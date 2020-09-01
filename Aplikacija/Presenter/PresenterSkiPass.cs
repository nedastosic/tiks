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

            _view.EventHendlerSaveUser -= EventHendlerSaveUser;
            _view.EventHendlerSaveUser += EventHendlerSaveUser;

            _view.EventHendlerRefresh -= EventHendlerRefresh;
            _view.EventHendlerRefresh += EventHendlerRefresh;
    }

        private void EventHendlerRefresh(object sender, EventArgs e)
        {
            NapuniComboKorisnik();
        }

        private void EventHendlerSaveUser(object sender, EventArgsUser e)
        {
            ServiceResult result = _service.SaveUpadateUser(e.User);

            if (result.isValid)
                _view.InformationMessage(result.Message);
            else
                _view.ErrorMessage(result.Message);
        }

        private void EventHendlerInsertRental(object sender, EventArgsRental e)
        {
            ServiceResult result = _service.InsertRental(e.DateFrom, e.DateTo, e.Package, e.User);

            if (result.isValid)
                _view.InformationMessage(result.Message);
            else
                _view.ErrorMessage(result.Message);
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
