﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Model
{
    public class User
    {
        public int KorisnikID { get; set; }
        public string Firstname { get; set; }
        public string Lastname { get; set; }
        public string JMBG { get; set; }
        public string Phone { get; set; }
        public string Email { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string Fullname {
            get
            {
                return Firstname + " " + Lastname;
            }
        }
    }
}