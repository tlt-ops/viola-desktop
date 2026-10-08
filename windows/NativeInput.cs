using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Viola.Windows;

internal sealed class NativeInput : IDisposable
{
    private const int KeyboardHook = 13, MouseHook = 14;
    private readonly HookProc keyboardCallback;
    private readonly HookProc mouseCallback;
    private IntPtr keyboard, mouse;
    private readonly HashSet<int> held = new();
    public event Action<int, bool, bool>? Key;
    public event Action<int, int, bool>? Mouse;
    public bool Connected => keyboard != IntPtr.Zero && mouse != IntPtr.Zero;
    public NativeInput() { keyboardCallback = Keyboard; mouseCallback = MouseEvent; }
    public void Start()
    {
        Dispose();
        IntPtr module = GetModuleHandle(null);
        keyboard = SetWindowsHookEx(KeyboardHook, keyboardCallback, module, 0);
        mouse = SetWindowsHookEx(MouseHook, mouseCallback, module, 0);
        if (!Connected) { int error = Marshal.GetLastWin32Error(); Dispose(); throw new Win32Exception(error, "Cannot register passive input hooks."); }
    }
    public void Dispose()
    {
        if (keyboard != IntPtr.Zero) UnhookWindowsHookEx(keyboard);
        if (mouse != IntPtr.Zero) UnhookWindowsHookEx(mouse);
        keyboard = mouse = IntPtr.Zero; held.Clear();
    }
    private IntPtr Keyboard(int code, IntPtr message, IntPtr pointer)
    {
        if (code >= 0)
        {
            var data = Marshal.PtrToStructure<KeyboardData>(pointer);
            int kind = message.ToInt32(); bool down = kind == 0x100 || kind == 0x104;
            bool up = kind == 0x101 || kind == 0x105;
            // Ignore injected events: only physical input drives the pet/statistics.
            if ((down || up) && (data.Flags & 0x10) == 0)
            {
                int key = (int)data.VirtualKey; bool repeat = down && !held.Add(key);
                if (up) held.Remove(key);
                try { Key?.Invoke(key, down, repeat); } catch { /* Never suppress user's input. */ }
            }
        }
        return CallNextHookEx(keyboard, code, message, pointer);
    }
    private IntPtr MouseEvent(int code, IntPtr message, IntPtr pointer)
    {
        if (code >= 0)
        {
            var data = Marshal.PtrToStructure<MouseData>(pointer);
            if ((data.Flags & 1) == 0)
            {
                int kind = message.ToInt32();
                if (kind == 0x200 || kind == 0x201 || kind == 0x204)
                    try { Mouse?.Invoke(data.X, data.Y, kind != 0x200); } catch { }
            }
        }
        return CallNextHookEx(mouse, code, message, pointer);
    }
    private delegate IntPtr HookProc(int code, IntPtr message, IntPtr pointer);
    [StructLayout(LayoutKind.Sequential)] private struct KeyboardData { public uint VirtualKey, ScanCode, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] private struct MouseData { public int X, Y; public uint MouseDataValue, Flags, Time; public UIntPtr Extra; }
    [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SetWindowsHookEx(int id, HookProc callback, IntPtr module, uint thread);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr pointer);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string? name);
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] internal static extern IntPtr GetWindowLongPtr(IntPtr window, int index);
    [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW")] internal static extern IntPtr SetWindowLongPtr(IntPtr window, int index, IntPtr value);
}
