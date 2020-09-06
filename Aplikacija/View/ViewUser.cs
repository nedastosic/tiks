using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using SkiPass.Event;
using SkiPass.Model;

namespace SkiPass.View
{
    public class ViewUser: Form, IVIewUser
    {
        public int? UserID { get; set; }
        public ViewUser()
        {
            InitializeComponent();
        }
        private TextBox txtFirstname;
        private TextBox txtLastname;
        private TextBox txtJMBG;
        private TextBox txtPhone;
        private TextBox txtEmail;
        private Label label1;
        private Label label2;
        private Label label3;
        private Label label4;
        private Label label5;
        private Label label6;
        private Button btnZapisi;
        private DateTimePicker datDateOfBirtf;

        public event EventHandler<EventArgsUser> EventHendlerSaveUser;

        private void InitializeComponent()
        {
            this.txtFirstname = new System.Windows.Forms.TextBox();
            this.txtLastname = new System.Windows.Forms.TextBox();
            this.txtJMBG = new System.Windows.Forms.TextBox();
            this.txtPhone = new System.Windows.Forms.TextBox();
            this.txtEmail = new System.Windows.Forms.TextBox();
            this.datDateOfBirtf = new System.Windows.Forms.DateTimePicker();
            this.label1 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.label3 = new System.Windows.Forms.Label();
            this.label4 = new System.Windows.Forms.Label();
            this.label5 = new System.Windows.Forms.Label();
            this.label6 = new System.Windows.Forms.Label();
            this.btnZapisi = new System.Windows.Forms.Button();
            this.SuspendLayout();
            // 
            // txtIme
            // 
            this.txtFirstname.Location = new System.Drawing.Point(103, 71);
            this.txtFirstname.Name = "txtIme";
            this.txtFirstname.Size = new System.Drawing.Size(224, 22);
            this.txtFirstname.TabIndex = 0;
            // 
            // txtPrezime
            // 
            this.txtLastname.Location = new System.Drawing.Point(103, 130);
            this.txtLastname.Name = "txtPrezime";
            this.txtLastname.Size = new System.Drawing.Size(224, 22);
            this.txtLastname.TabIndex = 1;
            // 
            // txtJMBG
            // 
            this.txtJMBG.Location = new System.Drawing.Point(103, 245);
            this.txtJMBG.Name = "txtJMBG";
            this.txtJMBG.Size = new System.Drawing.Size(224, 22);
            this.txtJMBG.TabIndex = 2;
            // 
            // txtTelefon
            // 
            this.txtPhone.Location = new System.Drawing.Point(103, 302);
            this.txtPhone.Name = "txtTelefon";
            this.txtPhone.Size = new System.Drawing.Size(224, 22);
            this.txtPhone.TabIndex = 3;
            // 
            // txtEmail
            // 
            this.txtEmail.Location = new System.Drawing.Point(103, 362);
            this.txtEmail.Name = "txtEmail";
            this.txtEmail.Size = new System.Drawing.Size(224, 22);
            this.txtEmail.TabIndex = 4;
            // 
            // datDatumRodjenja
            // 
            this.datDateOfBirtf.Format = System.Windows.Forms.DateTimePickerFormat.Short;
            this.datDateOfBirtf.Location = new System.Drawing.Point(103, 187);
            this.datDateOfBirtf.Name = "datDatumRodjenja";
            this.datDateOfBirtf.Size = new System.Drawing.Size(224, 22);
            this.datDateOfBirtf.TabIndex = 5;
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(103, 48);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(34, 17);
            this.label1.TabIndex = 6;
            this.label1.Text = "Ime:";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(103, 110);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(63, 17);
            this.label2.TabIndex = 7;
            this.label2.Text = "Prezime:";
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(103, 167);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(105, 17);
            this.label3.TabIndex = 8;
            this.label3.Text = "Datum rođenja:";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(103, 225);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(50, 17);
            this.label4.TabIndex = 9;
            this.label4.Text = "JMBG:";
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(103, 282);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(60, 17);
            this.label5.TabIndex = 10;
            this.label5.Text = "Telefon:";
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(103, 342);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(46, 17);
            this.label6.TabIndex = 11;
            this.label6.Text = "Email:";
            // 
            // btnZapisi
            // 
            this.btnZapisi.Location = new System.Drawing.Point(211, 413);
            this.btnZapisi.Name = "btnZapisi";
            this.btnZapisi.Size = new System.Drawing.Size(116, 40);
            this.btnZapisi.TabIndex = 13;
            this.btnZapisi.Text = "Zapiši";
            this.btnZapisi.UseVisualStyleBackColor = true;
            this.btnZapisi.Click += new System.EventHandler(this.ButtonZapisi_Click);
            // 
            // ViewKorisnik
            // 
            this.ClientSize = new System.Drawing.Size(465, 505);
            this.Controls.Add(this.btnZapisi);
            this.Controls.Add(this.label6);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.datDateOfBirtf);
            this.Controls.Add(this.txtEmail);
            this.Controls.Add(this.txtPhone);
            this.Controls.Add(this.txtJMBG);
            this.Controls.Add(this.txtLastname);
            this.Controls.Add(this.txtFirstname);
            this.Name = "ViewKorisnik";
            this.Text = "Registracija korisnika";
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        private void ButtonZapisi_Click(object sender, EventArgs e)
        {
            RequiredFields(txtFirstname.Text, txtLastname.Text, txtJMBG.Text, txtEmail.Text, txtPhone.Text, datDateOfBirtf.Value);
            ValidationEmail(txtEmail.Text);
            ValidationPhone(txtPhone.Text);

            EventHelper.Raise(this, EventHendlerSaveUser, new EventArgsUser()
            {
                User = new User()
                {
                    UserID = UserID,
                    Firstname = txtFirstname.Text,
                    Lastname = txtLastname.Text,
                    DateOfBirth = Convert.ToDateTime(datDateOfBirtf.Value),
                    Phone = txtPhone.Text,
                    Email = txtEmail.Text,
                    JMBG = txtJMBG.Text
                }
            });
        }

        public bool RequiredFields(string firstName, string lastName, string JMBG, string email, string phone, DateTime date)
        {
            if(string.IsNullOrEmpty(firstName) 
                || string.IsNullOrEmpty(lastName) 
                || string.IsNullOrEmpty(JMBG) 
                || string.IsNullOrEmpty(email) 
                || string.IsNullOrEmpty(phone) 
                || string.IsNullOrEmpty(Convert.ToString(date)))
                return false;
            return true;
        }

        public bool ValidationPhone(string phone)
        {
            if (Regex.Match(phone, @"^[0-9]*$").Success 
                || (phone.StartsWith("+381") && Regex.Match(phone.Substring(1), @"^[0-9]*$").Success))
                return true;

            return false;
        }

        public bool ValidationEmail(string email)
        {
            return Regex.IsMatch(email, @"^([0-9a-zA-Z]([-\.\w]*[0-9a-zA-Z])*@([0-9a-zA-Z][-\w]*[0-9a-zA-Z]\.)+[a-zA-Z]{2,9})$");
        }

        public void NapuniFormu(User user)
        {
            if (user == null)
                return;
            UserID = user.UserID;
            txtFirstname.Text= user.Firstname;
            txtLastname.Text = user.Lastname;
            txtJMBG.Text = user.JMBG;
            txtPhone.Text = user.Phone;
            txtEmail.Text = user.Email;
            datDateOfBirtf.Value = user.DateOfBirth.Value;
        }
    }
}
