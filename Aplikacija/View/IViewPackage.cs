using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Event;

namespace SkiPass.View
{
    public interface IViewPackage
    {
        event EventHandler<EventArgsPackage> EventHendlerSavePackage;
    }
}
