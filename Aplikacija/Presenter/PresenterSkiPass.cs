using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Model;
using SkiPass.Service;
using SkiPass.View;

namespace SkiPass.Presenter
{
    public class PresenterSkiPass : BasePresenter
    {
        private readonly IServiceSkiPass _service;
        private readonly IViewSkiPass _view;
        public PresenterSkiPass(IViewSkiPass view, IServiceSkiPass service) : base(view)
        {
            _view = view;
            _service = service;
        }

        public override void Init()
        {
            NapuniComboKorisnik();
            NapuniComboPaketiSP();
        }

        private void NapuniComboPaketiSP()
        {
            ServiceResult result =  _service.GetAllPaketi();
            _view.NapuniComboPaketi((List<PaketSkiPass>)result.Value);
        }

        private  void NapuniComboKorisnik()
        {
            ServiceResult result =  _service.GetAllKorisnici();
            _view.NapuniComboKorisnik((List<Korisnik>)result.Value);

        }
    }
}
