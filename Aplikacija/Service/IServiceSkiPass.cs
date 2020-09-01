using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Model;

namespace SkiPass.Service
{
    public interface IServiceSkiPass
    {
        IDictionary<string, string> Connections { get; set; }
        ServiceResult SelectUsers();
        ServiceResult SelectPackages();
        ServiceResult SaveUpadateUser(User user);
        ServiceResult InsertRental(DateTime dateFrom, DateTime dateTo, Package package, User user);
    }
}
