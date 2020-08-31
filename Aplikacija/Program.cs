using System;
using System.Windows.Forms;
using SkiPass.Presenter;

namespace SkiPass
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            var start = new StartAdapterSkiPass
            {
                ConnectionString = "SkiPass:Persist security info=false;Integrated security=SSPI;Data source=DESKTOP-HMK35GO;Initial catalog=SkiPass"
            };

            Application.Run(start.Create());
        }
    }
}
