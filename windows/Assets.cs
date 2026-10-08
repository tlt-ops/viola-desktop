using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Media.Imaging;

namespace Viola.Windows;

internal sealed class Clip
{
    public string Sheet { get; set; } = "";
    public int Columns { get; set; }
    public int FrameCount { get; set; }
    public double Fps { get; set; }
    public bool Loop { get; set; }
}

internal sealed class SpriteManifest
{
    public int SchemaVersion { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
    public Dictionary<string, Clip> Clips { get; set; } = new();
    public Dictionary<string, string> Poses { get; set; } = new();
}

internal sealed class Assets
{
    public SpriteManifest Manifest { get; }
    public static readonly string[] Required = { "idle", "blink", "laugh", "crawl", "hiddenIdle", "hiddenBlink", "hiddenLaugh", "hiddenCrawl" };
    private const long SheetBudget = 128L * 1024 * 1024;
    private const int PoseLimit = 12;
    private readonly string directory;
    private readonly Dictionary<string, CacheEntry> sheets = new();
    private readonly Dictionary<string, CacheEntry> poses = new();
    private long useCounter;
    private string? lastClip;
    private int lastIndex = -1;
    private BitmapSource? lastFrame;
    internal int CachedSheetCount => sheets.Count;
    internal int CachedPoseCount => poses.Count;
    internal long CachedSheetBytes
    {
        get { long total = 0; foreach (var item in sheets.Values) total += item.Bytes; return total; }
    }
    private sealed class CacheEntry
    {
        public required BitmapSource Image { get; init; }
        public long Used { get; set; }
        public long Bytes { get; init; }
    }

    public Assets(string directory)
    {
        this.directory = Path.GetFullPath(directory);
        Manifest = JsonSerializer.Deserialize<SpriteManifest>(File.ReadAllText(Path.Combine(directory, "manifest.json")),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new InvalidDataException("Missing manifest.");
        if (Manifest.SchemaVersion != 1 || Manifest.Width <= 0 || Manifest.Height <= 0 || Manifest.Width > 2048 || Manifest.Height > 2048)
            throw new InvalidDataException("Unsupported sprite manifest.");
        foreach (string name in Required)
        {
            if (!Manifest.Clips.TryGetValue(name, out Clip? clip)) throw new InvalidDataException("Missing clip: " + name);
            if (clip.Columns <= 0 || clip.Columns > 128 || clip.FrameCount <= 0 || clip.FrameCount > 10000 || !double.IsFinite(clip.Fps) || clip.Fps <= 0 || clip.Fps > 120)
                throw new InvalidDataException("Invalid clip metadata: " + name);
            int rows = (clip.FrameCount + clip.Columns - 1) / clip.Columns;
            CheckPng(SafeFile(clip.Sheet), checked(Manifest.Width * clip.Columns), checked(Manifest.Height * rows));
        }
        foreach (var pair in Manifest.Poses) CheckPng(SafeFile(pair.Value), Manifest.Width, Manifest.Height);
    }

    private string SafeFile(string name)
    {
        string root = directory + Path.DirectorySeparatorChar;
        string file = Path.GetFullPath(Path.Combine(root, name));
        if (!file.StartsWith(root, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Asset path escapes directory.");
        return file;
    }

    // Header validation covers every file without decoding all atlases into memory.
    private static void CheckPng(string path, int width, int height)
    {
        using var file = File.OpenRead(path);
        Span<byte> header = stackalloc byte[24]; file.ReadExactly(header);
        ReadOnlySpan<byte> signature = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 };
        if (!header.Slice(0, 8).SequenceEqual(signature) || header[12] != 73 || header[13] != 72 || header[14] != 68 || header[15] != 82)
            throw new InvalidDataException("Not a PNG asset: " + Path.GetFileName(path));
        int actualWidth = System.Buffers.Binary.BinaryPrimitives.ReadInt32BigEndian(header.Slice(16, 4));
        int actualHeight = System.Buffers.Binary.BinaryPrimitives.ReadInt32BigEndian(header.Slice(20, 4));
        if (actualWidth != width || actualHeight != height) throw new InvalidDataException("PNG dimensions differ from manifest: " + Path.GetFileName(path));
    }

    private static BitmapSource Load(string path)
    {
        // StreamSource avoids WPF's global URI bitmap cache retaining evicted atlases.
        using var file = File.OpenRead(path);
        var image = new BitmapImage(); image.BeginInit(); image.CacheOption = BitmapCacheOption.OnLoad;
        image.StreamSource = file; image.EndInit(); image.Freeze(); return image;
    }

    public static int FrameIndex(Clip clip, double age)
    {
        if (!double.IsFinite(age) || age < 0) age = 0;
        double frame = Math.Floor(age * clip.Fps);
        return clip.Loop ? (int)(frame % clip.FrameCount) : (int)Math.Min(clip.FrameCount - 1, frame);
    }

    public BitmapSource Frame(string name, double age)
    {
        Clip clip = Manifest.Clips[name]; int index = FrameIndex(clip, age);
        if (name == lastClip && index == lastIndex && lastFrame != null) return lastFrame;
        string path = SafeFile(clip.Sheet);
        if (!sheets.TryGetValue(path, out CacheEntry? entry))
        {
            // Clear the old crop reference before eviction; it also owns its source atlas.
            lastFrame = null;
            long bytes = (long)Manifest.Width * clip.Columns * Manifest.Height * ((clip.FrameCount + clip.Columns - 1) / clip.Columns) * 4;
            while (sheets.Count > 0 && (sheets.Count >= 2 || CachedSheetBytes + bytes > SheetBudget)) EvictOldest(sheets);
            entry = new CacheEntry { Image = Load(path), Bytes = bytes }; sheets[path] = entry;
        }
        entry.Used = ++useCounter;
        var crop = new CroppedBitmap(entry.Image, new Int32Rect(index % clip.Columns * Manifest.Width,
            index / clip.Columns * Manifest.Height, Manifest.Width, Manifest.Height));
        crop.Freeze(); lastClip = name; lastIndex = index; lastFrame = crop; return crop;
    }

    public bool HasPose(string name) => Manifest.Poses.ContainsKey(name);
    public bool TryPose(string name, [System.Diagnostics.CodeAnalysis.NotNullWhen(true)] out BitmapSource? image)
    {
        image = null;
        if (!Manifest.Poses.TryGetValue(name, out string? file)) return false;
        string path = SafeFile(file);
        if (!poses.TryGetValue(path, out CacheEntry? entry))
        {
            if (poses.Count >= PoseLimit) EvictOldest(poses);
            entry = new CacheEntry { Image = Load(path), Bytes = (long)Manifest.Width * Manifest.Height * 4 }; poses[path] = entry;
        }
        entry.Used = ++useCounter; image = entry.Image; return true;
    }
    private static void EvictOldest(Dictionary<string, CacheEntry> cache)
    {
        string? oldest = null; long age = long.MaxValue;
        foreach (var pair in cache) if (pair.Value.Used < age) { oldest = pair.Key; age = pair.Value.Used; }
        if (oldest != null) cache.Remove(oldest);
    }
}
