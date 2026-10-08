using System;

namespace Viola.Windows;

internal enum LaughPhase { Entry, Playback, Return, Complete }

internal readonly record struct LaughSample(LaughPhase Phase, int FrameIndex, double ClipAge, double NormalAge, double BlendWeight);

/// <summary>Elapsed-time choreography only; never connects input or reads user settings.</summary>
internal sealed class LaughTransition
{
    public const double ActionSeconds = 8;
    public const double HandoffSeconds = .12;
    private readonly int frameCount;
    private readonly double fps;
    private readonly double started;
    private double? returnStarted;
    public double ClipSeconds { get; }
    public double ReturnStart => returnStarted ?? started + ClipSeconds;

    public LaughTransition(int frameCount, double fps, double started)
    {
        if (frameCount <= 0 || !double.IsFinite(fps) || fps <= 0 || !double.IsFinite(started))
            throw new ArgumentOutOfRangeException(nameof(frameCount), "Invalid laugh timeline.");
        this.frameCount = frameCount; this.fps = fps; this.started = started;
        ClipSeconds = frameCount / fps;
        if (ClipSeconds < ActionSeconds) throw new ArgumentException("Laugh clip must retain its eight-second action.");
    }

    public LaughSample Sample(double now)
    {
        if (!double.IsFinite(now)) throw new ArgumentOutOfRangeException(nameof(now));
        double age = Math.Max(0, now - started);
        int index = (int)Math.Min(frameCount - 1, Math.Floor(age * fps));
        // The middle of the last frame's interval avoids floating-point floor ambiguity.
        double clipAge = Math.Min(age, (frameCount - .5) / fps);
        if (age < HandoffSeconds)
            return new(LaughPhase.Entry, index, clipAge, 0, Ease(age / HandoffSeconds));
        if (age < ClipSeconds)
            return new(LaughPhase.Playback, index, clipAge, 0, 1);
        // First observe the final frame before allowing recovery to complete, even after a delayed tick.
        returnStarted ??= now;
        double normalAge = Math.Max(0, now - returnStarted.Value);
        return new(normalAge < HandoffSeconds - 1e-9 ? LaughPhase.Return : LaughPhase.Complete,
            frameCount - 1, clipAge, normalAge, Ease(normalAge / HandoffSeconds));
    }

    public static double NextBlink(double completedAt, double randomUnit) => completedAt + 3 + 4 * Math.Clamp(randomUnit, 0, 1);
    private static double Ease(double value) { double t = Math.Clamp(value, 0, 1); return t * t * (3 - 2 * t); }
}
