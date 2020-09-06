using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Model
{
    public enum Status
    { 
        DEFAULT,
        ADD,
        DELETE
    }
    public class Region
    {
        public int RegionID { get; set; }
        [System.ComponentModel.DisplayName("Naziv regije")]
        public string Name { get; set; }
        [System.ComponentModel.DisplayName("Uključena u paket")]
        public bool Checked { get; set; } = false;
        public Status Status { get; set; } = Status.DEFAULT;

        public override bool Equals(object obj)
        {
            return this.RegionID == ((Region)obj).RegionID ? true : false;
        }
    }
}
