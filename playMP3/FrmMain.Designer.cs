namespace playMP3
{
    partial class frmMain
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(frmMain));
            this.btnBrowse = new System.Windows.Forms.Button();
            this.txtFilePath = new System.Windows.Forms.TextBox();
            this.txtLength = new System.Windows.Forms.TextBox();
            this.lblLength = new System.Windows.Forms.Label();
            this.txtPosition = new System.Windows.Forms.TextBox();
            this.label1 = new System.Windows.Forms.Label();
            this.openFileDialog1 = new System.Windows.Forms.OpenFileDialog();
            this.txtNextPosition = new System.Windows.Forms.TextBox();
            this.txtTranscript = new System.Windows.Forms.TextBox();
            this.grvRow = new System.Windows.Forms.DataGridView();
            this.FirstDuration = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.RowContent = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.LastDuration = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Group = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.txtResult = new System.Windows.Forms.TextBox();
            this.btnConvertToGrid = new System.Windows.Forms.Button();
            this.btnConvertGridToResult = new System.Windows.Forms.Button();
            this.txtGroupResult = new System.Windows.Forms.TextBox();
            this.txtActor = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.label3 = new System.Windows.Forms.Label();
            this.label4 = new System.Windows.Forms.Label();
            this.label5 = new System.Windows.Forms.Label();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.label6 = new System.Windows.Forms.Label();
            this.label7 = new System.Windows.Forms.Label();
            this.btnReward = new System.Windows.Forms.Button();
            this.btnPlay = new System.Windows.Forms.Button();
            this.btnForward = new System.Windows.Forms.Button();
            this.groupBox2 = new System.Windows.Forms.GroupBox();
            this.label17 = new System.Windows.Forms.Label();
            this.label21 = new System.Windows.Forms.Label();
            this.label18 = new System.Windows.Forms.Label();
            this.label16 = new System.Windows.Forms.Label();
            this.txtSecret = new System.Windows.Forms.TextBox();
            this.txtApiKey = new System.Windows.Forms.TextBox();
            this.txtUrl = new System.Windows.Forms.TextBox();
            this.btnConfig = new System.Windows.Forms.Button();
            this.cbCloudService = new System.Windows.Forms.ComboBox();
            this.groupBox3 = new System.Windows.Forms.GroupBox();
            this.btnSubmitAndAddNew = new System.Windows.Forms.Button();
            this.txtDuration = new System.Windows.Forms.NumericUpDown();
            this.btnGetLink = new System.Windows.Forms.Button();
            this.txtThumb = new System.Windows.Forms.TextBox();
            this.btnImageLink = new System.Windows.Forms.Button();
            this.label20 = new System.Windows.Forms.Label();
            this.txtGrammar = new System.Windows.Forms.TextBox();
            this.label15 = new System.Windows.Forms.Label();
            this.btnSubmit = new System.Windows.Forms.Button();
            this.txtHomeNumber = new System.Windows.Forms.TextBox();
            this.label38 = new System.Windows.Forms.Label();
            this.txtNumber = new System.Windows.Forms.TextBox();
            this.label19 = new System.Windows.Forms.Label();
            this.txtSummary = new System.Windows.Forms.TextBox();
            this.label14 = new System.Windows.Forms.Label();
            this.txtVocab = new System.Windows.Forms.TextBox();
            this.label13 = new System.Windows.Forms.Label();
            this.label22 = new System.Windows.Forms.Label();
            this.txtSecondfileUrl = new System.Windows.Forms.TextBox();
            this.label12 = new System.Windows.Forms.Label();
            this.dpPublishDate = new System.Windows.Forms.DateTimePicker();
            this.label10 = new System.Windows.Forms.Label();
            this.cbYear = new System.Windows.Forms.ComboBox();
            this.cbType = new System.Windows.Forms.ComboBox();
            this.cbCategory = new System.Windows.Forms.ComboBox();
            this.txtFileUrl = new System.Windows.Forms.TextBox();
            this.txtEpisodeName = new System.Windows.Forms.TextBox();
            this.label8 = new System.Windows.Forms.Label();
            this.txtId = new System.Windows.Forms.TextBox();
            this.label9 = new System.Windows.Forms.Label();
            this.label40 = new System.Windows.Forms.Label();
            this.label11 = new System.Windows.Forms.Label();
            this.tabControl1 = new System.Windows.Forms.TabControl();
            this.tabPage1 = new System.Windows.Forms.TabPage();
            this.tabPage2 = new System.Windows.Forms.TabPage();
            ((System.ComponentModel.ISupportInitialize)(this.grvRow)).BeginInit();
            this.groupBox1.SuspendLayout();
            this.groupBox2.SuspendLayout();
            this.groupBox3.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.txtDuration)).BeginInit();
            this.tabControl1.SuspendLayout();
            this.tabPage1.SuspendLayout();
            this.SuspendLayout();
            // 
            // btnBrowse
            // 
            this.btnBrowse.Location = new System.Drawing.Point(373, 12);
            this.btnBrowse.Name = "btnBrowse";
            this.btnBrowse.Size = new System.Drawing.Size(92, 23);
            this.btnBrowse.TabIndex = 0;
            this.btnBrowse.Text = "Browse";
            this.btnBrowse.UseVisualStyleBackColor = true;
            this.btnBrowse.Click += new System.EventHandler(this.btnBrowse_Click);
            // 
            // txtFilePath
            // 
            this.txtFilePath.Location = new System.Drawing.Point(59, 13);
            this.txtFilePath.Name = "txtFilePath";
            this.txtFilePath.ReadOnly = true;
            this.txtFilePath.Size = new System.Drawing.Size(308, 20);
            this.txtFilePath.TabIndex = 1;
            // 
            // txtLength
            // 
            this.txtLength.Location = new System.Drawing.Point(59, 41);
            this.txtLength.Name = "txtLength";
            this.txtLength.Size = new System.Drawing.Size(88, 20);
            this.txtLength.TabIndex = 5;
            // 
            // lblLength
            // 
            this.lblLength.AutoSize = true;
            this.lblLength.Location = new System.Drawing.Point(6, 44);
            this.lblLength.Name = "lblLength";
            this.lblLength.Size = new System.Drawing.Size(40, 13);
            this.lblLength.TabIndex = 6;
            this.lblLength.Text = "Length";
            // 
            // txtPosition
            // 
            this.txtPosition.Location = new System.Drawing.Point(209, 41);
            this.txtPosition.Name = "txtPosition";
            this.txtPosition.Size = new System.Drawing.Size(100, 20);
            this.txtPosition.TabIndex = 5;
            this.txtPosition.Click += new System.EventHandler(this.txtPosition_Click);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(153, 44);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(50, 13);
            this.label1.TabIndex = 6;
            this.label1.Text = "Start Pos";
            // 
            // openFileDialog1
            // 
            this.openFileDialog1.FileName = "openFileDialog1";
            // 
            // txtNextPosition
            // 
            this.txtNextPosition.Location = new System.Drawing.Point(373, 41);
            this.txtNextPosition.Name = "txtNextPosition";
            this.txtNextPosition.Size = new System.Drawing.Size(92, 20);
            this.txtNextPosition.TabIndex = 8;
            this.txtNextPosition.Click += new System.EventHandler(this.txtNextPosition_Click);
            // 
            // txtTranscript
            // 
            this.txtTranscript.Location = new System.Drawing.Point(127, 101);
            this.txtTranscript.Multiline = true;
            this.txtTranscript.Name = "txtTranscript";
            this.txtTranscript.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtTranscript.Size = new System.Drawing.Size(336, 146);
            this.txtTranscript.TabIndex = 9;
            this.txtTranscript.Leave += new System.EventHandler(this.txtTranscript_Leave);
            // 
            // grvRow
            // 
            this.grvRow.AllowUserToAddRows = false;
            this.grvRow.AllowUserToDeleteRows = false;
            this.grvRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.FirstDuration,
            this.RowContent,
            this.LastDuration,
            this.Group});
            this.grvRow.Location = new System.Drawing.Point(8, 6);
            this.grvRow.Name = "grvRow";
            this.grvRow.Size = new System.Drawing.Size(591, 653);
            this.grvRow.TabIndex = 11;
            // 
            // FirstDuration
            // 
            this.FirstDuration.DataPropertyName = "FirstDuration";
            this.FirstDuration.HeaderText = "Start Pos";
            this.FirstDuration.Name = "FirstDuration";
            this.FirstDuration.Width = 80;
            // 
            // RowContent
            // 
            this.RowContent.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.RowContent.DataPropertyName = "RowContent";
            this.RowContent.HeaderText = "Row Content";
            this.RowContent.Name = "RowContent";
            // 
            // LastDuration
            // 
            this.LastDuration.DataPropertyName = "LastDuration";
            this.LastDuration.FillWeight = 60F;
            this.LastDuration.HeaderText = "End Pos";
            this.LastDuration.Name = "LastDuration";
            // 
            // Group
            // 
            this.Group.DataPropertyName = "Group";
            this.Group.HeaderText = "Group";
            this.Group.Name = "Group";
            this.Group.Width = 50;
            // 
            // txtResult
            // 
            this.txtResult.Location = new System.Drawing.Point(127, 316);
            this.txtResult.Multiline = true;
            this.txtResult.Name = "txtResult";
            this.txtResult.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtResult.Size = new System.Drawing.Size(338, 202);
            this.txtResult.TabIndex = 13;
            // 
            // btnConvertToGrid
            // 
            this.btnConvertToGrid.Location = new System.Drawing.Point(469, 162);
            this.btnConvertToGrid.Name = "btnConvertToGrid";
            this.btnConvertToGrid.Size = new System.Drawing.Size(27, 23);
            this.btnConvertToGrid.TabIndex = 10;
            this.btnConvertToGrid.Text = ">>";
            this.btnConvertToGrid.UseVisualStyleBackColor = true;
            this.btnConvertToGrid.Click += new System.EventHandler(this.btnConvertToGrid_Click);
            // 
            // btnConvertGridToResult
            // 
            this.btnConvertGridToResult.Location = new System.Drawing.Point(471, 405);
            this.btnConvertGridToResult.Name = "btnConvertGridToResult";
            this.btnConvertGridToResult.Size = new System.Drawing.Size(27, 23);
            this.btnConvertGridToResult.TabIndex = 12;
            this.btnConvertGridToResult.Text = "<<";
            this.btnConvertGridToResult.UseVisualStyleBackColor = true;
            this.btnConvertGridToResult.Click += new System.EventHandler(this.btnConvertGridToResult_Click);
            // 
            // txtGroupResult
            // 
            this.txtGroupResult.Location = new System.Drawing.Point(127, 524);
            this.txtGroupResult.Multiline = true;
            this.txtGroupResult.Name = "txtGroupResult";
            this.txtGroupResult.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtGroupResult.Size = new System.Drawing.Size(338, 268);
            this.txtGroupResult.TabIndex = 14;
            // 
            // txtActor
            // 
            this.txtActor.Location = new System.Drawing.Point(127, 253);
            this.txtActor.Multiline = true;
            this.txtActor.Name = "txtActor";
            this.txtActor.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtActor.Size = new System.Drawing.Size(336, 57);
            this.txtActor.TabIndex = 9;
            this.txtActor.Leave += new System.EventHandler(this.txtTranscript_Leave);
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(12, 101);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(78, 13);
            this.label2.TabIndex = 6;
            this.label2.Text = "ORG Transcipt";
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(12, 253);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(37, 13);
            this.label3.TabIndex = 6;
            this.label3.Text = "Actors";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(12, 316);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(87, 13);
            this.label4.TabIndex = 6;
            this.label4.Text = "Normal Transcipt";
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(12, 524);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(72, 13);
            this.label5.TabIndex = 6;
            this.label5.Text = "Html Transript";
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.label6);
            this.groupBox1.Controls.Add(this.txtFilePath);
            this.groupBox1.Controls.Add(this.btnBrowse);
            this.groupBox1.Controls.Add(this.txtLength);
            this.groupBox1.Controls.Add(this.txtPosition);
            this.groupBox1.Controls.Add(this.lblLength);
            this.groupBox1.Controls.Add(this.label7);
            this.groupBox1.Controls.Add(this.label1);
            this.groupBox1.Controls.Add(this.txtNextPosition);
            this.groupBox1.Controls.Add(this.btnReward);
            this.groupBox1.Controls.Add(this.btnPlay);
            this.groupBox1.Controls.Add(this.btnForward);
            this.groupBox1.Location = new System.Drawing.Point(15, 9);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(765, 86);
            this.groupBox1.TabIndex = 15;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "Action";
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(6, 16);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(23, 13);
            this.label6.TabIndex = 6;
            this.label6.Text = "File";
            // 
            // label7
            // 
            this.label7.AutoSize = true;
            this.label7.Location = new System.Drawing.Point(317, 44);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(50, 13);
            this.label7.TabIndex = 6;
            this.label7.Text = "Next Pos";
            // 
            // btnReward
            // 
            this.btnReward.BackColor = System.Drawing.Color.Transparent;
            this.btnReward.Image = global::playMP3.Properties.Resources.fast_rewind_48;
            this.btnReward.Location = new System.Drawing.Point(471, 12);
            this.btnReward.Name = "btnReward";
            this.btnReward.Size = new System.Drawing.Size(59, 68);
            this.btnReward.TabIndex = 4;
            this.btnReward.UseVisualStyleBackColor = false;
            this.btnReward.Click += new System.EventHandler(this.btnReward_Click);
            // 
            // btnPlay
            // 
            this.btnPlay.BackColor = System.Drawing.Color.Transparent;
            this.btnPlay.FlatStyle = System.Windows.Forms.FlatStyle.Flat;
            this.btnPlay.Image = global::playMP3.Properties.Resources.play_6_48;
            this.btnPlay.Location = new System.Drawing.Point(542, 12);
            this.btnPlay.Name = "btnPlay";
            this.btnPlay.Size = new System.Drawing.Size(145, 68);
            this.btnPlay.TabIndex = 2;
            this.btnPlay.UseVisualStyleBackColor = false;
            this.btnPlay.Click += new System.EventHandler(this.btnPlay_Click);
            // 
            // btnForward
            // 
            this.btnForward.BackColor = System.Drawing.Color.Transparent;
            this.btnForward.Image = global::playMP3.Properties.Resources.fast_forward_2_48;
            this.btnForward.Location = new System.Drawing.Point(700, 12);
            this.btnForward.Name = "btnForward";
            this.btnForward.Size = new System.Drawing.Size(59, 67);
            this.btnForward.TabIndex = 4;
            this.btnForward.UseVisualStyleBackColor = false;
            this.btnForward.Click += new System.EventHandler(this.btnForward_Click);
            // 
            // groupBox2
            // 
            this.groupBox2.Controls.Add(this.label17);
            this.groupBox2.Controls.Add(this.label21);
            this.groupBox2.Controls.Add(this.label18);
            this.groupBox2.Controls.Add(this.label16);
            this.groupBox2.Controls.Add(this.txtSecret);
            this.groupBox2.Controls.Add(this.txtApiKey);
            this.groupBox2.Controls.Add(this.txtUrl);
            this.groupBox2.Controls.Add(this.btnConfig);
            this.groupBox2.Controls.Add(this.cbCloudService);
            this.groupBox2.Location = new System.Drawing.Point(786, 9);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Size = new System.Drawing.Size(716, 86);
            this.groupBox2.TabIndex = 16;
            this.groupBox2.TabStop = false;
            this.groupBox2.Text = "Configuration";
            // 
            // label17
            // 
            this.label17.AutoSize = true;
            this.label17.Location = new System.Drawing.Point(6, 24);
            this.label17.Name = "label17";
            this.label17.Size = new System.Drawing.Size(35, 13);
            this.label17.TabIndex = 3;
            this.label17.Text = "Name";
            // 
            // label21
            // 
            this.label21.AutoSize = true;
            this.label21.Location = new System.Drawing.Point(350, 50);
            this.label21.Name = "label21";
            this.label21.Size = new System.Drawing.Size(38, 13);
            this.label21.TabIndex = 3;
            this.label21.Text = "Secret";
            // 
            // label18
            // 
            this.label18.AutoSize = true;
            this.label18.Location = new System.Drawing.Point(6, 51);
            this.label18.Name = "label18";
            this.label18.Size = new System.Drawing.Size(43, 13);
            this.label18.TabIndex = 3;
            this.label18.Text = "Api Key";
            // 
            // label16
            // 
            this.label16.AutoSize = true;
            this.label16.Location = new System.Drawing.Point(174, 24);
            this.label16.Name = "label16";
            this.label16.Size = new System.Drawing.Size(20, 13);
            this.label16.TabIndex = 3;
            this.label16.Text = "Url";
            // 
            // txtSecret
            // 
            this.txtSecret.Location = new System.Drawing.Point(417, 43);
            this.txtSecret.Name = "txtSecret";
            this.txtSecret.Size = new System.Drawing.Size(194, 20);
            this.txtSecret.TabIndex = 2;
            // 
            // txtApiKey
            // 
            this.txtApiKey.Location = new System.Drawing.Point(73, 44);
            this.txtApiKey.Name = "txtApiKey";
            this.txtApiKey.Size = new System.Drawing.Size(256, 20);
            this.txtApiKey.TabIndex = 2;
            // 
            // txtUrl
            // 
            this.txtUrl.Location = new System.Drawing.Point(200, 17);
            this.txtUrl.Name = "txtUrl";
            this.txtUrl.Size = new System.Drawing.Size(411, 20);
            this.txtUrl.TabIndex = 2;
            // 
            // btnConfig
            // 
            this.btnConfig.BackColor = System.Drawing.Color.Transparent;
            this.btnConfig.FlatAppearance.BorderSize = 0;
            this.btnConfig.FlatStyle = System.Windows.Forms.FlatStyle.Flat;
            this.btnConfig.Image = global::playMP3.Properties.Resources.settings_17_48;
            this.btnConfig.Location = new System.Drawing.Point(635, 12);
            this.btnConfig.Name = "btnConfig";
            this.btnConfig.Size = new System.Drawing.Size(75, 66);
            this.btnConfig.TabIndex = 1;
            this.btnConfig.UseVisualStyleBackColor = false;
            this.btnConfig.Click += new System.EventHandler(this.btnConfig_Click);
            // 
            // cbCloudService
            // 
            this.cbCloudService.FormattingEnabled = true;
            this.cbCloudService.Location = new System.Drawing.Point(73, 16);
            this.cbCloudService.Name = "cbCloudService";
            this.cbCloudService.Size = new System.Drawing.Size(95, 21);
            this.cbCloudService.TabIndex = 0;
            this.cbCloudService.SelectedIndexChanged += new System.EventHandler(this.cbCloudService_SelectedIndexChanged);
            // 
            // groupBox3
            // 
            this.groupBox3.Controls.Add(this.btnSubmitAndAddNew);
            this.groupBox3.Controls.Add(this.txtDuration);
            this.groupBox3.Controls.Add(this.btnGetLink);
            this.groupBox3.Controls.Add(this.txtThumb);
            this.groupBox3.Controls.Add(this.btnImageLink);
            this.groupBox3.Controls.Add(this.label20);
            this.groupBox3.Controls.Add(this.txtGrammar);
            this.groupBox3.Controls.Add(this.label15);
            this.groupBox3.Controls.Add(this.btnSubmit);
            this.groupBox3.Controls.Add(this.txtHomeNumber);
            this.groupBox3.Controls.Add(this.label38);
            this.groupBox3.Controls.Add(this.txtNumber);
            this.groupBox3.Controls.Add(this.label19);
            this.groupBox3.Controls.Add(this.txtSummary);
            this.groupBox3.Controls.Add(this.label14);
            this.groupBox3.Controls.Add(this.txtVocab);
            this.groupBox3.Controls.Add(this.label13);
            this.groupBox3.Controls.Add(this.label22);
            this.groupBox3.Controls.Add(this.txtSecondfileUrl);
            this.groupBox3.Controls.Add(this.label12);
            this.groupBox3.Controls.Add(this.dpPublishDate);
            this.groupBox3.Controls.Add(this.label10);
            this.groupBox3.Controls.Add(this.cbYear);
            this.groupBox3.Controls.Add(this.cbType);
            this.groupBox3.Controls.Add(this.cbCategory);
            this.groupBox3.Controls.Add(this.txtFileUrl);
            this.groupBox3.Controls.Add(this.txtEpisodeName);
            this.groupBox3.Controls.Add(this.label8);
            this.groupBox3.Controls.Add(this.txtId);
            this.groupBox3.Controls.Add(this.label9);
            this.groupBox3.Controls.Add(this.label40);
            this.groupBox3.Controls.Add(this.label11);
            this.groupBox3.Location = new System.Drawing.Point(1121, 101);
            this.groupBox3.Name = "groupBox3";
            this.groupBox3.Size = new System.Drawing.Size(381, 691);
            this.groupBox3.TabIndex = 17;
            this.groupBox3.TabStop = false;
            this.groupBox3.Text = "Firebase";
            // 
            // btnSubmitAndAddNew
            // 
            this.btnSubmitAndAddNew.Location = new System.Drawing.Point(93, 533);
            this.btnSubmitAndAddNew.Name = "btnSubmitAndAddNew";
            this.btnSubmitAndAddNew.Size = new System.Drawing.Size(150, 23);
            this.btnSubmitAndAddNew.TabIndex = 37;
            this.btnSubmitAndAddNew.Text = "Submit and Add New";
            this.btnSubmitAndAddNew.UseVisualStyleBackColor = true;
            this.btnSubmitAndAddNew.Click += new System.EventHandler(this.btnSubmitAndAddNew_Click);
            // 
            // txtDuration
            // 
            this.txtDuration.Location = new System.Drawing.Point(93, 216);
            this.txtDuration.Maximum = new decimal(new int[] {
            10000,
            0,
            0,
            0});
            this.txtDuration.Name = "txtDuration";
            this.txtDuration.Size = new System.Drawing.Size(282, 20);
            this.txtDuration.TabIndex = 36;
            // 
            // btnGetLink
            // 
            this.btnGetLink.Location = new System.Drawing.Point(318, 161);
            this.btnGetLink.Name = "btnGetLink";
            this.btnGetLink.Size = new System.Drawing.Size(58, 23);
            this.btnGetLink.TabIndex = 35;
            this.btnGetLink.Text = "Get link";
            this.btnGetLink.UseVisualStyleBackColor = true;
            this.btnGetLink.Click += new System.EventHandler(this.btnGetLink_Click);
            // 
            // txtThumb
            // 
            this.txtThumb.Location = new System.Drawing.Point(93, 135);
            this.txtThumb.Name = "txtThumb";
            this.txtThumb.Size = new System.Drawing.Size(219, 20);
            this.txtThumb.TabIndex = 34;
            // 
            // btnImageLink
            // 
            this.btnImageLink.Location = new System.Drawing.Point(318, 133);
            this.btnImageLink.Name = "btnImageLink";
            this.btnImageLink.Size = new System.Drawing.Size(57, 23);
            this.btnImageLink.TabIndex = 0;
            this.btnImageLink.Text = "Browse";
            this.btnImageLink.UseVisualStyleBackColor = true;
            this.btnImageLink.Click += new System.EventHandler(this.btnImageLink_Click);
            // 
            // label20
            // 
            this.label20.AutoSize = true;
            this.label20.Location = new System.Drawing.Point(13, 138);
            this.label20.Name = "label20";
            this.label20.Size = new System.Drawing.Size(72, 13);
            this.label20.TabIndex = 33;
            this.label20.Text = "Thumb Image";
            // 
            // txtGrammar
            // 
            this.txtGrammar.Location = new System.Drawing.Point(93, 407);
            this.txtGrammar.Multiline = true;
            this.txtGrammar.Name = "txtGrammar";
            this.txtGrammar.Size = new System.Drawing.Size(283, 67);
            this.txtGrammar.TabIndex = 32;
            // 
            // label15
            // 
            this.label15.AutoSize = true;
            this.label15.Location = new System.Drawing.Point(14, 407);
            this.label15.Name = "label15";
            this.label15.Size = new System.Drawing.Size(49, 13);
            this.label15.TabIndex = 31;
            this.label15.Text = "Grammar";
            // 
            // btnSubmit
            // 
            this.btnSubmit.Location = new System.Drawing.Point(249, 533);
            this.btnSubmit.Name = "btnSubmit";
            this.btnSubmit.Size = new System.Drawing.Size(126, 23);
            this.btnSubmit.TabIndex = 30;
            this.btnSubmit.Text = "Submit to Firebase";
            this.btnSubmit.UseVisualStyleBackColor = true;
            this.btnSubmit.Click += new System.EventHandler(this.btnSubmit_Click);
            // 
            // txtHomeNumber
            // 
            this.txtHomeNumber.Location = new System.Drawing.Point(93, 506);
            this.txtHomeNumber.Name = "txtHomeNumber";
            this.txtHomeNumber.Size = new System.Drawing.Size(283, 20);
            this.txtHomeNumber.TabIndex = 29;
            // 
            // label38
            // 
            this.label38.AutoSize = true;
            this.label38.Location = new System.Drawing.Point(13, 506);
            this.label38.Name = "label38";
            this.label38.Size = new System.Drawing.Size(73, 13);
            this.label38.TabIndex = 28;
            this.label38.Text = "Home number";
            // 
            // txtNumber
            // 
            this.txtNumber.Location = new System.Drawing.Point(93, 480);
            this.txtNumber.Name = "txtNumber";
            this.txtNumber.Size = new System.Drawing.Size(283, 20);
            this.txtNumber.TabIndex = 27;
            // 
            // label19
            // 
            this.label19.AutoSize = true;
            this.label19.Location = new System.Drawing.Point(13, 483);
            this.label19.Name = "label19";
            this.label19.Size = new System.Drawing.Size(44, 13);
            this.label19.TabIndex = 26;
            this.label19.Text = "Number";
            // 
            // txtSummary
            // 
            this.txtSummary.Location = new System.Drawing.Point(93, 334);
            this.txtSummary.Multiline = true;
            this.txtSummary.Name = "txtSummary";
            this.txtSummary.Size = new System.Drawing.Size(283, 67);
            this.txtSummary.TabIndex = 25;
            // 
            // label14
            // 
            this.label14.AutoSize = true;
            this.label14.Location = new System.Drawing.Point(13, 334);
            this.label14.Name = "label14";
            this.label14.Size = new System.Drawing.Size(50, 13);
            this.label14.TabIndex = 24;
            this.label14.Text = "Summary";
            // 
            // txtVocab
            // 
            this.txtVocab.Location = new System.Drawing.Point(93, 255);
            this.txtVocab.Multiline = true;
            this.txtVocab.Name = "txtVocab";
            this.txtVocab.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtVocab.Size = new System.Drawing.Size(283, 67);
            this.txtVocab.TabIndex = 23;
            // 
            // label13
            // 
            this.label13.AutoSize = true;
            this.label13.Location = new System.Drawing.Point(13, 258);
            this.label13.Name = "label13";
            this.label13.Size = new System.Drawing.Size(38, 13);
            this.label13.TabIndex = 22;
            this.label13.Text = "Vocab";
            // 
            // label22
            // 
            this.label22.AutoSize = true;
            this.label22.Location = new System.Drawing.Point(13, 215);
            this.label22.Name = "label22";
            this.label22.Size = new System.Drawing.Size(47, 13);
            this.label22.TabIndex = 20;
            this.label22.Text = "Duration";
            // 
            // txtSecondfileUrl
            // 
            this.txtSecondfileUrl.Location = new System.Drawing.Point(93, 189);
            this.txtSecondfileUrl.Name = "txtSecondfileUrl";
            this.txtSecondfileUrl.Size = new System.Drawing.Size(283, 20);
            this.txtSecondfileUrl.TabIndex = 21;
            // 
            // label12
            // 
            this.label12.AutoSize = true;
            this.label12.Location = new System.Drawing.Point(13, 189);
            this.label12.Name = "label12";
            this.label12.Size = new System.Drawing.Size(74, 13);
            this.label12.TabIndex = 20;
            this.label12.Text = "Second file url";
            // 
            // dpPublishDate
            // 
            this.dpPublishDate.Location = new System.Drawing.Point(92, 81);
            this.dpPublishDate.Name = "dpPublishDate";
            this.dpPublishDate.Size = new System.Drawing.Size(283, 20);
            this.dpPublishDate.TabIndex = 19;
            // 
            // label10
            // 
            this.label10.AutoSize = true;
            this.label10.Location = new System.Drawing.Point(12, 85);
            this.label10.Name = "label10";
            this.label10.Size = new System.Drawing.Size(65, 13);
            this.label10.TabIndex = 18;
            this.label10.Text = "Publish date";
            // 
            // cbYear
            // 
            this.cbYear.FormattingEnabled = true;
            this.cbYear.Location = new System.Drawing.Point(282, 54);
            this.cbYear.Name = "cbYear";
            this.cbYear.Size = new System.Drawing.Size(93, 21);
            this.cbYear.TabIndex = 17;
            // 
            // cbType
            // 
            this.cbType.FormattingEnabled = true;
            this.cbType.Items.AddRange(new object[] {
            "BBC",
            "VOA"});
            this.cbType.Location = new System.Drawing.Point(92, 54);
            this.cbType.Name = "cbType";
            this.cbType.Size = new System.Drawing.Size(89, 21);
            this.cbType.TabIndex = 13;
            this.cbType.SelectedIndexChanged += new System.EventHandler(this.cbType_SelectedIndexChanged);
            // 
            // cbCategory
            // 
            this.cbCategory.FormattingEnabled = true;
            this.cbCategory.Location = new System.Drawing.Point(187, 54);
            this.cbCategory.Name = "cbCategory";
            this.cbCategory.Size = new System.Drawing.Size(89, 21);
            this.cbCategory.TabIndex = 14;
            // 
            // txtFileUrl
            // 
            this.txtFileUrl.Location = new System.Drawing.Point(93, 163);
            this.txtFileUrl.Name = "txtFileUrl";
            this.txtFileUrl.Size = new System.Drawing.Size(219, 20);
            this.txtFileUrl.TabIndex = 16;
            // 
            // txtEpisodeName
            // 
            this.txtEpisodeName.Location = new System.Drawing.Point(92, 107);
            this.txtEpisodeName.Name = "txtEpisodeName";
            this.txtEpisodeName.Size = new System.Drawing.Size(283, 20);
            this.txtEpisodeName.TabIndex = 15;
            // 
            // label8
            // 
            this.label8.AutoSize = true;
            this.label8.Location = new System.Drawing.Point(13, 166);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(37, 13);
            this.label8.TabIndex = 7;
            this.label8.Text = "File url";
            // 
            // txtId
            // 
            this.txtId.Location = new System.Drawing.Point(92, 28);
            this.txtId.Name = "txtId";
            this.txtId.Size = new System.Drawing.Size(283, 20);
            this.txtId.TabIndex = 12;
            // 
            // label9
            // 
            this.label9.AutoSize = true;
            this.label9.Location = new System.Drawing.Point(12, 110);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(74, 13);
            this.label9.TabIndex = 8;
            this.label9.Text = "Episode name";
            // 
            // label40
            // 
            this.label40.AutoSize = true;
            this.label40.Location = new System.Drawing.Point(12, 57);
            this.label40.Name = "label40";
            this.label40.Size = new System.Drawing.Size(31, 13);
            this.label40.TabIndex = 10;
            this.label40.Text = "Type";
            // 
            // label11
            // 
            this.label11.AutoSize = true;
            this.label11.Location = new System.Drawing.Point(12, 31);
            this.label11.Name = "label11";
            this.label11.Size = new System.Drawing.Size(16, 13);
            this.label11.TabIndex = 11;
            this.label11.Text = "Id";
            // 
            // tabControl1
            // 
            this.tabControl1.Controls.Add(this.tabPage1);
            this.tabControl1.Controls.Add(this.tabPage2);
            this.tabControl1.Location = new System.Drawing.Point(502, 101);
            this.tabControl1.Name = "tabControl1";
            this.tabControl1.SelectedIndex = 0;
            this.tabControl1.Size = new System.Drawing.Size(613, 691);
            this.tabControl1.TabIndex = 18;
            // 
            // tabPage1
            // 
            this.tabPage1.Controls.Add(this.grvRow);
            this.tabPage1.Location = new System.Drawing.Point(4, 22);
            this.tabPage1.Name = "tabPage1";
            this.tabPage1.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage1.Size = new System.Drawing.Size(605, 665);
            this.tabPage1.TabIndex = 0;
            this.tabPage1.Text = "En";
            this.tabPage1.UseVisualStyleBackColor = true;
            // 
            // tabPage2
            // 
            this.tabPage2.Location = new System.Drawing.Point(4, 22);
            this.tabPage2.Name = "tabPage2";
            this.tabPage2.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage2.Size = new System.Drawing.Size(605, 665);
            this.tabPage2.TabIndex = 1;
            this.tabPage2.Text = "Viet Nam";
            this.tabPage2.UseVisualStyleBackColor = true;
            // 
            // frmMain
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1514, 804);
            this.Controls.Add(this.tabControl1);
            this.Controls.Add(this.groupBox3);
            this.Controls.Add(this.groupBox2);
            this.Controls.Add(this.groupBox1);
            this.Controls.Add(this.btnConvertGridToResult);
            this.Controls.Add(this.btnConvertToGrid);
            this.Controls.Add(this.txtGroupResult);
            this.Controls.Add(this.txtResult);
            this.Controls.Add(this.txtActor);
            this.Controls.Add(this.txtTranscript);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.label2);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.MinimizeBox = false;
            this.Name = "frmMain";
            this.Text = "Play MP3";
            this.TopMost = true;
            ((System.ComponentModel.ISupportInitialize)(this.grvRow)).EndInit();
            this.groupBox1.ResumeLayout(false);
            this.groupBox1.PerformLayout();
            this.groupBox2.ResumeLayout(false);
            this.groupBox2.PerformLayout();
            this.groupBox3.ResumeLayout(false);
            this.groupBox3.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.txtDuration)).EndInit();
            this.tabControl1.ResumeLayout(false);
            this.tabPage1.ResumeLayout(false);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Button btnBrowse;
        private System.Windows.Forms.TextBox txtFilePath;
        private System.Windows.Forms.Button btnPlay;
        private System.Windows.Forms.Button btnForward;
        private System.Windows.Forms.Button btnReward;
        private System.Windows.Forms.TextBox txtLength;
        private System.Windows.Forms.Label lblLength;
        private System.Windows.Forms.TextBox txtPosition;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.OpenFileDialog openFileDialog1;
        private System.Windows.Forms.TextBox txtNextPosition;
        private System.Windows.Forms.TextBox txtTranscript;
        private System.Windows.Forms.DataGridView grvRow;
        private System.Windows.Forms.TextBox txtResult;
        private System.Windows.Forms.Button btnConvertToGrid;
        private System.Windows.Forms.Button btnConvertGridToResult;
        private System.Windows.Forms.TextBox txtGroupResult;
        private System.Windows.Forms.TextBox txtActor;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.DataGridViewTextBoxColumn FirstDuration;
        private System.Windows.Forms.DataGridViewTextBoxColumn RowContent;
        private System.Windows.Forms.DataGridViewTextBoxColumn LastDuration;
        private System.Windows.Forms.DataGridViewTextBoxColumn Group;
        private System.Windows.Forms.GroupBox groupBox2;
        private System.Windows.Forms.ComboBox cbCloudService;
        private System.Windows.Forms.Button btnConfig;
        private System.Windows.Forms.GroupBox groupBox3;
        private System.Windows.Forms.TextBox txtHomeNumber;
        private System.Windows.Forms.Label label38;
        private System.Windows.Forms.TextBox txtNumber;
        private System.Windows.Forms.Label label19;
        private System.Windows.Forms.TextBox txtSummary;
        private System.Windows.Forms.Label label14;
        private System.Windows.Forms.TextBox txtVocab;
        private System.Windows.Forms.Label label13;
        private System.Windows.Forms.TextBox txtSecondfileUrl;
        private System.Windows.Forms.Label label12;
        private System.Windows.Forms.DateTimePicker dpPublishDate;
        private System.Windows.Forms.Label label10;
        private System.Windows.Forms.ComboBox cbYear;
        private System.Windows.Forms.ComboBox cbType;
        private System.Windows.Forms.ComboBox cbCategory;
        private System.Windows.Forms.TextBox txtFileUrl;
        private System.Windows.Forms.TextBox txtEpisodeName;
        private System.Windows.Forms.Label label8;
        private System.Windows.Forms.TextBox txtId;
        private System.Windows.Forms.Label label9;
        private System.Windows.Forms.Label label40;
        private System.Windows.Forms.Label label11;
        private System.Windows.Forms.Button btnSubmit;
        private System.Windows.Forms.TextBox txtGrammar;
        private System.Windows.Forms.Label label15;
        private System.Windows.Forms.TextBox txtThumb;
        private System.Windows.Forms.Label label20;
        private System.Windows.Forms.Label label16;
        private System.Windows.Forms.TextBox txtUrl;
        private System.Windows.Forms.Label label17;
        private System.Windows.Forms.Label label21;
        private System.Windows.Forms.Label label18;
        private System.Windows.Forms.TextBox txtSecret;
        private System.Windows.Forms.TextBox txtApiKey;
        private System.Windows.Forms.Button btnGetLink;
        private System.Windows.Forms.Button btnImageLink;
        private System.Windows.Forms.NumericUpDown txtDuration;
        private System.Windows.Forms.Label label22;
        private System.Windows.Forms.Button btnSubmitAndAddNew;
        private System.Windows.Forms.TabControl tabControl1;
        private System.Windows.Forms.TabPage tabPage1;
        private System.Windows.Forms.TabPage tabPage2;
    }
}

