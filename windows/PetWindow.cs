using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Forms = System.Windows.Forms;

namespace Viola.Windows;

internal sealed class PetWindow : Window
{
    private readonly Assets assets = new(Path.Combine(AppContext.BaseDirectory, "Assets", "sprites"));
    private readonly Settings settings;
    private readonly Image sprite = new() { Stretch = Stretch.Fill };
    private readonly NativeInput input = new();
    private readonly Stopwatch clock = Stopwatch.StartNew();
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromMilliseconds(1000.0 / 60) };
    private readonly Forms.NotifyIcon? tray;
    private readonly string? smokeOutput;
    private readonly HashSet<int> pressed = new();
    private string state = "idle";
    private double stateStart, lastInput, nextBlink = 4, lastSave, keyReleaseAt, mouseReleaseAt;
    private int? currentKey;
    private int previousMouseX, previousMouseY;
    private bool mouseSeen, dragging, ready;
    private string? mousePose;
    private bool mouseClick;
    private Point dragPoint, dragOrigin;
    private double crawlOriginX, crawlOriginY, crawlDistance;
    private int crawlDirection = -1;
    private bool settingsDirty;
    private readonly Random random = new();
    private readonly MediaPlayer sound = new();
    private readonly TextBlock status = new();

    public PetWindow(string? smoke)
    {
        smokeOutput = smoke;
        settings = smoke == null ? SettingsStore.Load(SettingsStore.PathName) : new Settings { AutoCrawl = false };
        Title = "viola终稿"; WindowStyle = WindowStyle.None; ResizeMode = ResizeMode.NoResize;
        AllowsTransparency = true; Background = Brushes.Transparent; ShowInTaskbar = false; ShowActivated = false;
        Topmost = settings.Topmost; Width = settings.Width; Height = Width * assets.Manifest.Height / assets.Manifest.Width;
        Content = sprite;
        sound.MediaFailed += (_, e) => status.Text = "Laugh sound failed: " + e.ErrorException.Message;
        sound.MediaEnded += (_, _) => { sound.Stop(); sound.Close(); };
        sprite.Source = assets.Frame("idle", 0);
        SourceInitialized += (_, _) =>
        {
            IntPtr handle = new WindowInteropHelper(this).Handle;
            long style = NativeInput.GetWindowLongPtr(handle, -20).ToInt64();
            NativeInput.SetWindowLongPtr(handle, -20, new IntPtr(style | 0x08000000 | 0x00000080)); // NOACTIVATE + TOOLWINDOW
            HwndSource.FromHwnd(handle)?.AddHook(WindowMessage);
        };
        Loaded += (_, _) => Start();
        Closed += (_, _) =>
        {
            timer.Stop(); input.Dispose(); sound.Close(); tray?.Dispose();
            if (smokeOutput == null) Save();
        };
        timer.Tick += (_, _) => Tick();
        input.Key += OnKey; input.Mouse += OnMouse;
        MouseLeftButtonDown += OnPetMouseDown;
        MouseLeftButtonUp += OnPetMouseUp;
        MouseMove += Drag;
        MouseWheel += (_, e) => { SetWidth(Width * (e.Delta > 0 ? 1.08 : 1 / 1.08)); e.Handled = true; };
        ContextMenu = BuildMenu();
        if (smoke == null)
        {
            tray = new Forms.NotifyIcon { Icon = System.Drawing.SystemIcons.Application, Text = "Viola desktop companion", Visible = true };
            var menu = new Forms.ContextMenuStrip();
            menu.Items.Add("Show Viola", null, (_, _) => { Show(); Clamp(); });
            menu.Items.Add("Laugh", null, (_, _) => BeginLaugh());
            menu.Items.Add("Crawl", null, (_, _) => BeginCrawl());
            menu.Items.Add("Pause / resume interaction", null, (_, _) => ToggleInteraction());
            menu.Items.Add("Exit", null, (_, _) => Close());
            tray.ContextMenuStrip = menu;
            tray.DoubleClick += (_, _) => { Show(); Clamp(); };
        }
    }

    private static IntPtr WindowMessage(IntPtr window, int message, IntPtr w, IntPtr l, ref bool handled)
    {
        if (message == 0x21) { handled = true; return new IntPtr(3); } // MA_NOACTIVATE
        return IntPtr.Zero;
    }

    private void Start()
    {
        Rect area = Area();
        Left = settings.Left ?? area.Right - Width - 24; Top = settings.Top ?? area.Bottom - Height - 16;
        Clamp(); ready = true;
        if (smokeOutput == null && settings.Interaction) Connect();
        timer.Start();
    }

    private void Connect()
    {
        try { input.Start(); status.Text = "Passive input hooks connected"; }
        catch (Exception ex) { status.Text = "Input hooks unavailable: " + ex.Message; }
    }

    private ContextMenu BuildMenu()
    {
        var menu = new ContextMenu();
        void Add(string label, Action action) { var item = new MenuItem { Header = label }; item.Click += (_, _) => action(); menu.Items.Add(item); }
        void Toggle(string label, Func<bool> value, Action action)
        {
            var item = new MenuItem { Header = label, IsCheckable = true };
            menu.Opened += (_, _) => item.IsChecked = value();
            item.Click += (_, _) => { action(); settingsDirty = true; };
            menu.Items.Add(item);
        }
        Add("Laugh", BeginLaugh); Add("Crawl", BeginCrawl);
        Toggle("Automatic idle crawl", () => settings.AutoCrawl, () => { settings.AutoCrawl = !settings.AutoCrawl; lastInput = clock.Elapsed.TotalSeconds; });
        Toggle("Show keyboard and mouse", () => settings.ShowDesks, () => settings.ShowDesks = !settings.ShowDesks);
        Toggle("Observe keyboard and mouse", () => settings.Interaction, ToggleInteraction);
        Toggle("Laugh sound enabled", () => settings.SoundEnabled, () => { settings.SoundEnabled = !settings.SoundEnabled; StopSound(); });
        var sounds = new MenuItem { Header = "Laugh voice" };
        foreach (var option in new[] { (Variant: "nailong", Label: "奶龙大笑"), (Variant: "viola", Label: "薇欧拉大笑") })
        {
            var item = new MenuItem { Header = option.Label, IsCheckable = true };
            menu.Opened += (_, _) => item.IsChecked = settings.LaughVariant == option.Variant;
            item.Click += (_, _) =>
            {
                settings.LaughVariant = option.Variant; settingsDirty = true; StopSound();
                foreach (MenuItem sibling in sounds.Items) sibling.IsChecked = ReferenceEquals(sibling, item);
                status.Text = File.Exists(SoundPath()) ? "Voice selected: " + option.Label : "Missing selected sound: " + Path.GetFileName(SoundPath());
            };
            sounds.Items.Add(item);
        }
        menu.Items.Add(sounds);
        Toggle("Stay on top", () => settings.Topmost, () => { settings.Topmost = !settings.Topmost; Topmost = settings.Topmost; });
        var size = new MenuItem { Header = "Size" };
        foreach (double width in new[] { 160d, 240d, 320d, 440d, 640d })
        {
            var item = new MenuItem { Header = width + " px" }; item.Click += (_, _) => SetWidth(width); size.Items.Add(item);
        }
        menu.Items.Add(size);
        var statistics = new MenuItem { Header = "Local key statistics" }; statistics.Click += (_, _) => ShowStatistics(); menu.Items.Add(statistics);
        var connection = new MenuItem { Header = status, IsEnabled = false }; menu.Items.Add(connection);
        Add("Hide (tray remains available)", () => { StopSound(); Hide(); }); Add("Exit", Close);
        return menu;
    }

    private void ShowStatistics()
    {
        var lines = new List<string> { "Physical Windows virtual-key press totals (no text or event sequence).", "Stored only in LocalAppData/ViolaDesktop-Windows/settings.json", "" };
        foreach (var pair in settings.KeyPresses) lines.Add($"VK 0x{pair.Key:X2}: {pair.Value}");
        var view = new TextBox { Text = string.Join(Environment.NewLine, lines), IsReadOnly = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Margin = new Thickness(12) };
        new Window { Title = "Viola · local key statistics", Width = 480, Height = 500, Content = view }.Show();
    }

    private void ToggleInteraction()
    {
        settings.Interaction = !settings.Interaction; settingsDirty = true;
        if (settings.Interaction) Connect(); else { input.Dispose(); pressed.Clear(); currentKey = null; mousePose = null; StopSound(); status.Text = "Input observation paused"; }
    }

    private void OnKey(int virtualKey, bool down, bool repeat)
    {
        double now = clock.Elapsed.TotalSeconds;
        lastInput = now;
        if (state == "crawl") EndCrawl();
        if (down)
        {
            pressed.Add(virtualKey);
            if (!repeat) { settings.KeyPresses.TryGetValue(virtualKey, out long count); settings.KeyPresses[virtualKey] = count == long.MaxValue ? count : count + 1; settingsDirty = true; }
            currentKey = KeyMap.MacCode(virtualKey); keyReleaseAt = now + .12;
        }
        else
        {
            pressed.Remove(virtualKey);
            if (KeyMap.MacCode(virtualKey) == currentKey) keyReleaseAt = now + .10;
        }
        if (state != "laugh") Render(now); // Low-latency physical-key reaction.
    }

    private void OnMouse(int x, int y, bool click)
    {
        if (!click && mouseSeen && x == previousMouseX && y == previousMouseY) return;
        double now = clock.Elapsed.TotalSeconds; lastInput = now;
        if (state == "crawl") EndCrawl();
        mousePose = mouseSeen && x < previousMouseX ? "mouse-left" : "mouse-right";
        previousMouseX = x; previousMouseY = y; mouseSeen = true; mouseClick = click; mouseReleaseAt = now + .16;
    }

    private void BeginLaugh()
    {
        if (state == "crawl") EndCrawl();
        state = "laugh"; stateStart = clock.Elapsed.TotalSeconds;
        StopSound();
        if (settings.SoundEnabled)
        {
            string audio = SoundPath();
            if (File.Exists(audio)) { sound.Open(new Uri(audio)); sound.Volume = settings.SoundVolume; sound.Play(); status.Text = "Laugh voice: " + settings.LaughVariant; }
            else status.Text = "Missing selected sound: " + Path.GetFileName(audio);
        }
    }

    private void BeginCrawl()
    {
        if (state == "laugh" || dragging) return;
        if (state == "crawl") EndCrawl();
        Clamp(); Rect area = Area();
        crawlDirection = -crawlDirection;
        double available = crawlDirection > 0 ? area.Right - (Left + Width) : Left - area.Left;
        if (available < 20) { crawlDirection = -crawlDirection; available = crawlDirection > 0 ? area.Right - (Left + Width) : Left - area.Left; }
        crawlDistance = Math.Max(0, Math.Min(Width * .65, available));
        crawlOriginX = Left; crawlOriginY = Top; state = "crawl"; stateStart = clock.Elapsed.TotalSeconds;
    }

    private void EndCrawl()
    {
        // Retain the current visible position; input cancellation never teleports the pet.
        state = "idle"; stateStart = clock.Elapsed.TotalSeconds; lastInput = stateStart; Clamp(); settingsDirty = true;
    }

    private void Tick()
    {
        double now = clock.Elapsed.TotalSeconds;
        if (state == "laugh" && now - stateStart >= 8) { state = "idle"; stateStart = now; StopSound(); }
        if (state == "crawl")
        {
            double t = Math.Clamp((now - stateStart) / 8, 0, 1);
            double eased = t * t * (3 - 2 * t);
            Left = crawlOriginX + crawlDirection * crawlDistance * eased; Top = crawlOriginY; Clamp();
            if (t >= 1) EndCrawl();
        }
        if (state == "blink" && now - stateStart >= assets.Manifest.Clips[settings.ShowDesks ? "blink" : "hiddenBlink"].FrameCount / assets.Manifest.Clips[settings.ShowDesks ? "blink" : "hiddenBlink"].Fps)
        { state = "idle"; stateStart = now; }
        if (state == "idle" && now >= nextBlink) { state = "blink"; stateStart = now; nextBlink = now + 3 + random.NextDouble() * 4; }
        if (settings.AutoCrawl && state != "laugh" && state != "crawl" && !dragging && !ContextMenu!.IsOpen && now - lastInput >= 25) BeginCrawl();
        Render(now);
        if (smokeOutput != null && now >= 1)
        {
            SaveScreenshot(smokeOutput); timer.Stop(); Close(); return;
        }
        if (smokeOutput == null && settingsDirty && now - lastSave >= 2) Save();
    }

    private void Render(double now)
    {
        string clip = settings.ShowDesks ? state : "hidden" + char.ToUpperInvariant(state[0]) + state.Substring(1);
        BitmapSource frame = assets.Frame(clip, now - stateStart);
        if (state != "laugh" && state != "crawl")
        {
            bool keyHeld = false;
            foreach (int key in pressed) if (KeyMap.MacCode(key) == currentKey) keyHeld = true;
            string prefix = settings.ShowDesks ? "desk-" : "hidden-";
            if (currentKey.HasValue && (keyHeld || now < keyReleaseAt) && assets.TryPose(prefix + "key-" + currentKey.Value, out BitmapSource? keyPose)) frame = keyPose;
            else if (mousePose != null && now < mouseReleaseAt)
            {
                string name = prefix + (mouseClick ? "mouse-click" : mousePose == "mouse-left" ? "mouse-0" : "mouse-2");
                if (assets.TryPose(name, out BitmapSource? pose)) frame = pose;
                else if (settings.ShowDesks && assets.TryPose(mousePose, out BitmapSource? alias)) frame = alias;
            }
        }
        // One atomic image replacement avoids double-eye/face alpha ghosts.
        if (!ReferenceEquals(sprite.Source, frame)) sprite.Source = frame;
    }

    private void OnPetMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (state == "crawl") EndCrawl();
        dragging = true; dragPoint = PointToScreen(e.GetPosition(this)); dragOrigin = new Point(Left, Top);
        sprite.CaptureMouse(); e.Handled = true;
    }
    private void Drag(object sender, MouseEventArgs e)
    {
        if (!dragging) return;
        Point point = PointToScreen(e.GetPosition(this));
        var dpi = VisualTreeHelper.GetDpi(this);
        Left = dragOrigin.X + (point.X - dragPoint.X) / dpi.DpiScaleX;
        Top = dragOrigin.Y + (point.Y - dragPoint.Y) / dpi.DpiScaleY; Clamp();
    }
    private void OnPetMouseUp(object sender, MouseButtonEventArgs e)
    {
        if (!dragging) return;
        Point point = PointToScreen(e.GetPosition(this)); bool moved = (point - dragPoint).Length > 5;
        dragging = false; sprite.ReleaseMouseCapture(); lastInput = clock.Elapsed.TotalSeconds; settingsDirty = true;
        Point local = e.GetPosition(this);
        if (!moved && local.Y < Height * .65) BeginLaugh();
        e.Handled = true;
    }
    private void SetWidth(double width)
    {
        if (state == "crawl") EndCrawl();
        Width = Math.Clamp(width, 160, 800); Height = Width * assets.Manifest.Height / assets.Manifest.Width;
        settings.Width = Width; Clamp(); settingsDirty = true;
    }
    private Rect Area()
    {
        IntPtr handle = new WindowInteropHelper(this).Handle;
        var screen = handle == IntPtr.Zero ? Forms.Screen.PrimaryScreen! : Forms.Screen.FromHandle(handle);
        var dpi = VisualTreeHelper.GetDpi(this); var bounds = screen.WorkingArea;
        return new Rect(bounds.Left / dpi.DpiScaleX, bounds.Top / dpi.DpiScaleY, bounds.Width / dpi.DpiScaleX, bounds.Height / dpi.DpiScaleY);
    }
    private void Clamp()
    {
        Rect area = Area(); Left = Math.Clamp(Left, area.Left, Math.Max(area.Left, area.Right - Width)); Top = Math.Clamp(Top, area.Top, Math.Max(area.Top, area.Bottom - Height));
    }
    private void Save()
    {
        if (!ready) return;
        settings.Width = Width; settings.Left = Left; settings.Top = Top;
        try { SettingsStore.Save(SettingsStore.PathName, settings); settingsDirty = false; lastSave = clock.Elapsed.TotalSeconds; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { status.Text = "Settings save failed: " + ex.Message; }
    }
    private void SaveScreenshot(string path)
    {
        UpdateLayout();
        var image = new RenderTargetBitmap((int)Math.Ceiling(ActualWidth), (int)Math.Ceiling(ActualHeight), 96, 96, PixelFormats.Pbgra32);
        image.Render(sprite);
        var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(image));
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        using var output = File.Create(path); encoder.Save(output);
    }
    private string SoundPath() => Path.Combine(AppContext.BaseDirectory, "Assets", settings.LaughVariant + "-laugh.m4a");
    private void StopSound() { sound.Stop(); sound.Close(); }
}
