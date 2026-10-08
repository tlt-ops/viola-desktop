using System;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Viola.Windows;

/// <summary>Crossfade equal-canvas premultiplied pixels, preserving coverage and transparent edges.</summary>
internal sealed class FrameBlend
{
    private readonly BitmapSource source;
    private readonly byte[] sourcePixels;
    private readonly int stride;

    public FrameBlend(BitmapSource source)
    {
        stride = checked(source.PixelWidth * 4);
        sourcePixels = Pixels(source, stride);
        // Detach a 320x384 pose from its potentially much larger source atlas.
        this.source = BitmapSource.Create(source.PixelWidth, source.PixelHeight,
            source.DpiX, source.DpiY, PixelFormats.Pbgra32, null, sourcePixels, stride);
        this.source.Freeze();
    }

    public BitmapSource Mix(BitmapSource target, double weight)
    {
        if (!double.IsFinite(weight)) throw new ArgumentOutOfRangeException(nameof(weight));
        if (target.PixelWidth != source.PixelWidth || target.PixelHeight != source.PixelHeight)
            throw new ArgumentException("Transition poses must share a canvas.", nameof(target));
        if (weight <= 0) return source;
        if (weight >= 1) return target;
        byte[] pixels = Pixels(target, stride);
        for (int i = 0; i < pixels.Length; i++)
            pixels[i] = (byte)Math.Clamp((int)Math.Round(sourcePixels[i] * (1 - weight) + pixels[i] * weight), 0, 255);
        var result = BitmapSource.Create(source.PixelWidth, source.PixelHeight,
            source.DpiX, source.DpiY, PixelFormats.Pbgra32, null, pixels, stride);
        result.Freeze();
        return result;
    }

    private static byte[] Pixels(BitmapSource image, int stride)
    {
        BitmapSource premultiplied = image.Format == PixelFormats.Pbgra32 ? image :
            new FormatConvertedBitmap(image, PixelFormats.Pbgra32, null, 0);
        byte[] pixels = new byte[checked(stride * image.PixelHeight)];
        premultiplied.CopyPixels(pixels, stride, 0);
        return pixels;
    }
}
