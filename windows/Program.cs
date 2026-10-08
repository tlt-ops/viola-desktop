using System;
using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace Viola.Windows;

internal static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        try
        {
            if (Array.IndexOf(args, "--self-test") >= 0) return SelfTests.Run();
            string? smoke = null;
            int index = Array.IndexOf(args, "--smoke-test");
            if (index >= 0)
            {
                if (index + 1 >= args.Length) throw new ArgumentException("--smoke-test requires a PNG output path.");
                smoke = Path.GetFullPath(args[index + 1]);
            }
            var app = new Application { ShutdownMode = ShutdownMode.OnMainWindowClose };
            app.DispatcherUnhandledException += (_, e) =>
            {
                Console.Error.WriteLine(e.Exception);
                if (smoke == null) MessageBox.Show(e.Exception.Message, "Viola");
                e.Handled = true;
                app.Shutdown(1);
            };
            return app.Run(new PetWindow(smoke));
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex);
            if (Array.IndexOf(args, "--self-test") < 0 && Array.IndexOf(args, "--smoke-test") < 0)
                MessageBox.Show(ex.Message, "Viola could not start");
            return 1;
        }
    }
}
