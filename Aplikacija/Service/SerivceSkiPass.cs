using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SkiPass.Model;

namespace SkiPass.Service
{
    public class SerivceSkiPass : IServiceSkiPass
    {
        private string ConnectionString;

        public SerivceSkiPass(string connectionString)
        {
            this.ConnectionString = connectionString;
        }

        public IDictionary<string, string> Connections { get ; set ; }

        public ServiceResult SelectUsers()
        {
            ServiceResult result = new ServiceResult();
            List<User> list = new List<User>();
            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("SelectUser", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                conn.Open();
                SqlDataReader reader = command.ExecuteReader();
                try
                {
                    while (reader.Read())
                    {
                        User korisnik = new User()
                        {
                            UserID = Convert.ToInt32(reader["UserID"]),
                            Firstname = Convert.ToString(reader["Firstname"]),
                            DateOfBirth = Convert.ToDateTime(reader["DateOfBirth"]),
                            Lastname = Convert.ToString(reader["Lastname"]),
                            JMBG = Convert.ToString(reader["JMBG"]),
                            Phone = Convert.ToString(reader["Phone"]),
                            Email = Convert.ToString(reader["Email"]),
                        };
                        list.Add(korisnik);
                    }
                    result.Value = list;
                    result.IsValid = true;
                    result.Message = "Uspesno obavljeno.";
                }
                finally
                {
                    reader.Close();
                }
            }

            return result;
        }

        public ServiceResult SelectPackages()
        {
            ServiceResult result = new ServiceResult();
            List<Package> list = new List<Package>();
            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("SelectPaket", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                conn.Open();
                SqlDataReader reader = command.ExecuteReader();
                try
                {
                    while (reader.Read())
                    {
                        Package package = new Package()
                        {
                            PackageID = Convert.ToInt32(reader["PackageID"]),
                            Name = Convert.ToString(reader["Name"])
                        };
                        list.Add(package);
                    }
                    result.Value = list;
                    result.IsValid = true;
                    result.Message = "Uspesno obavljeno.";
                }
                finally
                {
                    reader.Close();
                }
            }

            return result;
        }

