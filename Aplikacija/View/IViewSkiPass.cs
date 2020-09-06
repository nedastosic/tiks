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
        event EventHandler<EventArgsUser> EventHendlerSaveUser;
        event EventHandler<EventArgsPackage> EventHendlerSavePackage;
        event EventHandler<EventArgsPackage> EventHendlerUpdatePackage;
        event EventHandler EventHendlerRefresh;
        List<Region> listRegion { get; set; }

        void ErrorMessage(string message);
        void InformationMessage(string message);
        void NapuniComboKorisnik(List<User> value);
        void NapuniComboPaketi(List<Package> value);
        void ShowPrice(decimal price);
        void SetRegions(List<Region> value);
    }
}
