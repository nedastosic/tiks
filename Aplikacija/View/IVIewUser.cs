using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Event;
using SkiPass.Model;

namespace SkiPass.View
{
    interface IVIewUser
    {
        event EventHandler<EventArgsUser> EventHendlerSaveUser;
    }
}
