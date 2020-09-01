using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Model;

namespace SkiPass.Event
{
    public class EventArgsUser: EventArgs
    {
        public User User { get; set; }
    }
}
