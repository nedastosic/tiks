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
                    result.isValid = true;
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
                    result.isValid = true;
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
            using (var command = new SqlCommand("dbo.[SkiPass.InsertUser]", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                if(user.UserID.HasValue)
                    command.Parameters.Add(new SqlParameter("@UserID", SqlDbType.BigInt)).Value = user.UserID;
                command.Parameters.Add(new SqlParameter("@Firstname", SqlDbType.NVarChar)).Value = user.Firstname;
                command.Parameters.Add(new SqlParameter("@Lastname", SqlDbType.NVarChar)).Value = user.Lastname;
                command.Parameters.Add(new SqlParameter("@JMBG", SqlDbType.NVarChar)).Value = user.JMBG;
                command.Parameters.Add(new SqlParameter("@DateOfBirth", SqlDbType.DateTime)).Value = user.DateOfBirth;
                command.Parameters.Add(new SqlParameter("@Phone", SqlDbType.NVarChar)).Value = user.Phone;
                command.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar)).Value = user.Email;
                conn.Open();
                try
                {
                    command.ExecuteNonQuery();
                }
                catch (Exception ex)
                {
                    result.isValid = false;
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

        public ServiceResult InsertRental(DateTime dateFrom, DateTime dateTo, Package package, User user)
        {
            ServiceResult result = new ServiceResult();

            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("dbo.[SkiPass.InsertUser]", conn)
            {
                CommandType = CommandType.StoredProcedure
            })
            {
                if (user.UserID.HasValue)
                    command.Parameters.Add(new SqlParameter("@UserID", SqlDbType.BigInt)).Value = user.UserID;
                command.Parameters.Add(new SqlParameter("@Firstname", SqlDbType.NVarChar)).Value = user.Firstname;
                command.Parameters.Add(new SqlParameter("@Lastname", SqlDbType.NVarChar)).Value = user.Lastname;
                command.Parameters.Add(new SqlParameter("@JMBG", SqlDbType.NVarChar)).Value = user.JMBG;
                command.Parameters.Add(new SqlParameter("@DateOfBirth", SqlDbType.DateTime)).Value = user.DateOfBirth;
                command.Parameters.Add(new SqlParameter("@Phone", SqlDbType.NVarChar)).Value = user.Phone;
                command.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar)).Value = user.Email;
                conn.Open();
                try
                {
                    command.ExecuteNonQuery();
                }
                catch (Exception ex)
                {
                    result.isValid = false;
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
