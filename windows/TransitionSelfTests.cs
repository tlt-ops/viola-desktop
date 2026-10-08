using System;
using System.Collections.Generic;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Viola.Windows;

internal static class TransitionSelfTests
{
    public static void Run(Assets assets)
    {
        CheckPixels();
        Clip visible = assets.Manifest.Clips["laugh"], hidden = assets.Manifest.Clips["hiddenLaugh"];
        Require(visible.FrameCount == hidden.FrameCount && visible.Fps == hidden.Fps, "desk modes share a laugh timeline");
        foreach (bool desks in new[] { true, false })
        {
            string clipName = desks ? "laugh" : "hiddenLaugh";
            Clip clip = assets.Manifest.Clips[clipName];
            Require(clip.FrameCount / clip.Fps > LaughTransition.ActionSeconds, "recovery tail exists after the eight-second action");
            string prefix = desks ? "desk-" : "hidden-";
            foreach (string pose in new[] { "idle", "key-0", "mouse-0" })
            {
                Require(assets.TryPose(prefix + pose, out BitmapSource? from) && from != null, "handoff source pose exists");
                CheckSequence(assets, clipName, clip, from!, pose);
            }
        }
        var delayed = new LaughTransition(visible.FrameCount, visible.Fps, 0);
        Require(delayed.Sample(0).FrameIndex == 0, "timeline begins at its first frame");
        LaughSample late = delayed.Sample(30);
        Require(late.Phase == LaughPhase.Return && late.FrameIndex == visible.FrameCount - 1 && late.BlendWeight == 0,
            "a delayed timer must expose the final frame before its return");
        Require(delayed.Sample(30 + LaughTransition.HandoffSeconds).Phase == LaughPhase.Complete, "delayed return finishes independently of overdue action time");
        Require(LaughTransition.NextBlink(10, 0) == 13 && LaughTransition.NextBlink(10, 1) == 17,
            "blink is scheduled afresh three to seven seconds after recovery");
        Console.WriteLine("PASS: laugh idle/key/mouse handoffs in both desk modes, complete recovery tail, delayed timers and premultiplied alpha.");
    }

    private static void CheckSequence(Assets assets, string clipName, Clip clip, BitmapSource from, string pose)
    {
        var sequence = new LaughTransition(clip.FrameCount, clip.Fps, 0);
        var visited = new HashSet<int>();
        int returnSamples = 0;
        bool completed = false;
        double lastReturnWeight = -1;
        for (int step = 0; step <= Math.Ceiling((sequence.ClipSeconds + LaughTransition.HandoffSeconds) * 60) + 3; step++)
        {
            LaughSample sample = sequence.Sample(step / 60.0);
            Require(sample.FrameIndex == Assets.FrameIndex(clip, sample.ClipAge), "runtime frame indexing matches transition timeline");
            Require(sample.BlendWeight >= 0 && sample.BlendWeight <= 1, "handoff weight remains bounded");
            if (sample.Phase == LaughPhase.Complete)
            {
                Require(returnSamples > 0 && visited.Contains(clip.FrameCount - 1), "recovery and final frame were presented before completion");
                completed = true;
                break;
            }
            visited.Add(sample.FrameIndex);
            if (sample.Phase == LaughPhase.Return)
            {
                returnSamples++;
                Require(sample.FrameIndex == clip.FrameCount - 1 && sample.BlendWeight >= lastReturnWeight,
                    "return retains the last frame and progresses monotonically");
                lastReturnWeight = sample.BlendWeight;
            }
        }
        Require(completed, "recovery completes within its handoff interval");
        for (int frame = (int)(LaughTransition.ActionSeconds * clip.Fps); frame < clip.FrameCount; frame++)
            Require(visited.Contains(frame), "actual post-action tail frame was visited: " + frame);

        // Decode real idle/key/mouse and laugh frames only at the handoff boundaries; no window or hooks.
        var entry = new FrameBlend(from);
        BitmapSource first = assets.Frame(clipName, 0);
        SamePixels(entry.Mix(first, 0), from, "entry preserves the currently displayed " + pose);
        BitmapSource middle = entry.Mix(assets.Frame(clipName, .06), .5);
        Require(middle.PixelWidth == from.PixelWidth && middle.PixelHeight == from.PixelHeight, "entry canvas remains registered");
        BitmapSource end = assets.Frame(clipName, (clip.FrameCount - .5) / clip.Fps);
        var recovery = new FrameBlend(end);
        SamePixels(recovery.Mix(from, 0), end, "recovery starts with the real last frame");
        SamePixels(recovery.Mix(from, 1), from, "recovery returns exactly to the selected normal pose");
    }

    private static void CheckPixels()
    {
        BitmapSource Pixel(byte b, byte g, byte r, byte a) => BitmapSource.Create(1, 1, 96, 96, PixelFormats.Pbgra32, null, new byte[] { b, g, r, a }, 4);
        byte[] opaque = Pixels(new FrameBlend(Pixel(0, 0, 255, 255)).Mix(Pixel(255, 0, 0, 255), .5));
        Require(opaque[0] == 128 && opaque[2] == 128 && opaque[3] == 255, "overlapping opaque artwork stays fully opaque");
        byte[] edge = Pixels(new FrameBlend(Pixel(0, 0, 128, 128)).Mix(Pixel(128, 0, 0, 128), .5));
        Require(edge[0] == 64 && edge[2] == 64 && edge[3] == 128, "partial-alpha edges retain coverage");
        byte[] transparent = Pixels(new FrameBlend(Pixel(0, 0, 0, 0)).Mix(Pixel(128, 0, 0, 128), .5));
        Require(transparent[0] == 64 && transparent[3] == 64, "transparent endpoint stays premultiplied without a dark halo");
    }

    private static void SamePixels(BitmapSource left, BitmapSource right, string name) => Require(Pixels(left).AsSpan().SequenceEqual(Pixels(right)), name);
    private static byte[] Pixels(BitmapSource image)
    {
        BitmapSource source = image.Format == PixelFormats.Pbgra32 ? image : new FormatConvertedBitmap(image, PixelFormats.Pbgra32, null, 0);
        int stride = checked(image.PixelWidth * 4); byte[] result = new byte[checked(stride * image.PixelHeight)];
        source.CopyPixels(result, stride, 0); return result;
    }
    private static void Require(bool condition, string message) { if (!condition) throw new InvalidOperationException(message); }
}
