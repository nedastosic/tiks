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
        public bool isValid { get; set; }
        public string Message { get; set; }
    }
}
