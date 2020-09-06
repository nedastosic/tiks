using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Model
{
    public class Package
    {
        public int PackageID { get; set; }
        public string Name { get; set; }
        public List<Region> Regions { get; set; }
    }
}
