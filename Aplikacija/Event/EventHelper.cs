using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Event
{
    public class EventHelper
    {
        public static void Raise<T>(object sender, EventHandler<T> handler, T args) where T : EventArgs
        {
            handler?.Invoke(sender, args);
        }

        public static void Raise(object sender, EventHandler handler)
        {
            handler?.Invoke(sender, EventArgs.Empty);
        }
    }
}
