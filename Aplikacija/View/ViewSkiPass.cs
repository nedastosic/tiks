using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using SkiPass.Event;
using SkiPass.Model;

namespace SkiPass.View
{
    public class ViewSkiPass : Form, IViewSkiPass
    {
        private ToolStripMenuItem korisnikToolStripMenuItem;
        private ToolStripMenuItem registrujNovogKorisnikaToolStripMenuItem;
        private ComboBox cboKorisnik;
        private Label label1;
        private ComboBox cboSkiPass;
        private TextBox textBox1;
        private Label label2;
        private Label label3;
        private DateTimePicker datDatumOd;
        private Label label4;
        private DateTimePicker datDatumDo;
        private Label label5;
        private Button btnZapisi;
        private MenuStrip menuStrip1;

        public event EventHandler Init;

        public void ErrorMessage(string message)
        {
            MessageBox.Show(
                this,
                (message ?? string.Empty).Trim(),
                string.Empty,
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }

        public void InformationMessage(string message)
        {
            MessageBox.Show(
                this,
                (message ?? string.Empty).Trim(),
                string.Empty,
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
        }

        public void Initialize()
        {
            EventHelper.Raise(this, Init);
        }

        public void NapuniComboKorisnik(List<Korisnik> list)
        {
            cboKorisnik.DataSource = null;
            cboKorisnik.DataSource = list;
            cboKorisnik.ValueMember = "KorisnikID";
            cboKorisnik.DisplayMember = "ImePrezime";
        }

        public void NapuniComboPaketi(List<PaketSkiPass> value)
        {
            throw new NotImplementedException();
        }

        private void InitializeComponent()
        {
            this.menuStrip1 = new System.Windows.Forms.MenuStrip();
            this.korisnikToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.registrujNovogKorisnikaToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.cboKorisnik = new System.Windows.Forms.ComboBox();
            this.label1 = new System.Windows.Forms.Label();
            this.cboSkiPass = new System.Windows.Forms.ComboBox();
            this.textBox1 = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.label3 = new System.Windows.Forms.Label();
            this.datDatumOd = new System.Windows.Forms.DateTimePicker();
            this.label4 = new System.Windows.Forms.Label();
            this.datDatumDo = new System.Windows.Forms.DateTimePicker();
            this.label5 = new System.Windows.Forms.Label();
            this.btnZapisi = new System.Windows.Forms.Button();
            this.menuStrip1.SuspendLayout();
            this.SuspendLayout();
            // 
            // menuStrip1
            // 
            this.menuStrip1.ImageScalingSize = new System.Drawing.Size(20, 20);
            this.menuStrip1.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.korisnikToolStripMenuItem});
            this.menuStrip1.Location = new System.Drawing.Point(0, 0);
            this.menuStrip1.Name = "menuStrip1";
            this.menuStrip1.Size = new System.Drawing.Size(391, 30);
            this.menuStrip1.TabIndex = 0;
            this.menuStrip1.Text = "menuStrip1";
            // 
            // korisnikToolStripMenuItem
            // 
            this.korisnikToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.registrujNovogKorisnikaToolStripMenuItem});
            this.korisnikToolStripMenuItem.Name = "korisnikToolStripMenuItem";
            this.korisnikToolStripMenuItem.Size = new System.Drawing.Size(75, 26);
            this.korisnikToolStripMenuItem.Text = "Korisnik";
            // 
            // registrujNovogKorisnikaToolStripMenuItem
            // 
            this.registrujNovogKorisnikaToolStripMenuItem.Name = "registrujNovogKorisnikaToolStripMenuItem";
            this.registrujNovogKorisnikaToolStripMenuItem.Size = new System.Drawing.Size(258, 26);
            this.registrujNovogKorisnikaToolStripMenuItem.Text = "Registruj novog korisnika";
            this.registrujNovogKorisnikaToolStripMenuItem.Click += new System.EventHandler(this.registrujNovogKorisnikaToolStripMenuItem_Click);
            // 
            // cboKorisnik
            // 
            this.cboKorisnik.FormattingEnabled = true;
            this.cboKorisnik.Location = new System.Drawing.Point(51, 104);
            this.cboKorisnik.Name = "cboKorisnik";
            this.cboKorisnik.Size = new System.Drawing.Size(265, 24);
            this.cboKorisnik.TabIndex = 2;
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(48, 84);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(62, 17);
            this.label1.TabIndex = 3;
            this.label1.Text = "Korisnik:";
            // 
            // cboSkiPass
            // 
            this.cboSkiPass.FormattingEnabled = true;
            this.cboSkiPass.Location = new System.Drawing.Point(51, 168);
            this.cboSkiPass.Name = "cboSkiPass";
            this.cboSkiPass.Size = new System.Drawing.Size(265, 24);
            this.cboSkiPass.TabIndex = 5;
            // 
            // textBox1
            // 
            this.textBox1.Location = new System.Drawing.Point(51, 222);
            this.textBox1.Name = "textBox1";
            this.textBox1.Size = new System.Drawing.Size(164, 22);
            this.textBox1.TabIndex = 7;
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(48, 148);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(103, 17);
            this.label2.TabIndex = 6;
            this.label2.Text = "Paket ski pass:";
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(48, 202);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(92, 17);
            this.label3.TabIndex = 8;
            this.label3.Text = "Cena paketa:";
            // 
            // datDatumOd
            // 
            this.datDatumOd.Format = System.Windows.Forms.DateTimePickerFormat.Short;
            this.datDatumOd.Location = new System.Drawing.Point(51, 282);
            this.datDatumOd.Name = "datDatumOd";
            this.datDatumOd.Size = new System.Drawing.Size(164, 22);
            this.datDatumOd.TabIndex = 9;
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(48, 262);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(73, 17);
            this.label4.TabIndex = 10;
            this.label4.Text = "Datum od:";
            // 
            // datDatumDo
            // 
            this.datDatumDo.Format = System.Windows.Forms.DateTimePickerFormat.Short;
            this.datDatumDo.Location = new System.Drawing.Point(51, 343);
            this.datDatumDo.Name = "datDatumDo";
            this.datDatumDo.Size = new System.Drawing.Size(164, 22);
            this.datDatumDo.TabIndex = 11;
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(48, 323);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(73, 17);
            this.label5.TabIndex = 12;
            this.label5.Text = "Datum do:";
            // 
            // btnZapisi
            // 
            this.btnZapisi.Location = new System.Drawing.Point(212, 420);
            this.btnZapisi.Name = "btnZapisi";
            this.btnZapisi.Size = new System.Drawing.Size(104, 45);
            this.btnZapisi.TabIndex = 13;
            this.btnZapisi.Text = "Zapiši";
            this.btnZapisi.UseVisualStyleBackColor = true;
            // 
            // ViewSkiPass
            // 
            this.ClientSize = new System.Drawing.Size(391, 488);
            this.Controls.Add(this.btnZapisi);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.datDatumDo);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.datDatumOd);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.textBox1);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.cboSkiPass);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.cboKorisnik);
            this.Controls.Add(this.menuStrip1);
            this.MainMenuStrip = this.menuStrip1;
            this.Name = "ViewSkiPass";
            this.Text = "Izadavanje ski pass-a";
            this.menuStrip1.ResumeLayout(false);
            this.menuStrip1.PerformLayout();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        private void registrujNovogKorisnikaToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }
    }
}
