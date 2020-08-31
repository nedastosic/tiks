using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using SkiPass.Service;
using SkiPass.View;

namespace SkiPass.Presenter
{
    public class StartAdapterSkiPass
    {

        public string ConnectionString { get; set; }

        public Form Create()
        {
            IServiceSkiPass service = new SerivceSkiPass(ConnectionString);
            IViewSkiPass view = new ViewSkiPass();
            BasePresenter presenter = new PresenterSkiPass(view, service);

            presenter.ConnectionString = ConnectionString;
            presenter.Init();
            return (Form)view;
        }

    }
}
