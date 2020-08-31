using System;
using System.Collections.Generic;
using SkiPass.View;

namespace SkiPass.Presenter
{
    public class BasePresenter 
    {
        public BasePresenter(IViewSkiPass view)
        {
            view.Init += View_Init;
        }

        private void View_Init(object sender, EventArgs e)
        {
            Init();
        }

        public string ConnectionString { get; set; }
        public IDictionary<string, string> Connections { get; set; }
        public virtual void Init()
        {
        }

        public virtual void SetupControls()
        {
        }
    }
}
