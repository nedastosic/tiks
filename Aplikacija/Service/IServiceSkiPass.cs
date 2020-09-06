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
        ServiceResult SelectSkiPass(int idSkiPass);
        ServiceResult SelectRegions();
        ServiceResult InsertPackageRegion(Package package, List<Region> regions);
        List<Region> SelectRegionsByPackageId(int packageID);
        ServiceResult UpdatePackage(Package package);
    }
}
