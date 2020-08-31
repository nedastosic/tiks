using System;
using System.Collections.Generic;
using SkiPass.View;

namespace SkiPass.Presenter
{
    public class BasePresenter 
    {
        public BasePresenter(IViewSkiPass view)
        {
        }

        public string ConnectionString { get; set; }
        public IDictionary<string, string> Connections { get; set; }
        public virtual void Init()
        {

        }
    }
}
