using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Model;

namespace SkiPass.Event
{
    public class EventArgsPackage:EventArgs
    {
        public Package Package { get; set; }
        public List<Region> Regions { get; set; }
    }
}
