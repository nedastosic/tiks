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
    public class ViewPackage: Form, IViewPackage
    {
        private TextBox txtNamePackage;
        private Label label1;
        private DataGridView grdRegions;
        private Button btnSave;
        private Label label2;
        public event EventHandler<EventArgsPackage> EventHendlerSavePackage;
        public event EventHandler<EventArgsPackage> EventHendlerUpdatePackage;
        public Mode ViewMode { get; set; } = Mode.NEW;
        public Package CurrentPackage { get; set; }

        public enum Mode
        { 
            NEW,
            EDIT
        }
        public ViewPackage()
        {
            InitializeComponent();
        }
        private void InitializeComponent()
        {
            this.txtNamePackage = new System.Windows.Forms.TextBox();
            this.label1 = new System.Windows.Forms.Label();
            this.grdRegions = new System.Windows.Forms.DataGridView();
            this.label2 = new System.Windows.Forms.Label();
            this.btnSave = new System.Windows.Forms.Button();
            ((System.ComponentModel.ISupportInitialize)(this.grdRegions)).BeginInit();
            this.SuspendLayout();
            // 
            // txtNamePackage
            // 
            this.txtNamePackage.Location = new System.Drawing.Point(47, 53);
            this.txtNamePackage.Name = "txtNamePackage";
            this.txtNamePackage.Size = new System.Drawing.Size(173, 22);
            this.txtNamePackage.TabIndex = 0;
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(47, 30);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(47, 17);
            this.label1.TabIndex = 1;
            this.label1.Text = "Naziv:";
            // 
            // grdRegions
            // 
            this.grdRegions.AutoSizeColumnsMode = System.Windows.Forms.DataGridViewAutoSizeColumnsMode.Fill;
            this.grdRegions.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grdRegions.Location = new System.Drawing.Point(47, 126);
            this.grdRegions.Name = "grdRegions";
            this.grdRegions.RowHeadersWidth = 51;
            this.grdRegions.RowTemplate.Height = 24;
            this.grdRegions.Size = new System.Drawing.Size(407, 134);
            this.grdRegions.TabIndex = 2;
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(47, 106);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(52, 17);
            this.label2.TabIndex = 3;
            this.label2.Text = "Regije:";
            // 
            // btnSave
            // 
            this.btnSave.Location = new System.Drawing.Point(338, 279);
            this.btnSave.Name = "btnSave";
            this.btnSave.Size = new System.Drawing.Size(116, 45);
            this.btnSave.TabIndex = 4;
            this.btnSave.Text = "Zapiši";
            this.btnSave.UseVisualStyleBackColor = true;
            this.btnSave.Click += new System.EventHandler(this.BtnSave_Click);
            // 
            // ViewPackage
            // 
            this.ClientSize = new System.Drawing.Size(506, 336);
            this.Controls.Add(this.btnSave);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.grdRegions);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.txtNamePackage);
            this.Name = "ViewPackage";
            this.Text = "Paket skipass";
            ((System.ComponentModel.ISupportInitialize)(this.grdRegions)).EndInit();
            this.ResumeLayout(false);
            this.PerformLayout();

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

        internal void NapuniFormu(Package package)
        {
            ViewMode = Mode.EDIT;
            txtNamePackage.Text = package.Name;
            CurrentPackage = package;

            foreach (Region reg in grdRegions.DataSource as List<Region>)
            {
                if (package.Regions.Contains(reg))
                    reg.Checked = true;
            }
        }

        internal void FillRegions(List<Region> listRegion)
        {
            foreach (Region reg in listRegion)
                reg.Checked = false;

            grdRegions.DataSource = listRegion;
            grdRegions.Columns["RegionID"].Visible = false;
            grdRegions.Columns["Status"].Visible = false;

            grdRegions.Columns["Name"].ReadOnly = true;
            grdRegions.Columns["Checked"].ReadOnly = false;
        }

        private void BtnSave_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(txtNamePackage.Text))
            {
                ErrorMessage("Morate uneti naziv paketa.");
                return;
            }

            if ((grdRegions.DataSource as List<Region>).FindAll(r => r.Checked).Count == 0)
            {
                ErrorMessage("Paket mora sadržati barem jednu regiju.");
                return;
            }

            switch (ViewMode)
            {
                case Mode.NEW:
                    EventHelper.Raise(this, EventHendlerSavePackage, new EventArgsPackage()
                    {
                        Package = new Package()
                        {
                            Name = txtNamePackage.Text
                        },
                        Regions = (grdRegions.DataSource as List<Region>).FindAll(r => r.Checked)
                    });
                    break;
                case Mode.EDIT:
                    EventHelper.Raise(this, EventHendlerUpdatePackage, new EventArgsPackage()
                    {
                        Package = new Package()
                        {
                            PackageID = CurrentPackage.PackageID,
                            Name = txtNamePackage.Text,
                            Regions = GetEditedRegions((grdRegions.DataSource as List<Region>).FindAll(r => r.Checked))
                        }
                    }) ; 
                    break;
            }
        }

        private List<Region> GetEditedRegions(List<Region> newRegions)
        {
            List<Region> list = CurrentPackage.Regions;

            foreach (Region reg in newRegions)
            {
                if (!CurrentPackage.Regions.Contains(reg))
                {
                    reg.Status = Status.ADD;
                    list.Add(reg);
                }
            }

            foreach (Region reg in CurrentPackage.Regions)
            { 
                if(!newRegions.Contains(reg))
                    reg.Status = Status.DELETE;
            }

            return list;
        }
    }
}
