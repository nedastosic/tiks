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

            _view.EventHendlerSavePackage -= EventHendlerSavePackage;
            _view.EventHendlerSavePackage += EventHendlerSavePackage;

            _view.EventHendlerUpdatePackage -= EventHendlerUpdatePackage;
            _view.EventHendlerUpdatePackage += EventHendlerUpdatePackage;
    }

        private void EventHendlerUpdatePackage(object sender, EventArgsPackage e)
        {
            ServiceResult result = _service.UpdatePackage(e.Package);
            if (result.IsValid)
                _view.InformationMessage(result.Message);
            else
                _view.ErrorMessage(result.Message);
        }

        private void EventHendlerSavePackage(object sender, EventArgsPackage e)
        {
            ServiceResult result = _service.InsertPackageRegion(e.Package, e.Regions);

            if (result.IsValid)
                _view.ErrorMessage(result.Message);
            else
                _view.InformationMessage(result.Message);
        }

        private void EventHendlerRefresh(object sender, EventArgs e)
        {
            NapuniComboKorisnik();
            NapuniComboPaketiSP();
        }

        private void EventHendlerSaveUser(object sender, EventArgsUser e)
        {
            ServiceResult result = _service.SaveUpadateUser(e.User);

            if (result.IsValid)
                _view.InformationMessage(result.Message);
            else
                _view.ErrorMessage(result.Message);
        }

        private void EventHendlerInsertRental(object sender, EventArgsRental e)
        {
            ServiceResult result = _service.InsertRental(e.DateFrom, e.DateTo, e.Package, e.User);

            if (result.IsValid)
            {
                _view.InformationMessage(result.Message);
                UcitajGenerisanuCenu((int)result.Value);
            }
            else
                _view.ErrorMessage(result.Message);

        }

        private void UcitajGenerisanuCenu(int idSkiPass)
        {
            ServiceResult result = _service.SelectSkiPass(idSkiPass);
            if (result.IsValid)
                _view.ShowPrice((decimal)result.Value);
        }

        public override void Init()
        {
            NapuniComboKorisnik();
            NapuniComboPaketiSP();
            GetAllRegions();
        }

        private void GetAllRegions()
        {
            ServiceResult result = _service.SelectRegions();
            if (result.IsValid)
                _view.SetRegions((List<Region>)result.Value);
        }

        private void NapuniComboPaketiSP()
        {
            ServiceResult result =  _service.SelectPackages();

            foreach (Package package in (List<Package>)result.Value)
            { 
                package.Regions = _service.SelectRegionsByPackageId(package.PackageID);
            }

            _view.NapuniComboPaketi((List<Package>)result.Value);
        }

        private  void NapuniComboKorisnik()
        {
            ServiceResult result =  _service.SelectUsers();
            _view.NapuniComboKorisnik((List<User>)result.Value);

        }
    }
}
