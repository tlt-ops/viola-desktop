using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace Viola.Windows;

internal sealed class Settings
{
    public double Width { get; set; } = 320;
    public double? Left { get; set; }
    public double? Top { get; set; }
    public bool Interaction { get; set; } = true;
    public bool Topmost { get; set; } = true;
    public bool ShowDesks { get; set; } = true;
    public bool AutoCrawl { get; set; } = true;
    public string LaughVariant { get; set; } = "nailong";
    public bool SoundEnabled { get; set; } = true;
    public double SoundVolume { get; set; } = .8;
    public Dictionary<int, long> KeyPresses { get; set; } = new();
    public void Sanitize()
    {
        Width = double.IsFinite(Width) ? Math.Clamp(Width, 160, 800) : 320;
        if (Left.HasValue && !double.IsFinite(Left.Value)) Left = null;
        if (Top.HasValue && !double.IsFinite(Top.Value)) Top = null;
        KeyPresses ??= new();
        if (LaughVariant != "nailong" && LaughVariant != "viola") LaughVariant = "nailong";
        SoundVolume = double.IsFinite(SoundVolume) ? Math.Clamp(SoundVolume, 0, 1) : .8;
    }
}

internal static class SettingsStore
{
    public static string DirectoryPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ViolaDesktop-Windows");
    public static string PathName => Path.Combine(DirectoryPath, "settings.json");
    public static Settings Load(string path)
    {
        try { var settings = JsonSerializer.Deserialize<Settings>(File.ReadAllText(path)) ?? new(); settings.Sanitize(); return settings; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is JsonException) { return new(); }
    }
    public static void Save(string path, Settings settings)
    {
        settings.Sanitize(); Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        string temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true }));
        File.Move(temporary, path, true);
    }
}

internal static class KeyMap
{
    private static readonly Dictionary<int, int> Map = new()
    {
        [0x41]=0,[0x53]=1,[0x44]=2,[0x46]=3,[0x48]=4,[0x47]=5,[0x5A]=6,[0x58]=7,[0x43]=8,[0x56]=9,[0x42]=11,
        [0x51]=12,[0x57]=13,[0x45]=14,[0x52]=15,[0x59]=16,[0x54]=17,[0x31]=18,[0x32]=19,[0x33]=20,[0x34]=21,
        [0x36]=22,[0x35]=23,[0xBB]=24,[0x39]=25,[0x37]=26,[0xBD]=27,[0x38]=28,[0x30]=29,[0xDD]=30,[0x4F]=31,
        [0x55]=32,[0xDB]=33,[0x49]=34,[0x50]=35,[0x0D]=36,[0x4C]=37,[0x4A]=38,[0xDE]=39,[0x4B]=40,[0xBA]=41,
        [0xDC]=42,[0xBC]=43,[0xBF]=44,[0x4E]=45,[0x4D]=46,[0xBE]=47,[0x09]=48,[0x20]=49,[0xC0]=50,[0x08]=51,
        [0x1B]=53,[0x5C]=54,[0x5B]=55,[0xA0]=56,[0x10]=56,[0x14]=57,[0xA4]=58,[0x12]=58,[0xA2]=59,[0x11]=59,[0xA1]=60,[0xA5]=61,[0xA3]=62,
        [0x25]=123,[0x27]=124,[0x28]=125,[0x26]=126,[0x24]=115,[0x21]=116,[0x2E]=117,[0x23]=119,[0x22]=121,
        [0x70]=122,[0x71]=120,[0x72]=99,[0x73]=118,[0x74]=96,[0x75]=97,[0x76]=98,[0x77]=100,[0x78]=101,[0x79]=109,[0x7A]=103,[0x7B]=111
    };
    public static int? MacCode(int virtualKey) => Map.TryGetValue(virtualKey, out int code) ? code : null;
}
