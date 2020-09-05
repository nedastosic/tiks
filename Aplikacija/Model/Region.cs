using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Model
{
    public class Region
    {
        public int RegionID { get; set; }
        [System.ComponentModel.DisplayName("Naziv regije")]
        public string Name { get; set; }
        [System.ComponentModel.DisplayName("Uključena u paket")]
        public bool Checked { get; set; } = false;
    }
}
