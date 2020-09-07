using Microsoft.VisualStudio.TestTools.UnitTesting;
using SkiPass.Model;
using SkiPass.Service;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SkiPass.Service.Tests
{
    [TestClass()]
    public class ServiceSkiPassTest
    {
        public SerivceSkiPass ServiceTest { get; set; }

        public string ConnectionString { get; set; }
        public ServiceSkiPassTest()
        {
            ConnectionTest();
            ServiceTest = new SerivceSkiPass(ConnectionString);
        }
        [TestMethod()]
        public void ConnectionTest()
        {
            ConnectionString = "Persist security info=false;Integrated security=SSPI;Data source=DESKTOP-HMK35GO;Initial catalog=SkiPass";
            try
            {
                using (SqlConnection conn = new SqlConnection(ConnectionString))
                {
                    conn.Open();
                }
            }
            catch (SqlException ex)
            {
                Assert.Fail();
            }

        }

        [TestMethod()]
        public void SelectUsersTest()
        {
            ServiceResult result =  ServiceTest.SelectUsers();

            if (result.Value.GetType() != typeof(List<User>))
                Assert.Fail();
        }

        [TestMethod()]
        public void SelectPackagesTest()
        {
            ServiceResult result = ServiceTest.SelectPackages();

            if (result.Value.GetType() != typeof(List<Package>))
                Assert.Fail();
        }

        [TestMethod()]
        public void SelectRegionsTest()
        {
            ServiceResult result = ServiceTest.SelectRegions();

            if (result.Value.GetType() != typeof(List<Region>))
                Assert.Fail();
        }
        [TestMethod()]
        public void SaveUpadateUserTest()
        {
            // arrange
            User user = new User()
            {
                Firstname = "tFirstName",
                Lastname = "tLastName",
                Email = "test@gmail.com",
                Phone = "+3815555",
                DateOfBirth = DateTime.Now,
                JMBG = "1206996715192"
            };
            // act
            user.UserID = (int)ServiceTest.SaveUpadateUser(user).Value;

            if (user.UserID <= 0)
                Assert.Fail("Can not save new user.");
            

        }

        [TestMethod()]
        public void InsertRentalTestFail()
        {
            Assert.ThrowsException<NullReferenceException>(() => _ = ServiceTest.InsertRental(null, null, null, null));
        }


        private void AddRegionFromPackage(Package pack)
        {
            ServiceTest.UpdatePackage(pack);
            Assert.AreEqual(pack.Regions.Count, ServiceTest.SelectRegionsByPackageId(pack.PackageID).Count);
        }

        private Region RemoveRegionFromPackage(Package pack)
        {
            Region testRegion = new Region();
            if (pack.Regions.Count > 1)
            {
                pack.Regions.FirstOrDefault().Status = Status.DELETE;
                testRegion = pack.Regions.FirstOrDefault();
            }

            ServiceTest.UpdatePackage(pack);
            pack.Regions.Remove(testRegion);


            Assert.AreEqual(pack.Regions.Count, ServiceTest.SelectRegionsByPackageId(pack.PackageID).Count);

            return testRegion;
        }

        [TestMethod()]
        public void SelectRegionsByPackageIdTest()
        {
            List<Package> packs = (List<Package>)ServiceTest.SelectPackages().Value;

            foreach (Package pack in packs)
            {
                pack.Regions = ServiceTest.SelectRegionsByPackageId(pack.PackageID);
                if (pack.Regions == null)
                { 
                    Assert.Fail("[Error]: Object Regions is null.");
                    return;
                }

                if (pack.Regions.Count == 0)
                {
                    Assert.Fail("[Error]: Package with id: <"+pack.PackageID+"> doesn't contain any regions.");
                    return;
                }
            }
        }

        [TestMethod()]
        public void UpdatePackageTest()
        {
            // arrange
            Package pack = ((List<Package>)ServiceTest.SelectPackages().Value).FirstOrDefault();
            pack.Regions = ServiceTest.SelectRegionsByPackageId(pack.PackageID);

            // act1 and assert
            Region testRegion = RemoveRegionFromPackage(pack);

            testRegion.Status = Status.ADD;
            pack.Regions.Add(testRegion);

            //act2 and assert
            AddRegionFromPackage(pack);
        }
    }
}