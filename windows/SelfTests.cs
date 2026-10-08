using System;
using System.IO;

namespace Viola.Windows;

internal static class SelfTests
{
    public static int Run()
    {
        string temporary = Path.Combine(Path.GetTempPath(), "ViolaSelfTest-" + Guid.NewGuid().ToString("N"));
        try
        {
            var assets = new Assets(Path.Combine(AppContext.BaseDirectory, "Assets", "sprites"));
            Require(assets.CachedSheetCount == 0 && assets.CachedPoseCount == 0, "metadata validation does not eagerly decode assets");
            Require(assets.HasPose("desk-key-0") && assets.HasPose("hidden-key-0"), "both desk and hidden A-key poses exist");
            Require(assets.HasPose("mouse-left") && assets.HasPose("mouse-right"), "mouse poses exist");
            foreach (string name in Assets.Required)
            {
                var frame = assets.Frame(name, 0);
                Require(ReferenceEquals(frame, assets.Frame(name, 0)), "current clip/frame is reused");
                Require(assets.CachedSheetCount <= 2, "atlas cache is bounded");
                assets.Frame(name, 100); // Decode and crop each atlas's end/loop frame.
            }
            foreach (string name in assets.Manifest.Poses.Keys)
            {
                Require(assets.TryPose(name, out var pose) && pose != null, "pose decodes: " + name);
                Require(assets.CachedPoseCount <= 12, "pose cache is bounded");
            }
            Require(assets.TryPose("desk-key-0", out var cachedPose) && assets.TryPose("desk-key-0", out var repeatedPose) && ReferenceEquals(cachedPose, repeatedPose), "repeated key pose reuses decoded bitmap");
            foreach (string variant in new[] { "nailong", "viola" })
                Require(File.Exists(Path.Combine(AppContext.BaseDirectory, "Assets", variant + "-laugh.m4a")), "bundled laugh voice: " + variant);
            Require(KeyMap.MacCode(0x41) == 0 && KeyMap.MacCode(0x31) == 18 && KeyMap.MacCode(0x20) == 49 && KeyMap.MacCode(0x25) == 123, "physical key mapping");
            Require(KeyMap.MacCode(-1) == null, "unknown keys have no fabricated pose");
            var loop = new Clip { FrameCount = 3, Fps = 30, Loop = true };
            Require(Assets.FrameIndex(loop, .1) == 0 && Assets.FrameIndex(loop, 2.0 / 30) == 2, "elapsed-time loop indexing");
            loop.Loop = false; Require(Assets.FrameIndex(loop, 9) == 2, "one-shot frame clamps");
            TransitionSelfTests.Run(assets);
            string path = Path.Combine(temporary, "settings.json");
            var config = new Settings { Width = double.NaN, Left = double.PositiveInfinity, Interaction = false, LaughVariant = "viola", SoundEnabled = false, SoundVolume = .3 };
            config.KeyPresses[0x41] = 3; config.Sanitize(); SettingsStore.Save(path, config);
            Settings loaded = SettingsStore.Load(path);
            Require(loaded.Width == 320 && loaded.Left == null && !loaded.Interaction && loaded.KeyPresses[0x41] == 3, "local configuration and aggregate statistics round trip");
            Require(loaded.LaughVariant == "viola" && !loaded.SoundEnabled && loaded.SoundVolume == .3, "selected laugh sound persists without fallback");
            loaded.LaughVariant = "unsupported"; loaded.SoundVolume = double.NaN; loaded.Sanitize();
            Require(loaded.LaughVariant == "nailong" && loaded.SoundVolume == .8, "invalid sound settings sanitize");
            File.WriteAllText(path, "invalid json"); Require(SettingsStore.Load(path).Width == 320, "corrupt configuration fallback");
            Console.WriteLine("PASS: sprite metadata, atlas frames, key mapping, elapsed-time indexing, local configuration.");
            return 0;
        }
        catch (Exception ex) { Console.Error.WriteLine("FAIL: " + ex); return 1; }
        finally { if (Directory.Exists(temporary)) Directory.Delete(temporary, true); }
    }
    private static void Require(bool condition, string name) { if (!condition) throw new InvalidOperationException(name); }
}
