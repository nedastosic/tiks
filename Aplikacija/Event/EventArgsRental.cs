using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Model;

namespace SkiPass.Event
{
    public class EventArgsRental: EventArgs
    {
        public DateTime  DateFrom{ get; set; }
        public DateTime  DateTo{ get; set; }
        public User User { get; set; }
        public Package Package { get; set; }
    }
}
