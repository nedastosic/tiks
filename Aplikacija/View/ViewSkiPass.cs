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
        private ComboBox cboUser;
        private Label label1;
        private ComboBox cboPackage;
        private TextBox txtPrice;
        private Label label2;
        private Label lblPrice;
        private DateTimePicker datDateFrom;
        private Label label4;
        private DateTimePicker datDateTo;
        private Label label5;
        private Button btnZapisi;
        private ToolStripMenuItem paketToolStripMenuItem;
        private ToolStripMenuItem dodajNoviPaketToolStripMenuItem;
        private ContextMenuStrip contextMenuUsers;
        private System.ComponentModel.IContainer components;
        private ToolStripMenuItem changeUserToolStripMenuItem;
        private ContextMenuStrip contextMenuPackages;
        private ToolStripMenuItem changePackageToolStripMenuItem;
        private MenuStrip menuStrip1;

        public event EventHandler<EventArgsRental> EventHendlerInsertRental;
        public event EventHandler<EventArgsUser> EventHendlerSaveUser;
        public event EventHandler<EventArgsPackage> EventHendlerSavePackage;
        public event EventHandler EventHendlerRefresh;
        public List<Region> listRegion { get; set; }
        public ViewSkiPass()
        {
            InitializeComponent();
            txtPrice.Visible = false;
            lblPrice.Visible = false;
        }

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

        public void NapuniComboKorisnik(List<User> list)
        {
            cboUser.DataSource = null;
            cboUser.DataSource = list;
            cboUser.ValueMember = "UserID";
            cboUser.DisplayMember = "Fullname";
        }

        public void NapuniComboPaketi(List<Package> list)
        {
            cboPackage.DataSource = null;
            cboPackage.DataSource = list;
            cboPackage.ValueMember = "PackageID";
            cboPackage.DisplayMember = "Name";
        }

        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            this.menuStrip1 = new System.Windows.Forms.MenuStrip();
            this.korisnikToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.registrujNovogKorisnikaToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.paketToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.dodajNoviPaketToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.cboUser = new System.Windows.Forms.ComboBox();
            this.contextMenuUsers = new System.Windows.Forms.ContextMenuStrip(this.components);
            this.changeUserToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.label1 = new System.Windows.Forms.Label();
            this.cboPackage = new System.Windows.Forms.ComboBox();
            this.contextMenuPackages = new System.Windows.Forms.ContextMenuStrip(this.components);
            this.changePackageToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.txtPrice = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.lblPrice = new System.Windows.Forms.Label();
            this.datDateFrom = new System.Windows.Forms.DateTimePicker();
            this.label4 = new System.Windows.Forms.Label();
            this.datDateTo = new System.Windows.Forms.DateTimePicker();
            this.label5 = new System.Windows.Forms.Label();
            this.btnZapisi = new System.Windows.Forms.Button();
            this.menuStrip1.SuspendLayout();
            this.contextMenuUsers.SuspendLayout();
            this.contextMenuPackages.SuspendLayout();
            this.SuspendLayout();
            // 
            // menuStrip1
            // 
            this.menuStrip1.ImageScalingSize = new System.Drawing.Size(20, 20);
            this.menuStrip1.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.korisnikToolStripMenuItem,
            this.paketToolStripMenuItem});
            this.menuStrip1.Location = new System.Drawing.Point(0, 0);
            this.menuStrip1.Name = "menuStrip1";
            this.menuStrip1.Size = new System.Drawing.Size(437, 28);
            this.menuStrip1.TabIndex = 0;
            this.menuStrip1.Text = "menuStrip1";
            // 
            // korisnikToolStripMenuItem
            // 
            this.korisnikToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.registrujNovogKorisnikaToolStripMenuItem});
            this.korisnikToolStripMenuItem.Name = "korisnikToolStripMenuItem";
            this.korisnikToolStripMenuItem.Size = new System.Drawing.Size(75, 24);
            this.korisnikToolStripMenuItem.Text = "Korisnik";
            // 
            // registrujNovogKorisnikaToolStripMenuItem
            // 
            this.registrujNovogKorisnikaToolStripMenuItem.Name = "registrujNovogKorisnikaToolStripMenuItem";
            this.registrujNovogKorisnikaToolStripMenuItem.Size = new System.Drawing.Size(258, 26);
            this.registrujNovogKorisnikaToolStripMenuItem.Text = "Registruj novog korisnika";
            this.registrujNovogKorisnikaToolStripMenuItem.Click += new System.EventHandler(this.RegistrujNovogKorisnikaToolStripMenuItem_Click);
            // 
            // paketToolStripMenuItem
            // 
            this.paketToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.dodajNoviPaketToolStripMenuItem});
            this.paketToolStripMenuItem.Name = "paketToolStripMenuItem";
            this.paketToolStripMenuItem.Size = new System.Drawing.Size(58, 24);
            this.paketToolStripMenuItem.Text = "Paket";
            // 
            // dodajNoviPaketToolStripMenuItem
            // 
            this.dodajNoviPaketToolStripMenuItem.Name = "dodajNoviPaketToolStripMenuItem";
            this.dodajNoviPaketToolStripMenuItem.Size = new System.Drawing.Size(224, 26);
            this.dodajNoviPaketToolStripMenuItem.Text = "Dodaj novi paket";
            this.dodajNoviPaketToolStripMenuItem.Click += new System.EventHandler(this.DodajNoviPaketToolStripMenuItem_Click);
            // 
            // cboUser
            // 
            this.cboUser.ContextMenuStrip = this.contextMenuUsers;
            this.cboUser.FormattingEnabled = true;
            this.cboUser.Location = new System.Drawing.Point(51, 104);
            this.cboUser.Name = "cboUser";
            this.cboUser.Size = new System.Drawing.Size(265, 24);
            this.cboUser.TabIndex = 2;
            // 
            // contextMenuUsers
            // 
            this.contextMenuUsers.ImageScalingSize = new System.Drawing.Size(20, 20);
            this.contextMenuUsers.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.changeUserToolStripMenuItem});
            this.contextMenuUsers.Name = "contextMenuUsers";
            this.contextMenuUsers.Size = new System.Drawing.Size(185, 28);
            // 
            // changeUserToolStripMenuItem
            // 
            this.changeUserToolStripMenuItem.Name = "changeUserToolStripMenuItem";
            this.changeUserToolStripMenuItem.Size = new System.Drawing.Size(184, 24);
            this.changeUserToolStripMenuItem.Text = "Izmeni korisnika";
            this.changeUserToolStripMenuItem.Click += new System.EventHandler(this.ChangeUserToolStripMenuItem_Click_1);
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
            // cboPackage
            // 
            this.cboPackage.ContextMenuStrip = this.contextMenuPackages;
            this.cboPackage.FormattingEnabled = true;
            this.cboPackage.Location = new System.Drawing.Point(51, 168);
            this.cboPackage.Name = "cboPackage";
            this.cboPackage.Size = new System.Drawing.Size(265, 24);
            this.cboPackage.TabIndex = 5;
            // 
            // contextMenuPackages
            // 
            this.contextMenuPackages.ImageScalingSize = new System.Drawing.Size(20, 20);
            this.contextMenuPackages.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.changePackageToolStripMenuItem});
            this.contextMenuPackages.Name = "contextMenuPackages";
            this.contextMenuPackages.Size = new System.Drawing.Size(164, 28);
            // 
            // changePackageToolStripMenuItem
            // 
            this.changePackageToolStripMenuItem.Name = "changePackageToolStripMenuItem";
            this.changePackageToolStripMenuItem.Size = new System.Drawing.Size(163, 24);
            this.changePackageToolStripMenuItem.Text = "Izmeni paket";
            this.changePackageToolStripMenuItem.Click += new System.EventHandler(this.ChangePackageToolStripMenuItem_Click);
            // 
            // txtPrice
            // 
            this.txtPrice.Enabled = false;
            this.txtPrice.Location = new System.Drawing.Point(51, 368);
            this.txtPrice.Name = "txtPrice";
            this.txtPrice.Size = new System.Drawing.Size(164, 22);
            this.txtPrice.TabIndex = 7;
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
            // lblPrice
            // 
            this.lblPrice.AutoSize = true;
            this.lblPrice.Location = new System.Drawing.Point(48, 348);
            this.lblPrice.Name = "lblPrice";
            this.lblPrice.Size = new System.Drawing.Size(365, 17);
            this.lblPrice.TabIndex = 8;
            this.lblPrice.Text = "Cena paketa (na osnovu izabranog paketa i broja dana):";
            // 
            // datDateFrom
            // 
            this.datDateFrom.Format = System.Windows.Forms.DateTimePickerFormat.Short;
            this.datDateFrom.Location = new System.Drawing.Point(51, 235);
            this.datDateFrom.Name = "datDateFrom";
            this.datDateFrom.Size = new System.Drawing.Size(164, 22);
            this.datDateFrom.TabIndex = 9;
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(48, 205);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(73, 17);
            this.label4.TabIndex = 10;
            this.label4.Text = "Datum od:";
            // 
            // datDateTo
            // 
            this.datDateTo.Format = System.Windows.Forms.DateTimePickerFormat.Short;
            this.datDateTo.Location = new System.Drawing.Point(51, 302);
            this.datDateTo.Name = "datDateTo";
            this.datDateTo.Size = new System.Drawing.Size(164, 22);
            this.datDateTo.TabIndex = 11;
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(48, 271);
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
            this.btnZapisi.Click += new System.EventHandler(this.BtnZapisi_Click);
            // 
            // ViewSkiPass
            // 
            this.ClientSize = new System.Drawing.Size(437, 494);
            this.Controls.Add(this.btnZapisi);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.datDateTo);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.datDateFrom);
            this.Controls.Add(this.lblPrice);
            this.Controls.Add(this.txtPrice);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.cboPackage);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.cboUser);
            this.Controls.Add(this.menuStrip1);
            this.MainMenuStrip = this.menuStrip1;
            this.Name = "ViewSkiPass";
            this.Text = "Izadavanje ski pass-a";
            this.menuStrip1.ResumeLayout(false);
            this.menuStrip1.PerformLayout();
            this.contextMenuUsers.ResumeLayout(false);
            this.contextMenuPackages.ResumeLayout(false);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        private void RegistrujNovogKorisnikaToolStripMenuItem_Click(object sender, EventArgs e)
        {
            using (ViewUser form = new ViewUser())
            {
                form.EventHendlerSaveUser -= this.EventHendlerSaveUserChildForm;
                form.EventHendlerSaveUser += this.EventHendlerSaveUserChildForm;
                form.ShowDialog();
            }
        }

        private void EventHendlerSaveUserChildForm(object sender, EventArgsUser e)
        {
            EventHelper.Raise(this, EventHendlerSaveUser, new EventArgsUser()
            {
                User = e.User
            });
        }

        private void BtnZapisi_Click(object sender, EventArgs e)
        {
            EventHelper.Raise(this, EventHendlerInsertRental, new EventArgsRental()
            {
                DateFrom = Convert.ToDateTime(datDateFrom.Value),
                DateTo = Convert.ToDateTime(datDateTo.Value),
                Package = cboPackage.SelectedItem as Package,
                User = cboUser.SelectedItem as User
            });
        }

        private void RefreshForm()
        {
            EventHelper.Raise(this, EventHendlerRefresh);
            txtPrice.Visible = false;
            lblPrice.Visible = false;
        }

        private void ChangeUserToolStripMenuItem_Click_1(object sender, EventArgs e)
        {
            if (cboUser.SelectedItem is null)
            {
                InformationMessage("Morate izabrati korisnika iz combo box-a.");
                return;
            }

            using (ViewUser form = new ViewUser())
            {
                form.EventHendlerSaveUser -= this.EventHendlerSaveUserChildForm;
                form.EventHendlerSaveUser += this.EventHendlerSaveUserChildForm;
                form.NapuniFormu(cboUser.SelectedItem as User);
                form.ShowDialog();
            }

            RefreshForm();
        }

        private void ChangePackageToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (cboPackage.SelectedItem is null)
            {
                InformationMessage("Morate izabrati korisnika iz combo box-a.");
                return;
            }

            using (ViewPackage form = new ViewPackage())
            {
                form.EventHendlerSavePackage -= this.EventHendlerSavePackageChildForm;
                form.EventHendlerSavePackage += this.EventHendlerSavePackageChildForm;
                form.NapuniFormu(cboPackage.SelectedItem as Package);
                form.ShowDialog();
            }

            RefreshForm();
        }

        private void EventHendlerSavePackageChildForm(object sender, EventArgsPackage e)
        {
            EventHelper.Raise(this, EventHendlerSavePackage, new EventArgsPackage()
            {
                Package = e.Package,
                Regions = e.Regions
            });
        }

        public void ShowPrice(decimal price)
        {
            txtPrice.Text = Convert.ToString(price);
            txtPrice.Visible = true;
            lblPrice.Visible = true;
        }

        private void DodajNoviPaketToolStripMenuItem_Click(object sender, EventArgs e)
        {
            using (ViewPackage form = new ViewPackage())
            {
                form.EventHendlerSavePackage += this.EventHendlerSavePackageChildForm;
                form.FillRegions(listRegion);
                form.ShowDialog();
            }
        }

        public void SetRegions(List<Region> regions)
        {
            listRegion = regions;
        }
    }
}
