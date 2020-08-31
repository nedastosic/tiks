using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Model;

namespace SkiPass.View
{
    public interface IViewSkiPass
    {
        event EventHandler Init;
        void Initialize();
        void ErrorMessage(string message);
        void InformationMessage(string message);
        void NapuniComboKorisnik(List<Korisnik> value);
        void NapuniComboPaketi(List<PaketSkiPass> value);
    }
}
