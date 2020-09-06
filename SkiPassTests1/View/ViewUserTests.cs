using Microsoft.VisualStudio.TestTools.UnitTesting;
using SkiPass.View;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.View.Tests
{
    [TestClass()]
    public class ViewUserTests
    {
        [TestMethod()]
        public void ValidationEmailTest()
        {
            var view = new ViewUser();
            Assert.IsTrue(view.ValidationEmail("boba@gmail.com"));
        }

        [TestMethod()]
        public void ValidationEmailTestFail()
        {
            var view = new ViewUser();
            Assert.IsFalse(view.ValidationEmail("bobaaa.com"));
        }

        [TestMethod()]
        public void ValidationPhoneTest()
        {
            var view = new ViewUser();
            Assert.IsTrue(view.ValidationPhone("0656011065") && view.ValidationPhone("+3810656011065"));
        }

        [TestMethod()]
        public void ValidationPhoneTestFail()
        {
            var view = new ViewUser();
            Assert.IsFalse(view.ValidationPhone("0656asdsa011065"));
        }

        [TestMethod()]
        public void RequiredFieldsTestFail()
        {
            var view = new ViewUser();
            var date = new DateTime();
            Assert.IsFalse(view.RequiredFields(string.Empty, string.Empty, string.Empty, string.Empty, string.Empty,date));
        }
    }
}