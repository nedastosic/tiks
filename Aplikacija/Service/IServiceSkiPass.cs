using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Service
{
    public interface IServiceSkiPass
    {
        IDictionary<string, string> Connections { get; set; }
        ServiceResult SelectUsers();
        ServiceResult SelectPackages();
    }
}
