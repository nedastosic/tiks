using Microsoft.VisualStudio.TestTools.UnitTesting;
using SkiPass.Model;
using SkiPass.Service;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Service.Tests
{
    [TestClass()]
    public class SerivceSkiPassTests
    {
        public SerivceSkiPass serviceTest { get; set; }
        public string ConnectionString { get; set; } = "Persist security info=false;Integrated security=SSPI;Data source=DESKTOP-HMK35GO;Initial catalog=SkiPass";
        [TestMethod()]
        public void SerivceSkiPassTest()
        {
            serviceTest = new SerivceSkiPass(ConnectionString);
        }

        [TestMethod()]
        public void SelectUsersTest()
        {
            
        }

        [TestMethod()]
        public void SelectPackagesTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void SaveUpadateUserTest()
        {
            // arrange
            User user = null;
            var service = new SerivceSkiPass("");
            // act
            service.SaveUpadateUser(user);
            
            // assert
            Assert.IsNull(user);
        }

        [TestMethod()]
        public void InsertRentalTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void SelectSkiPassTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void SelectRegionsTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void InsertPackageRegionTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void SelectRegionsByPackageIdTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void UpdatePackageTest()
        {
            Assert.Fail();
        }
    }
}