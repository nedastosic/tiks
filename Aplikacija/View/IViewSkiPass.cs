using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Event;
using SkiPass.Model;

namespace SkiPass.View
{
    public interface IViewSkiPass
    {
        event EventHandler<EventArgsRental> EventHendlerInsertRental;
        void ErrorMessage(string message);
        void InformationMessage(string message);
        void NapuniComboKorisnik(List<User> value);
        void NapuniComboPaketi(List<Package> value);
    }
}