        public ServiceResult SaveUpadateUser(User user)
        {
            ServiceResult result = new ServiceResult();
            
            using (var conn = new SqlConnection(ConnectionString))
            using (var adapter = new SqlDataAdapter()
            {
                SelectCommand = new SqlCommand("dbo.[SkiPass.InsertUser]", conn)
                {
                    CommandType = CommandType.StoredProcedure
                }

            })
            {
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@UserID", SqlDbType.BigInt)).Value = user.UserID == null ? -2: user.UserID;
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@Firstname", SqlDbType.NVarChar)).Value = user.Firstname;
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@Lastname", SqlDbType.NVarChar)).Value = user.Lastname;
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@JMBG", SqlDbType.NVarChar)).Value = user.JMBG;
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@DateOfBirth", SqlDbType.DateTime)).Value = user.DateOfBirth;
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@Phone", SqlDbType.NVarChar)).Value = user.Phone;
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar)).Value = user.Email;
                conn.Open();
                try
                {
                    DataSet ds = new DataSet();
                    adapter.Fill(ds, "result_name");

                    DataTable dt = ds.Tables["result_name"];

                    foreach (DataRow row in dt.Rows)
                    {
                        result.Value = Convert.ToInt32(row["ID"]);
                    }

                }
                catch (Exception ex)
                {
                    result.IsValid = false;
                    result.Message = ex.Message;
                    return result;
                }
                finally
                {
                }
            }
            result.Message = "Uspešno obavljeno.";
            return result;
        }

        public ServiceResult InsertRental(DateTime? dateFrom, DateTime? dateTo, Package package, User user)
        {
            ServiceResult result = InsertSkiPass(package.PackageID);

            if (!result.IsValid)
                return result;


            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("dbo.[SkiPass.InsertRental]", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                command.Parameters.Add(new SqlParameter("@RentalDate", SqlDbType.DateTime)).Value = DateTime.Now;
                command.Parameters.Add(new SqlParameter("@UserID", SqlDbType.BigInt)).Value = user.UserID;
                command.Parameters.Add(new SqlParameter("@SkiPassID", SqlDbType.BigInt)).Value = (int)result.Value;
                command.Parameters.Add(new SqlParameter("@ValidFrom", SqlDbType.DateTime)).Value = dateFrom;
                command.Parameters.Add(new SqlParameter("@ValidTo", SqlDbType.DateTime)).Value = dateTo;
                conn.Open();
                try
                {
                    command.ExecuteNonQuery();
                }
                catch (Exception ex)
                {
                    result.IsValid = false;
                    result.Message = ex.Message;
                    return result;
                }
                finally
                {
                }
            }
            result.Message = "Uspešno obavljeno.";
            return result;
        }

        private ServiceResult InsertSkiPass(int packageID)
        {
            ServiceResult result = new ServiceResult();
            using (var conn = new SqlConnection(ConnectionString))
            using (var adapter = new SqlDataAdapter()
            {
                SelectCommand = new SqlCommand("dbo.[SkiPass.InsertSkiPass]", conn)
                { 
                    CommandType = CommandType.StoredProcedure
                }
                
            })
            {
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@PackageID", SqlDbType.BigInt)).Value = packageID;
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@Status", SqlDbType.Bit)).Value = 1;
                conn.Open();
                try
                {
                    DataSet ds = new DataSet();
                    adapter.Fill(ds, "result_name");

                    DataTable dt = ds.Tables["result_name"];

                    foreach (DataRow row in dt.Rows)
                    {
                        result.Value = Convert.ToInt32(row["ID"]);
                    }
                }
                catch (Exception ex)
                {
                    result.Message = ex.Message;
                    result.IsValid = false;
                }
                finally
                {
                }

                return result;
            }
        }

        public ServiceResult SelectSkiPass(int idSkiPass)
        {
            ServiceResult result = new ServiceResult();
            decimal price = 0;
            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("SelectSkiPass", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                conn.Open();
                command.Parameters.Add(new SqlParameter("@SkiPassID", SqlDbType.BigInt)).Value = idSkiPass;
                SqlDataReader reader = command.ExecuteReader();
                try
                {
                    while (reader.Read())
                    {
                        price = Convert.ToDecimal(reader["Price"]);
                    }
                    result.Value = price;
                    result.IsValid = true;
                    result.Message = "Uspesno obavljeno.";
                }
                finally
                {
                    reader.Close();
                }
            }

            return result;
        }

        public ServiceResult SelectRegions()
        {
            ServiceResult result = new ServiceResult();
            List<Region> list = new List<Region>();
            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("SelectRegions", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                conn.Open();
                SqlDataReader reader = command.ExecuteReader();
                try
                {
                    while (reader.Read())
                    {
                        Region region = new Region()
                        {
                            RegionID = Convert.ToInt32(reader["RegionID"]),
                            Name = Convert.ToString(reader["Name"])
                        };
                        list.Add(region);
                    }
                    result.Value = list;
                    result.IsValid = true;
                    result.Message = "Uspesno obavljeno.";
                }
                finally
                {
                    reader.Close();
                }
            }

            return result;
        }

        public ServiceResult InsertPackageRegion(Package package, List<Region> regions)
        {
            ServiceResult result = InsertPackage(package.Name);

            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("dbo.[InsertPackageRegion]", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                
                command.Parameters.Add(new SqlParameter("@PackageID", SqlDbType.BigInt)).Value = (int)result.Value;
                command.Parameters.Add(new SqlParameter("@RegionID", SqlDbType.BigInt));
                conn.Open();

                try
                {
                    foreach (Region reg in regions)
                    {
                        command.Parameters["@RegionID"].Value = reg.RegionID;
                        command.ExecuteNonQuery();
                    }
                }
                catch (Exception ex)
                {
                    result.IsValid = false;
                    result.Message = ex.Message;
                    return result;
                }
                finally
                {
                }
            }
            result.Message = "Uspešno obavljeno.";
            return result;
        }

        private ServiceResult InsertPackage(string name)
        {
            ServiceResult result = new ServiceResult();
            using (var conn = new SqlConnection(ConnectionString))
            using (var adapter = new SqlDataAdapter()
            {
                SelectCommand = new SqlCommand("dbo.[InsertPackage]", conn)
                {
                    CommandType = CommandType.StoredProcedure
                }

            })
            {
                adapter.SelectCommand.Parameters.Add(new SqlParameter("@PackageName", SqlDbType.NVarChar)).Value = name;
                conn.Open();
                try
                {
                    DataSet ds = new DataSet();
                    adapter.Fill(ds, "result_name");

                    DataTable dt = ds.Tables["result_name"];

                    foreach (DataRow row in dt.Rows)
                    {
                        result.Value = Convert.ToInt32(row["ID"]);
                    }
                }
                catch (Exception ex)
                {
                    result.Message = ex.Message;
                    result.IsValid = false;
                }
                finally
                {
                }

                return result;
            }
        }

        public List<Region> SelectRegionsByPackageId(int packageID)
        {
            List<Region> list = new List<Region>();

            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("SelectRegion", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                conn.Open();
                command.Parameters.Add(new SqlParameter("@PackageID", SqlDbType.BigInt)).Value = packageID;
                SqlDataReader reader = command.ExecuteReader();
                try
                {
                    while (reader.Read())
                    {
                        Region region = new Region()
                        {
                            RegionID = Convert.ToInt32(reader["RegionID"]),
                            Name = Convert.ToString(reader["Name"]),
                            Checked = true
                        };
                        list.Add(region);
                    }
                }
                finally
                {
                    reader.Close();
                }
            }
            return list;
        }

        public ServiceResult UpdatePackage(Package package)
        {
            ServiceResult result = UpdatePackageName(package.PackageID, package.Name);
            if (!result.IsValid)
            {
                result.Message = "Greška prilikom update-a paketa.";
                result.IsValid = false;
                return result;
            }

            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                try
                {
                    command.Parameters.Add(new SqlParameter("@PackageID", SqlDbType.BigInt)).Value = package.PackageID;
                    command.Parameters.Add(new SqlParameter("@RegionID", SqlDbType.BigInt));
                    conn.Open();
                    foreach (Region reg in package.Regions)
                    {
                        command.Parameters["@RegionID"].Value = reg.RegionID;
                        if (reg.Status == Status.DEFAULT)
                            continue;

                        if (reg.Status == Status.ADD)
                            command.CommandText = "dbo.[InsertPackageRegion]";

                        if (reg.Status == Status.DELETE)
                            command.CommandText = "dbo.[DeleteRegionFromPackage]";

                        command.ExecuteNonQuery();
                    }
                }
                catch (Exception ex)
                {
                    result.IsValid = false;
                    result.Message = ex.Message;
                    return result;
                }
                finally
                {
                }
            }
            result.Message = "Uspešno obavljeno.";
            return result;
        }

        private ServiceResult UpdatePackageName(int packageID, string name)
        {
            ServiceResult result = new ServiceResult();
            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("dbo.[UpdatePackage]", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                command.Parameters.Add(new SqlParameter("@PackageID", SqlDbType.NVarChar)).Value = packageID;
                command.Parameters.Add(new SqlParameter("@Name", SqlDbType.NVarChar)).Value = name;
                conn.Open();
                try
                {
                    command.ExecuteNonQuery();
                }
                catch (Exception ex)
                {
                    result.IsValid = false;
                    result.Message = ex.Message;
                    return result;
                }
                finally
                {
                }
            }
            result.Message = "Uspešno obavljeno.";
            return result;
        }
    }
}
