using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Event;
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
            EventSetup();
        }

        private void EventSetup()
        {
            _view.EventHendlerInsertRental -= EventHendlerInsertRental;
            _view.EventHendlerInsertRental += EventHendlerInsertRental;
        }

        private void EventHendlerInsertRental(object sender, EventArgsRental e)
        {
            
        }

        public override void Init()
        {
            NapuniComboKorisnik();
            NapuniComboPaketiSP();
        }

        private void NapuniComboPaketiSP()
        {
            ServiceResult result =  _service.SelectPackages();
            _view.NapuniComboPaketi((List<Package>)result.Value);
        }

        private  void NapuniComboKorisnik()
        {
            ServiceResult result =  _service.SelectUsers();
            _view.NapuniComboKorisnik((List<User>)result.Value);

        }
    }
}
