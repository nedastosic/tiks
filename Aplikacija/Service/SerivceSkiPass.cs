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

        public ServiceResult GetAllKorisnici()
        {
            ServiceResult result = new ServiceResult();
            List<Korisnik> list = new List<Korisnik>();
            using (var conn = new SqlConnection(ConnectionString))
            using (var command = new SqlCommand("SelectKorisnik", conn)
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
                        Korisnik korisnik = new Korisnik()
                        {
                            KorisnikID = Convert.ToInt32(reader["UserID"]),
                            Ime = Convert.ToString(reader["Firstname"]),
                            DatumRodjenja = Convert.ToDateTime(reader["DateOfBirth"]),
                            Prezime = Convert.ToString(reader["Lastname"]),
                            JMBG = Convert.ToString(reader["JMBG"]),
                            Telefon = Convert.ToString(reader["Phone"]),
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

        public ServiceResult GetAllPaketi()
        {
            throw new NotImplementedException();
        }
    }
}
