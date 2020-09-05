using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Service
{
    public class ServiceResult
    {
        public object Value { get; set; }
        public bool IsValid { get; set; } = true;
        public string Message { get; set; }
    }
}
