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
            this.GrammarExplainationEn = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.txtResult = new System.Windows.Forms.TextBox();
            this.btnConvertGridToResult = new System.Windows.Forms.Button();
            this.txtGroupResult = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
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
            this.cbLevel = new System.Windows.Forms.ComboBox();
            this.label3 = new System.Windows.Forms.Label();
            this.cbExportTranslation = new System.Windows.Forms.CheckBox();
            this.cbExportGrammar = new System.Windows.Forms.CheckBox();
            this.cbExportVocabulary = new System.Windows.Forms.CheckBox();
            this.cbExportQuestions = new System.Windows.Forms.CheckBox();
            this.cbExportEpisodeDetail = new System.Windows.Forms.CheckBox();
            this.cbSendEpisodePush = new System.Windows.Forms.CheckBox();
            this.txtASSeriesChild = new System.Windows.Forms.TextBox();
            this.lblASSeriesChild = new System.Windows.Forms.Label();
            this.btnGetQuestions = new System.Windows.Forms.Button();
            this.label12 = new System.Windows.Forms.Label();
            this.grvQuestions = new System.Windows.Forms.DataGridView();
            this.btnGetVocabTransLateAndObject = new System.Windows.Forms.Button();
            this.tabControl2 = new System.Windows.Forms.TabControl();
            this.tabPage10 = new System.Windows.Forms.TabPage();
            this.grvVocabEn = new System.Windows.Forms.DataGridView();
            this.colVocabEnText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.dataGridViewTextBoxColumn34 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabEnObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage11 = new System.Windows.Forms.TabPage();
            this.grvVocabVi = new System.Windows.Forms.DataGridView();
            this.colVocabViText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabViMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabViObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage12 = new System.Windows.Forms.TabPage();
            this.grvVocabEs = new System.Windows.Forms.DataGridView();
            this.colVocabEsText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabEsMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabEsObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage13 = new System.Windows.Forms.TabPage();
            this.grvVocabAr = new System.Windows.Forms.DataGridView();
            this.colVocabArText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabArMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabArObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage14 = new System.Windows.Forms.TabPage();
            this.grvVocabJa = new System.Windows.Forms.DataGridView();
            this.colVocabJaText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabJaMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabJaObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage15 = new System.Windows.Forms.TabPage();
            this.grvVocabKo = new System.Windows.Forms.DataGridView();
            this.colVocabKoText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabKoMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabKoObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage16 = new System.Windows.Forms.TabPage();
            this.grvVocabPt = new System.Windows.Forms.DataGridView();
            this.colVocabPtText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabPtMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabPtObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage17 = new System.Windows.Forms.TabPage();
            this.grvVocabRu = new System.Windows.Forms.DataGridView();
            this.colVocabRuText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabRuMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabRuObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage18 = new System.Windows.Forms.TabPage();
            this.grvVocabZh = new System.Windows.Forms.DataGridView();
            this.colVocabZhText = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabZhMeaning = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.colVocabZhObject = new System.Windows.Forms.DataGridViewTextBoxColumn();
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
            this.txtViTranscript = new System.Windows.Forms.TextBox();
            this.label23 = new System.Windows.Forms.Label();
            this.grvViRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn2 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationVi = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage3 = new System.Windows.Forms.TabPage();
            this.txtEsTranscript = new System.Windows.Forms.TextBox();
            this.label24 = new System.Windows.Forms.Label();
            this.grvEsRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn6 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationEs = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage4 = new System.Windows.Forms.TabPage();
            this.txtArTranscript = new System.Windows.Forms.TextBox();
            this.label25 = new System.Windows.Forms.Label();
            this.grvArRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn10 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationAr = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage5 = new System.Windows.Forms.TabPage();
            this.txtJaTranscript = new System.Windows.Forms.TextBox();
            this.label26 = new System.Windows.Forms.Label();
            this.grvJaRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn14 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationJa = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage6 = new System.Windows.Forms.TabPage();
            this.txtKoTranscript = new System.Windows.Forms.TextBox();
            this.label27 = new System.Windows.Forms.Label();
            this.grvKoRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn18 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationKo = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage7 = new System.Windows.Forms.TabPage();
            this.txtPtTranscript = new System.Windows.Forms.TextBox();
            this.label28 = new System.Windows.Forms.Label();
            this.grvPtRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn22 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationPt = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage8 = new System.Windows.Forms.TabPage();
            this.txtRuTranscript = new System.Windows.Forms.TextBox();
            this.label29 = new System.Windows.Forms.Label();
            this.grvRuRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn26 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationRu = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPage9 = new System.Windows.Forms.TabPage();
            this.txtZhTranscript = new System.Windows.Forms.TextBox();
            this.label30 = new System.Windows.Forms.Label();
            this.grvZhRow = new System.Windows.Forms.DataGridView();
            this.dataGridViewTextBoxColumn30 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.GrammarExplainationZh = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.btngetGrammarExplaimation = new System.Windows.Forms.Button();
            this.statusStripGrammar = new System.Windows.Forms.StatusStrip();
            this.toolStripProgressGrammar = new System.Windows.Forms.ToolStripProgressBar();
            this.toolStripStatusLabelGrammar = new System.Windows.Forms.ToolStripStatusLabel();
            this.groupBox4 = new System.Windows.Forms.GroupBox();
            ((System.ComponentModel.ISupportInitialize)(this.grvRow)).BeginInit();
            this.groupBox1.SuspendLayout();
            this.groupBox2.SuspendLayout();
            this.groupBox3.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvQuestions)).BeginInit();
            this.tabControl2.SuspendLayout();
            this.tabPage10.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabEn)).BeginInit();
            this.tabPage11.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabVi)).BeginInit();
            this.tabPage12.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabEs)).BeginInit();
            this.tabPage13.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabAr)).BeginInit();
            this.tabPage14.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabJa)).BeginInit();
            this.tabPage15.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabKo)).BeginInit();
            this.tabPage16.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabPt)).BeginInit();
            this.tabPage17.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabRu)).BeginInit();
            this.tabPage18.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabZh)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.txtDuration)).BeginInit();
            this.tabControl1.SuspendLayout();
            this.tabPage1.SuspendLayout();
            this.tabPage2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvViRow)).BeginInit();
            this.tabPage3.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvEsRow)).BeginInit();
            this.tabPage4.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvArRow)).BeginInit();
            this.tabPage5.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvJaRow)).BeginInit();
            this.tabPage6.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvKoRow)).BeginInit();
            this.tabPage7.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvPtRow)).BeginInit();
            this.tabPage8.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvRuRow)).BeginInit();
            this.tabPage9.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvZhRow)).BeginInit();
            this.statusStripGrammar.SuspendLayout();
            this.groupBox4.SuspendLayout();
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
            this.txtTranscript.Location = new System.Drawing.Point(8, 19);
            this.txtTranscript.Multiline = true;
            this.txtTranscript.Name = "txtTranscript";
            this.txtTranscript.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtTranscript.Size = new System.Drawing.Size(1046, 178);
            this.txtTranscript.TabIndex = 1;
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
            this.GrammarExplainationEn});
            this.grvRow.Location = new System.Drawing.Point(8, 220);
            this.grvRow.Name = "grvRow";
            this.grvRow.Size = new System.Drawing.Size(1046, 663);
            this.grvRow.TabIndex = 2;
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
            // GrammarExplainationEn
            // 
            this.GrammarExplainationEn.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationEn.HeaderText = "Grammar Explaination";
            this.GrammarExplainationEn.Name = "GrammarExplainationEn";
            this.GrammarExplainationEn.Width = 300;
            // 
            // txtResult
            // 
            this.txtResult.Location = new System.Drawing.Point(15, 172);
            this.txtResult.Multiline = true;
            this.txtResult.Name = "txtResult";
            this.txtResult.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtResult.Size = new System.Drawing.Size(450, 346);
            this.txtResult.TabIndex = 13;
            // 
            // btnConvertGridToResult
            // 
            this.btnConvertGridToResult.Location = new System.Drawing.Point(473, 514);
            this.btnConvertGridToResult.Name = "btnConvertGridToResult";
            this.btnConvertGridToResult.Size = new System.Drawing.Size(27, 23);
            this.btnConvertGridToResult.TabIndex = 12;
            this.btnConvertGridToResult.Text = "<<";
            this.btnConvertGridToResult.UseVisualStyleBackColor = true;
            this.btnConvertGridToResult.Click += new System.EventHandler(this.btnConvertGridToResult_Click);
            // 
            // txtGroupResult
            // 
            this.txtGroupResult.Location = new System.Drawing.Point(15, 540);
            this.txtGroupResult.Multiline = true;
            this.txtGroupResult.Name = "txtGroupResult";
            this.txtGroupResult.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtGroupResult.Size = new System.Drawing.Size(450, 397);
            this.txtGroupResult.TabIndex = 14;
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(3, 3);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(78, 13);
            this.label2.TabIndex = 6;
            this.label2.Text = "ORG Transcipt";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(12, 155);
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
            this.groupBox1.Location = new System.Drawing.Point(15, 9);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(485, 86);
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
            this.btnReward.Location = new System.Drawing.Point(36, 19);
            this.btnReward.Name = "btnReward";
            this.btnReward.Size = new System.Drawing.Size(59, 68);
            this.btnReward.TabIndex = 24;
            this.btnReward.UseVisualStyleBackColor = false;
            this.btnReward.Click += new System.EventHandler(this.btnReward_Click);
            // 
            // btnPlay
            // 
            this.btnPlay.BackColor = System.Drawing.Color.Transparent;
            this.btnPlay.FlatStyle = System.Windows.Forms.FlatStyle.Flat;
            this.btnPlay.Image = global::playMP3.Properties.Resources.play_6_48;
            this.btnPlay.Location = new System.Drawing.Point(107, 19);
            this.btnPlay.Name = "btnPlay";
            this.btnPlay.Size = new System.Drawing.Size(145, 68);
            this.btnPlay.TabIndex = 25;
            this.btnPlay.UseVisualStyleBackColor = false;
            this.btnPlay.Click += new System.EventHandler(this.btnPlay_Click);
            // 
            // btnForward
            // 
            this.btnForward.BackColor = System.Drawing.Color.Transparent;
            this.btnForward.Image = global::playMP3.Properties.Resources.fast_forward_2_48;
            this.btnForward.Location = new System.Drawing.Point(265, 19);
            this.btnForward.Name = "btnForward";
            this.btnForward.Size = new System.Drawing.Size(59, 67);
            this.btnForward.TabIndex = 26;
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
            this.groupBox2.Location = new System.Drawing.Point(1573, 12);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Size = new System.Drawing.Size(629, 86);
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
            this.groupBox3.Controls.Add(this.cbLevel);
            this.groupBox3.Controls.Add(this.label3);
            this.groupBox3.Controls.Add(this.cbSendEpisodePush);
            this.groupBox3.Controls.Add(this.cbExportTranslation);
            this.groupBox3.Controls.Add(this.cbExportGrammar);
            this.groupBox3.Controls.Add(this.cbExportVocabulary);
            this.groupBox3.Controls.Add(this.cbExportQuestions);
            this.groupBox3.Controls.Add(this.cbExportEpisodeDetail);
            this.groupBox3.Controls.Add(this.txtASSeriesChild);
            this.groupBox3.Controls.Add(this.lblASSeriesChild);
            this.groupBox3.Controls.Add(this.btnGetQuestions);
            this.groupBox3.Controls.Add(this.label12);
            this.groupBox3.Controls.Add(this.grvQuestions);
            this.groupBox3.Controls.Add(this.btnGetVocabTransLateAndObject);
            this.groupBox3.Controls.Add(this.tabControl2);
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
            this.groupBox3.Location = new System.Drawing.Point(1573, 101);
            this.groupBox3.Name = "groupBox3";
            this.groupBox3.Size = new System.Drawing.Size(629, 993);
            this.groupBox3.TabIndex = 17;
            this.groupBox3.TabStop = false;
            this.groupBox3.Text = "Firebase";
            // 
            // cbLevel
            // 
            this.cbLevel.FormattingEnabled = true;
            this.cbLevel.Items.AddRange(new object[] {
            "--Select--",
            "A1",
            "A2",
            "B1",
            "B2",
            "C1",
            "C2"});
            this.cbLevel.Location = new System.Drawing.Point(406, 163);
            this.cbLevel.Name = "cbLevel";
            this.cbLevel.Size = new System.Drawing.Size(217, 21);
            this.cbLevel.TabIndex = 48;
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(351, 166);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(33, 13);
            this.label3.TabIndex = 47;
            this.label3.Text = "Level";
            // 
            // cbExportTranslation
            // 
            this.cbExportTranslation.AutoSize = true;
            this.cbExportTranslation.Location = new System.Drawing.Point(132, 888);
            this.cbExportTranslation.Name = "cbExportTranslation";
            this.cbExportTranslation.Size = new System.Drawing.Size(111, 17);
            this.cbExportTranslation.TabIndex = 46;
            this.cbExportTranslation.Text = "Export Translation";
            this.cbExportTranslation.UseVisualStyleBackColor = true;
            // 
            // cbExportGrammar
            // 
            this.cbExportGrammar.AutoSize = true;
            this.cbExportGrammar.Location = new System.Drawing.Point(270, 888);
            this.cbExportGrammar.Name = "cbExportGrammar";
            this.cbExportGrammar.Size = new System.Drawing.Size(101, 17);
            this.cbExportGrammar.TabIndex = 45;
            this.cbExportGrammar.Text = "Export Grammar";
            this.cbExportGrammar.UseVisualStyleBackColor = true;
            // 
            // cbExportVocabulary
            // 
            this.cbExportVocabulary.AutoSize = true;
            this.cbExportVocabulary.Location = new System.Drawing.Point(511, 888);
            this.cbExportVocabulary.Name = "cbExportVocabulary";
            this.cbExportVocabulary.Size = new System.Drawing.Size(112, 17);
            this.cbExportVocabulary.TabIndex = 44;
            this.cbExportVocabulary.Text = "Export Vocabulary";
            this.cbExportVocabulary.UseVisualStyleBackColor = true;
            // 
            // cbExportQuestions
            // 
            this.cbExportQuestions.AutoSize = true;
            this.cbExportQuestions.Location = new System.Drawing.Point(399, 888);
            this.cbExportQuestions.Name = "cbExportQuestions";
            this.cbExportQuestions.Size = new System.Drawing.Size(106, 17);
            this.cbExportQuestions.TabIndex = 43;
            this.cbExportQuestions.Text = "Export Questions";
            this.cbExportQuestions.UseVisualStyleBackColor = true;
            // 
            // cbExportEpisodeDetail
            // 
            this.cbExportEpisodeDetail.AutoSize = true;
            this.cbExportEpisodeDetail.Location = new System.Drawing.Point(17, 888);
            this.cbExportEpisodeDetail.Name = "cbExportEpisodeDetail";
            this.cbExportEpisodeDetail.Size = new System.Drawing.Size(86, 17);
            this.cbExportEpisodeDetail.TabIndex = 42;
            this.cbExportEpisodeDetail.Text = "Export Detail";
            this.cbExportEpisodeDetail.UseVisualStyleBackColor = true;
            // 
            // cbSendEpisodePush
            // 
            this.cbSendEpisodePush.AutoSize = true;
            this.cbSendEpisodePush.Checked = true;
            this.cbSendEpisodePush.CheckState = System.Windows.Forms.CheckState.Checked;
            this.cbSendEpisodePush.Location = new System.Drawing.Point(17, 911);
            this.cbSendEpisodePush.Name = "cbSendEpisodePush";
            this.cbSendEpisodePush.Size = new System.Drawing.Size(95, 17);
            this.cbSendEpisodePush.TabIndex = 44;
            this.cbSendEpisodePush.Text = "Gửi push FCM";
            this.cbSendEpisodePush.UseVisualStyleBackColor = true;
            // 
            // txtASSeriesChild
            // 
            this.txtASSeriesChild.Location = new System.Drawing.Point(404, 55);
            this.txtASSeriesChild.Name = "txtASSeriesChild";
            this.txtASSeriesChild.Size = new System.Drawing.Size(217, 20);
            this.txtASSeriesChild.TabIndex = 41;
            // 
            // lblASSeriesChild
            // 
            this.lblASSeriesChild.AutoSize = true;
            this.lblASSeriesChild.Location = new System.Drawing.Point(322, 58);
            this.lblASSeriesChild.Name = "lblASSeriesChild";
            this.lblASSeriesChild.Size = new System.Drawing.Size(76, 13);
            this.lblASSeriesChild.TabIndex = 40;
            this.lblASSeriesChild.Text = "Another Series";
            // 
            // btnGetQuestions
            // 
            this.btnGetQuestions.Location = new System.Drawing.Point(476, 381);
            this.btnGetQuestions.Name = "btnGetQuestions";
            this.btnGetQuestions.Size = new System.Drawing.Size(145, 31);
            this.btnGetQuestions.TabIndex = 14;
            this.btnGetQuestions.Text = "Get Questions";
            this.btnGetQuestions.UseVisualStyleBackColor = true;
            this.btnGetQuestions.Click += new System.EventHandler(this.btnGetQuestions_Click);
            // 
            // label12
            // 
            this.label12.AutoSize = true;
            this.label12.Location = new System.Drawing.Point(14, 264);
            this.label12.Name = "label12";
            this.label12.Size = new System.Drawing.Size(54, 13);
            this.label12.TabIndex = 39;
            this.label12.Text = "Questions";
            // 
            // grvQuestions
            // 
            this.grvQuestions.AllowUserToAddRows = false;
            this.grvQuestions.AllowUserToDeleteRows = false;
            this.grvQuestions.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvQuestions.Location = new System.Drawing.Point(92, 264);
            this.grvQuestions.Name = "grvQuestions";
            this.grvQuestions.Size = new System.Drawing.Size(529, 111);
            this.grvQuestions.TabIndex = 19;
            // 
            // btnGetVocabTransLateAndObject
            // 
            this.btnGetVocabTransLateAndObject.Location = new System.Drawing.Point(462, 788);
            this.btnGetVocabTransLateAndObject.Name = "btnGetVocabTransLateAndObject";
            this.btnGetVocabTransLateAndObject.Size = new System.Drawing.Size(161, 39);
            this.btnGetVocabTransLateAndObject.TabIndex = 16;
            this.btnGetVocabTransLateAndObject.Text = "Get Vocab Translate && Object";
            this.btnGetVocabTransLateAndObject.UseVisualStyleBackColor = true;
            this.btnGetVocabTransLateAndObject.Click += new System.EventHandler(this.btnGetVocabTransLateAndObject_Click);
            // 
            // tabControl2
            // 
            this.tabControl2.Controls.Add(this.tabPage10);
            this.tabControl2.Controls.Add(this.tabPage11);
            this.tabControl2.Controls.Add(this.tabPage12);
            this.tabControl2.Controls.Add(this.tabPage13);
            this.tabControl2.Controls.Add(this.tabPage14);
            this.tabControl2.Controls.Add(this.tabPage15);
            this.tabControl2.Controls.Add(this.tabPage16);
            this.tabControl2.Controls.Add(this.tabPage17);
            this.tabControl2.Controls.Add(this.tabPage18);
            this.tabControl2.Location = new System.Drawing.Point(6, 539);
            this.tabControl2.Name = "tabControl2";
            this.tabControl2.SelectedIndex = 0;
            this.tabControl2.Size = new System.Drawing.Size(616, 243);
            this.tabControl2.TabIndex = 38;
            // 
            // tabPage10
            // 
            this.tabPage10.Controls.Add(this.grvVocabEn);
            this.tabPage10.Location = new System.Drawing.Point(4, 22);
            this.tabPage10.Name = "tabPage10";
            this.tabPage10.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage10.Size = new System.Drawing.Size(608, 217);
            this.tabPage10.TabIndex = 0;
            this.tabPage10.Text = "En";
            this.tabPage10.UseVisualStyleBackColor = true;
            // 
            // grvVocabEn
            // 
            this.grvVocabEn.AllowUserToAddRows = false;
            this.grvVocabEn.AllowUserToDeleteRows = false;
            this.grvVocabEn.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabEn.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabEnText,
            this.dataGridViewTextBoxColumn34,
            this.colVocabEnObject});
            this.grvVocabEn.Location = new System.Drawing.Point(7, 6);
            this.grvVocabEn.Name = "grvVocabEn";
            this.grvVocabEn.Size = new System.Drawing.Size(595, 205);
            this.grvVocabEn.TabIndex = 16;
            // 
            // colVocabEnText
            // 
            this.colVocabEnText.DataPropertyName = "DisplayText";
            this.colVocabEnText.HeaderText = "Text";
            this.colVocabEnText.MinimumWidth = 100;
            this.colVocabEnText.Name = "colVocabEnText";
            // 
            // dataGridViewTextBoxColumn34
            // 
            this.dataGridViewTextBoxColumn34.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn34.DataPropertyName = "Meaning";
            this.dataGridViewTextBoxColumn34.HeaderText = "Meaning";
            this.dataGridViewTextBoxColumn34.MinimumWidth = 100;
            this.dataGridViewTextBoxColumn34.Name = "dataGridViewTextBoxColumn34";
            // 
            // colVocabEnObject
            // 
            this.colVocabEnObject.DataPropertyName = "EnhancementJson";
            this.colVocabEnObject.HeaderText = "Vocab Object";
            this.colVocabEnObject.Name = "colVocabEnObject";
            // 
            // tabPage11
            // 
            this.tabPage11.Controls.Add(this.grvVocabVi);
            this.tabPage11.Location = new System.Drawing.Point(4, 22);
            this.tabPage11.Name = "tabPage11";
            this.tabPage11.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage11.Size = new System.Drawing.Size(608, 217);
            this.tabPage11.TabIndex = 1;
            this.tabPage11.Text = "Vi";
            this.tabPage11.UseVisualStyleBackColor = true;
            // 
            // grvVocabVi
            // 
            this.grvVocabVi.AllowUserToAddRows = false;
            this.grvVocabVi.AllowUserToDeleteRows = false;
            this.grvVocabVi.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabVi.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabViText,
            this.colVocabViMeaning,
            this.colVocabViObject});
            this.grvVocabVi.Location = new System.Drawing.Point(7, 6);
            this.grvVocabVi.Name = "grvVocabVi";
            this.grvVocabVi.Size = new System.Drawing.Size(595, 205);
            this.grvVocabVi.TabIndex = 19;
            // 
            // colVocabViText
            // 
            this.colVocabViText.DataPropertyName = "DisplayText";
            this.colVocabViText.HeaderText = "Text";
            this.colVocabViText.MinimumWidth = 100;
            this.colVocabViText.Name = "colVocabViText";
            // 
            // colVocabViMeaning
            // 
            this.colVocabViMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabViMeaning.DataPropertyName = "Meaning";
            this.colVocabViMeaning.HeaderText = "Meaning";
            this.colVocabViMeaning.MinimumWidth = 100;
            this.colVocabViMeaning.Name = "colVocabViMeaning";
            // 
            // colVocabViObject
            // 
            this.colVocabViObject.DataPropertyName = "EnhancementJson";
            this.colVocabViObject.HeaderText = "Vocab Object";
            this.colVocabViObject.Name = "colVocabViObject";
            // 
            // tabPage12
            // 
            this.tabPage12.Controls.Add(this.grvVocabEs);
            this.tabPage12.Location = new System.Drawing.Point(4, 22);
            this.tabPage12.Name = "tabPage12";
            this.tabPage12.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage12.Size = new System.Drawing.Size(608, 217);
            this.tabPage12.TabIndex = 2;
            this.tabPage12.Text = "Es";
            this.tabPage12.UseVisualStyleBackColor = true;
            // 
            // grvVocabEs
            // 
            this.grvVocabEs.AllowUserToAddRows = false;
            this.grvVocabEs.AllowUserToDeleteRows = false;
            this.grvVocabEs.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabEs.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabEsText,
            this.colVocabEsMeaning,
            this.colVocabEsObject});
            this.grvVocabEs.Location = new System.Drawing.Point(7, 6);
            this.grvVocabEs.Name = "grvVocabEs";
            this.grvVocabEs.Size = new System.Drawing.Size(595, 205);
            this.grvVocabEs.TabIndex = 20;
            // 
            // colVocabEsText
            // 
            this.colVocabEsText.DataPropertyName = "DisplayText";
            this.colVocabEsText.HeaderText = "Text";
            this.colVocabEsText.MinimumWidth = 100;
            this.colVocabEsText.Name = "colVocabEsText";
            // 
            // colVocabEsMeaning
            // 
            this.colVocabEsMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabEsMeaning.DataPropertyName = "Meaning";
            this.colVocabEsMeaning.HeaderText = "Meaning";
            this.colVocabEsMeaning.MinimumWidth = 100;
            this.colVocabEsMeaning.Name = "colVocabEsMeaning";
            // 
            // colVocabEsObject
            // 
            this.colVocabEsObject.DataPropertyName = "EnhancementJson";
            this.colVocabEsObject.HeaderText = "Vocab Object";
            this.colVocabEsObject.Name = "colVocabEsObject";
            // 
            // tabPage13
            // 
            this.tabPage13.Controls.Add(this.grvVocabAr);
            this.tabPage13.Location = new System.Drawing.Point(4, 22);
            this.tabPage13.Name = "tabPage13";
            this.tabPage13.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage13.Size = new System.Drawing.Size(608, 217);
            this.tabPage13.TabIndex = 3;
            this.tabPage13.Text = "Ar";
            this.tabPage13.UseVisualStyleBackColor = true;
            // 
            // grvVocabAr
            // 
            this.grvVocabAr.AllowUserToAddRows = false;
            this.grvVocabAr.AllowUserToDeleteRows = false;
            this.grvVocabAr.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabAr.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabArText,
            this.colVocabArMeaning,
            this.colVocabArObject});
            this.grvVocabAr.Location = new System.Drawing.Point(7, 6);
            this.grvVocabAr.Name = "grvVocabAr";
            this.grvVocabAr.Size = new System.Drawing.Size(595, 205);
            this.grvVocabAr.TabIndex = 20;
            // 
            // colVocabArText
            // 
            this.colVocabArText.DataPropertyName = "DisplayText";
            this.colVocabArText.HeaderText = "Text";
            this.colVocabArText.MinimumWidth = 100;
            this.colVocabArText.Name = "colVocabArText";
            // 
            // colVocabArMeaning
            // 
            this.colVocabArMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabArMeaning.DataPropertyName = "Meaning";
            this.colVocabArMeaning.HeaderText = "Meaning";
            this.colVocabArMeaning.MinimumWidth = 100;
            this.colVocabArMeaning.Name = "colVocabArMeaning";
            // 
            // colVocabArObject
            // 
            this.colVocabArObject.DataPropertyName = "EnhancementJson";
            this.colVocabArObject.HeaderText = "Vocab Object";
            this.colVocabArObject.Name = "colVocabArObject";
            // 
            // tabPage14
            // 
            this.tabPage14.Controls.Add(this.grvVocabJa);
            this.tabPage14.Location = new System.Drawing.Point(4, 22);
            this.tabPage14.Name = "tabPage14";
            this.tabPage14.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage14.Size = new System.Drawing.Size(608, 217);
            this.tabPage14.TabIndex = 4;
            this.tabPage14.Text = "Ja";
            this.tabPage14.UseVisualStyleBackColor = true;
            // 
            // grvVocabJa
            // 
            this.grvVocabJa.AllowUserToAddRows = false;
            this.grvVocabJa.AllowUserToDeleteRows = false;
            this.grvVocabJa.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabJa.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabJaText,
            this.colVocabJaMeaning,
            this.colVocabJaObject});
            this.grvVocabJa.Location = new System.Drawing.Point(7, 6);
            this.grvVocabJa.Name = "grvVocabJa";
            this.grvVocabJa.Size = new System.Drawing.Size(595, 205);
            this.grvVocabJa.TabIndex = 20;
            // 
            // colVocabJaText
            // 
            this.colVocabJaText.DataPropertyName = "DisplayText";
            this.colVocabJaText.HeaderText = "Text";
            this.colVocabJaText.MinimumWidth = 100;
            this.colVocabJaText.Name = "colVocabJaText";
            // 
            // colVocabJaMeaning
            // 
            this.colVocabJaMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabJaMeaning.DataPropertyName = "Meaning";
            this.colVocabJaMeaning.HeaderText = "Meaning";
            this.colVocabJaMeaning.MinimumWidth = 100;
            this.colVocabJaMeaning.Name = "colVocabJaMeaning";
            // 
            // colVocabJaObject
            // 
            this.colVocabJaObject.DataPropertyName = "EnhancementJson";
            this.colVocabJaObject.HeaderText = "Vocab Object";
            this.colVocabJaObject.Name = "colVocabJaObject";
            // 
            // tabPage15
            // 
            this.tabPage15.Controls.Add(this.grvVocabKo);
            this.tabPage15.Location = new System.Drawing.Point(4, 22);
            this.tabPage15.Name = "tabPage15";
            this.tabPage15.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage15.Size = new System.Drawing.Size(608, 217);
            this.tabPage15.TabIndex = 5;
            this.tabPage15.Text = "Ko";
            this.tabPage15.UseVisualStyleBackColor = true;
            // 
            // grvVocabKo
            // 
            this.grvVocabKo.AllowUserToAddRows = false;
            this.grvVocabKo.AllowUserToDeleteRows = false;
            this.grvVocabKo.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabKo.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabKoText,
            this.colVocabKoMeaning,
            this.colVocabKoObject});
            this.grvVocabKo.Location = new System.Drawing.Point(7, 6);
            this.grvVocabKo.Name = "grvVocabKo";
            this.grvVocabKo.Size = new System.Drawing.Size(595, 205);
            this.grvVocabKo.TabIndex = 20;
            // 
            // colVocabKoText
            // 
            this.colVocabKoText.DataPropertyName = "DisplayText";
            this.colVocabKoText.HeaderText = "Text";
            this.colVocabKoText.MinimumWidth = 100;
            this.colVocabKoText.Name = "colVocabKoText";
            // 
            // colVocabKoMeaning
            // 
            this.colVocabKoMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabKoMeaning.DataPropertyName = "Meaning";
            this.colVocabKoMeaning.HeaderText = "Meaning";
            this.colVocabKoMeaning.MinimumWidth = 100;
            this.colVocabKoMeaning.Name = "colVocabKoMeaning";
            // 
            // colVocabKoObject
            // 
            this.colVocabKoObject.DataPropertyName = "EnhancementJson";
            this.colVocabKoObject.HeaderText = "Vocab Object";
            this.colVocabKoObject.Name = "colVocabKoObject";
            // 
            // tabPage16
            // 
            this.tabPage16.Controls.Add(this.grvVocabPt);
            this.tabPage16.Location = new System.Drawing.Point(4, 22);
            this.tabPage16.Name = "tabPage16";
            this.tabPage16.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage16.Size = new System.Drawing.Size(608, 217);
            this.tabPage16.TabIndex = 6;
            this.tabPage16.Text = "Pt";
            this.tabPage16.UseVisualStyleBackColor = true;
            // 
            // grvVocabPt
            // 
            this.grvVocabPt.AllowUserToAddRows = false;
            this.grvVocabPt.AllowUserToDeleteRows = false;
            this.grvVocabPt.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabPt.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabPtText,
            this.colVocabPtMeaning,
            this.colVocabPtObject});
            this.grvVocabPt.Location = new System.Drawing.Point(7, 6);
            this.grvVocabPt.Name = "grvVocabPt";
            this.grvVocabPt.Size = new System.Drawing.Size(595, 205);
            this.grvVocabPt.TabIndex = 20;
            // 
            // colVocabPtText
            // 
            this.colVocabPtText.DataPropertyName = "DisplayText";
            this.colVocabPtText.HeaderText = "Text";
            this.colVocabPtText.MinimumWidth = 100;
            this.colVocabPtText.Name = "colVocabPtText";
            // 
            // colVocabPtMeaning
            // 
            this.colVocabPtMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabPtMeaning.DataPropertyName = "Meaning";
            this.colVocabPtMeaning.HeaderText = "Meaning";
            this.colVocabPtMeaning.MinimumWidth = 100;
            this.colVocabPtMeaning.Name = "colVocabPtMeaning";
            // 
            // colVocabPtObject
            // 
            this.colVocabPtObject.DataPropertyName = "EnhancementJson";
            this.colVocabPtObject.HeaderText = "Vocab Object";
            this.colVocabPtObject.Name = "colVocabPtObject";
            // 
            // tabPage17
            // 
            this.tabPage17.Controls.Add(this.grvVocabRu);
            this.tabPage17.Location = new System.Drawing.Point(4, 22);
            this.tabPage17.Name = "tabPage17";
            this.tabPage17.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage17.Size = new System.Drawing.Size(608, 217);
            this.tabPage17.TabIndex = 7;
            this.tabPage17.Text = "Ru";
            this.tabPage17.UseVisualStyleBackColor = true;
            // 
            // grvVocabRu
            // 
            this.grvVocabRu.AllowUserToAddRows = false;
            this.grvVocabRu.AllowUserToDeleteRows = false;
            this.grvVocabRu.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabRu.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabRuText,
            this.colVocabRuMeaning,
            this.colVocabRuObject});
            this.grvVocabRu.Location = new System.Drawing.Point(7, 6);
            this.grvVocabRu.Name = "grvVocabRu";
            this.grvVocabRu.Size = new System.Drawing.Size(595, 205);
            this.grvVocabRu.TabIndex = 20;
            // 
            // colVocabRuText
            // 
            this.colVocabRuText.DataPropertyName = "DisplayText";
            this.colVocabRuText.HeaderText = "Text";
            this.colVocabRuText.MinimumWidth = 100;
            this.colVocabRuText.Name = "colVocabRuText";
            // 
            // colVocabRuMeaning
            // 
            this.colVocabRuMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabRuMeaning.DataPropertyName = "Meaning";
            this.colVocabRuMeaning.HeaderText = "Meaning";
            this.colVocabRuMeaning.MinimumWidth = 100;
            this.colVocabRuMeaning.Name = "colVocabRuMeaning";
            // 
            // colVocabRuObject
            // 
            this.colVocabRuObject.DataPropertyName = "EnhancementJson";
            this.colVocabRuObject.HeaderText = "Vocab Object";
            this.colVocabRuObject.Name = "colVocabRuObject";
            // 
            // tabPage18
            // 
            this.tabPage18.Controls.Add(this.grvVocabZh);
            this.tabPage18.Location = new System.Drawing.Point(4, 22);
            this.tabPage18.Name = "tabPage18";
            this.tabPage18.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage18.Size = new System.Drawing.Size(608, 217);
            this.tabPage18.TabIndex = 8;
            this.tabPage18.Text = "Zh";
            this.tabPage18.UseVisualStyleBackColor = true;
            // 
            // grvVocabZh
            // 
            this.grvVocabZh.AllowUserToAddRows = false;
            this.grvVocabZh.AllowUserToDeleteRows = false;
            this.grvVocabZh.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvVocabZh.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.colVocabZhText,
            this.colVocabZhMeaning,
            this.colVocabZhObject});
            this.grvVocabZh.Location = new System.Drawing.Point(7, 6);
            this.grvVocabZh.Name = "grvVocabZh";
            this.grvVocabZh.Size = new System.Drawing.Size(595, 205);
            this.grvVocabZh.TabIndex = 20;
            // 
            // colVocabZhText
            // 
            this.colVocabZhText.DataPropertyName = "DisplayText";
            this.colVocabZhText.HeaderText = "Text";
            this.colVocabZhText.MinimumWidth = 100;
            this.colVocabZhText.Name = "colVocabZhText";
            // 
            // colVocabZhMeaning
            // 
            this.colVocabZhMeaning.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.colVocabZhMeaning.DataPropertyName = "Meaning";
            this.colVocabZhMeaning.HeaderText = "Meaning";
            this.colVocabZhMeaning.MinimumWidth = 100;
            this.colVocabZhMeaning.Name = "colVocabZhMeaning";
            // 
            // colVocabZhObject
            // 
            this.colVocabZhObject.DataPropertyName = "EnhancementJson";
            this.colVocabZhObject.HeaderText = "Vocab Object";
            this.colVocabZhObject.Name = "colVocabZhObject";
            // 
            // btnSubmitAndAddNew
            // 
            this.btnSubmitAndAddNew.Location = new System.Drawing.Point(270, 927);
            this.btnSubmitAndAddNew.Name = "btnSubmitAndAddNew";
            this.btnSubmitAndAddNew.Size = new System.Drawing.Size(189, 59);
            this.btnSubmitAndAddNew.TabIndex = 19;
            this.btnSubmitAndAddNew.Text = "Submit and Add New";
            this.btnSubmitAndAddNew.UseVisualStyleBackColor = true;
            this.btnSubmitAndAddNew.Click += new System.EventHandler(this.btnSubmitAndAddNew_Click);
            // 
            // txtDuration
            // 
            this.txtDuration.Location = new System.Drawing.Point(92, 164);
            this.txtDuration.Maximum = new decimal(new int[] {
            10000,
            0,
            0,
            0});
            this.txtDuration.Name = "txtDuration";
            this.txtDuration.Size = new System.Drawing.Size(122, 20);
            this.txtDuration.TabIndex = 11;
            // 
            // btnGetLink
            // 
            this.btnGetLink.Location = new System.Drawing.Point(540, 136);
            this.btnGetLink.Name = "btnGetLink";
            this.btnGetLink.Size = new System.Drawing.Size(83, 23);
            this.btnGetLink.TabIndex = 20;
            this.btnGetLink.Text = "Get link";
            this.btnGetLink.UseVisualStyleBackColor = true;
            this.btnGetLink.Click += new System.EventHandler(this.btnGetLink_Click);
            // 
            // txtThumb
            // 
            this.txtThumb.Location = new System.Drawing.Point(93, 110);
            this.txtThumb.Name = "txtThumb";
            this.txtThumb.Size = new System.Drawing.Size(441, 20);
            this.txtThumb.TabIndex = 9;
            // 
            // btnImageLink
            // 
            this.btnImageLink.Location = new System.Drawing.Point(540, 108);
            this.btnImageLink.Name = "btnImageLink";
            this.btnImageLink.Size = new System.Drawing.Size(82, 23);
            this.btnImageLink.TabIndex = 9;
            this.btnImageLink.Text = "Browse";
            this.btnImageLink.UseVisualStyleBackColor = true;
            this.btnImageLink.Click += new System.EventHandler(this.btnImageLink_Click);
            // 
            // label20
            // 
            this.label20.AutoSize = true;
            this.label20.Location = new System.Drawing.Point(13, 113);
            this.label20.Name = "label20";
            this.label20.Size = new System.Drawing.Size(72, 13);
            this.label20.TabIndex = 33;
            this.label20.Text = "Thumb Image";
            // 
            // txtGrammar
            // 
            this.txtGrammar.Location = new System.Drawing.Point(383, 191);
            this.txtGrammar.Multiline = true;
            this.txtGrammar.Name = "txtGrammar";
            this.txtGrammar.Size = new System.Drawing.Size(240, 67);
            this.txtGrammar.TabIndex = 13;
            // 
            // label15
            // 
            this.label15.AutoSize = true;
            this.label15.Location = new System.Drawing.Point(328, 191);
            this.label15.Name = "label15";
            this.label15.Size = new System.Drawing.Size(49, 13);
            this.label15.TabIndex = 31;
            this.label15.Text = "Grammar";
            // 
            // btnSubmit
            // 
            this.btnSubmit.Location = new System.Drawing.Point(462, 927);
            this.btnSubmit.Name = "btnSubmit";
            this.btnSubmit.Size = new System.Drawing.Size(159, 60);
            this.btnSubmit.TabIndex = 20;
            this.btnSubmit.Text = "Submit to Firebase";
            this.btnSubmit.UseVisualStyleBackColor = true;
            this.btnSubmit.Click += new System.EventHandler(this.btnSubmit_Click);
            // 
            // txtHomeNumber
            // 
            this.txtHomeNumber.Location = new System.Drawing.Point(93, 862);
            this.txtHomeNumber.Name = "txtHomeNumber";
            this.txtHomeNumber.Size = new System.Drawing.Size(530, 20);
            this.txtHomeNumber.TabIndex = 18;
            // 
            // label38
            // 
            this.label38.AutoSize = true;
            this.label38.Location = new System.Drawing.Point(13, 862);
            this.label38.Name = "label38";
            this.label38.Size = new System.Drawing.Size(73, 13);
            this.label38.TabIndex = 28;
            this.label38.Text = "Home number";
            // 
            // txtNumber
            // 
            this.txtNumber.Location = new System.Drawing.Point(93, 836);
            this.txtNumber.Name = "txtNumber";
            this.txtNumber.Size = new System.Drawing.Size(530, 20);
            this.txtNumber.TabIndex = 17;
            // 
            // label19
            // 
            this.label19.AutoSize = true;
            this.label19.Location = new System.Drawing.Point(13, 839);
            this.label19.Name = "label19";
            this.label19.Size = new System.Drawing.Size(44, 13);
            this.label19.TabIndex = 26;
            this.label19.Text = "Number";
            // 
            // txtSummary
            // 
            this.txtSummary.Location = new System.Drawing.Point(93, 191);
            this.txtSummary.Multiline = true;
            this.txtSummary.Name = "txtSummary";
            this.txtSummary.Size = new System.Drawing.Size(229, 67);
            this.txtSummary.TabIndex = 12;
            // 
            // label14
            // 
            this.label14.AutoSize = true;
            this.label14.Location = new System.Drawing.Point(13, 191);
            this.label14.Name = "label14";
            this.label14.Size = new System.Drawing.Size(50, 13);
            this.label14.TabIndex = 24;
            this.label14.Text = "Summary";
            // 
            // txtVocab
            // 
            this.txtVocab.Location = new System.Drawing.Point(92, 418);
            this.txtVocab.Multiline = true;
            this.txtVocab.Name = "txtVocab";
            this.txtVocab.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.txtVocab.Size = new System.Drawing.Size(530, 115);
            this.txtVocab.TabIndex = 15;
            this.txtVocab.Leave += new System.EventHandler(this.txtVocab_Leave);
            // 
            // label13
            // 
            this.label13.AutoSize = true;
            this.label13.Location = new System.Drawing.Point(12, 421);
            this.label13.Name = "label13";
            this.label13.Size = new System.Drawing.Size(38, 13);
            this.label13.TabIndex = 22;
            this.label13.Text = "Vocab";
            // 
            // label22
            // 
            this.label22.AutoSize = true;
            this.label22.Location = new System.Drawing.Point(12, 163);
            this.label22.Name = "label22";
            this.label22.Size = new System.Drawing.Size(47, 13);
            this.label22.TabIndex = 20;
            this.label22.Text = "Duration";
            // 
            // dpPublishDate
            // 
            this.dpPublishDate.Location = new System.Drawing.Point(92, 84);
            this.dpPublishDate.Name = "dpPublishDate";
            this.dpPublishDate.Size = new System.Drawing.Size(217, 20);
            this.dpPublishDate.TabIndex = 7;
            // 
            // label10
            // 
            this.label10.AutoSize = true;
            this.label10.Location = new System.Drawing.Point(12, 88);
            this.label10.Name = "label10";
            this.label10.Size = new System.Drawing.Size(65, 13);
            this.label10.TabIndex = 18;
            this.label10.Text = "Publish date";
            // 
            // cbYear
            // 
            this.cbYear.FormattingEnabled = true;
            this.cbYear.Location = new System.Drawing.Point(560, 28);
            this.cbYear.Name = "cbYear";
            this.cbYear.Size = new System.Drawing.Size(61, 21);
            this.cbYear.TabIndex = 6;
            // 
            // cbType
            // 
            this.cbType.FormattingEnabled = true;
            this.cbType.Items.AddRange(new object[] {
            "BBC",
            "VOA"});
            this.cbType.Location = new System.Drawing.Point(404, 28);
            this.cbType.Name = "cbType";
            this.cbType.Size = new System.Drawing.Size(82, 21);
            this.cbType.TabIndex = 4;
            this.cbType.SelectedIndexChanged += new System.EventHandler(this.cbType_SelectedIndexChanged);
            // 
            // cbCategory
            // 
            this.cbCategory.FormattingEnabled = true;
            this.cbCategory.Location = new System.Drawing.Point(492, 28);
            this.cbCategory.Name = "cbCategory";
            this.cbCategory.Size = new System.Drawing.Size(62, 21);
            this.cbCategory.TabIndex = 5;
            // 
            // txtFileUrl
            // 
            this.txtFileUrl.Location = new System.Drawing.Point(93, 138);
            this.txtFileUrl.Name = "txtFileUrl";
            this.txtFileUrl.Size = new System.Drawing.Size(441, 20);
            this.txtFileUrl.TabIndex = 20;
            // 
            // txtEpisodeName
            // 
            this.txtEpisodeName.Location = new System.Drawing.Point(404, 84);
            this.txtEpisodeName.Name = "txtEpisodeName";
            this.txtEpisodeName.Size = new System.Drawing.Size(218, 20);
            this.txtEpisodeName.TabIndex = 8;
            // 
            // label8
            // 
            this.label8.AutoSize = true;
            this.label8.Location = new System.Drawing.Point(13, 141);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(37, 13);
            this.label8.TabIndex = 7;
            this.label8.Text = "File url";
            // 
            // txtId
            // 
            this.txtId.Location = new System.Drawing.Point(92, 28);
            this.txtId.Name = "txtId";
            this.txtId.Size = new System.Drawing.Size(217, 20);
            this.txtId.TabIndex = 3;
            // 
            // label9
            // 
            this.label9.AutoSize = true;
            this.label9.Location = new System.Drawing.Point(324, 88);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(74, 13);
            this.label9.TabIndex = 8;
            this.label9.Text = "Episode name";
            // 
            // label40
            // 
            this.label40.AutoSize = true;
            this.label40.Location = new System.Drawing.Point(367, 31);
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
            this.tabControl1.Controls.Add(this.tabPage3);
            this.tabControl1.Controls.Add(this.tabPage4);
            this.tabControl1.Controls.Add(this.tabPage5);
            this.tabControl1.Controls.Add(this.tabPage6);
            this.tabControl1.Controls.Add(this.tabPage7);
            this.tabControl1.Controls.Add(this.tabPage8);
            this.tabControl1.Controls.Add(this.tabPage9);
            this.tabControl1.Location = new System.Drawing.Point(502, 12);
            this.tabControl1.Name = "tabControl1";
            this.tabControl1.SelectedIndex = 0;
            this.tabControl1.Size = new System.Drawing.Size(1065, 915);
            this.tabControl1.TabIndex = 18;
            // 
            // tabPage1
            // 
            this.tabPage1.Controls.Add(this.grvRow);
            this.tabPage1.Controls.Add(this.label2);
            this.tabPage1.Controls.Add(this.txtTranscript);
            this.tabPage1.Location = new System.Drawing.Point(4, 22);
            this.tabPage1.Name = "tabPage1";
            this.tabPage1.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage1.Size = new System.Drawing.Size(1057, 889);
            this.tabPage1.TabIndex = 0;
            this.tabPage1.Text = "En";
            this.tabPage1.UseVisualStyleBackColor = true;
            // 
            // tabPage2
            // 
            this.tabPage2.Controls.Add(this.txtViTranscript);
            this.tabPage2.Controls.Add(this.label23);
            this.tabPage2.Controls.Add(this.grvViRow);
            this.tabPage2.Location = new System.Drawing.Point(4, 22);
            this.tabPage2.Name = "tabPage2";
            this.tabPage2.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage2.Size = new System.Drawing.Size(1057, 889);
            this.tabPage2.TabIndex = 1;
            this.tabPage2.Text = "Viet Nam";
            this.tabPage2.UseVisualStyleBackColor = true;
            // 
            // txtViTranscript
            // 
            this.txtViTranscript.Location = new System.Drawing.Point(9, 26);
            this.txtViTranscript.Multiline = true;
            this.txtViTranscript.Name = "txtViTranscript";
            this.txtViTranscript.Size = new System.Drawing.Size(1042, 184);
            this.txtViTranscript.TabIndex = 14;
            this.txtViTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label23
            // 
            this.label23.AutoSize = true;
            this.label23.Location = new System.Drawing.Point(6, 9);
            this.label23.Name = "label23";
            this.label23.Size = new System.Drawing.Size(54, 13);
            this.label23.TabIndex = 13;
            this.label23.Text = "Transcript";
            // 
            // grvViRow
            // 
            this.grvViRow.AllowUserToAddRows = false;
            this.grvViRow.AllowUserToDeleteRows = false;
            this.grvViRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvViRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn2,
            this.GrammarExplainationVi});
            this.grvViRow.Location = new System.Drawing.Point(6, 233);
            this.grvViRow.Name = "grvViRow";
            this.grvViRow.Size = new System.Drawing.Size(1045, 650);
            this.grvViRow.TabIndex = 12;
            // 
            // dataGridViewTextBoxColumn2
            // 
            this.dataGridViewTextBoxColumn2.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn2.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn2.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn2.Name = "dataGridViewTextBoxColumn2";
            // 
            // GrammarExplainationVi
            // 
            this.GrammarExplainationVi.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationVi.HeaderText = "Grammar Explaination";
            this.GrammarExplainationVi.Name = "GrammarExplainationVi";
            this.GrammarExplainationVi.Width = 200;
            // 
            // tabPage3
            // 
            this.tabPage3.Controls.Add(this.txtEsTranscript);
            this.tabPage3.Controls.Add(this.label24);
            this.tabPage3.Controls.Add(this.grvEsRow);
            this.tabPage3.Location = new System.Drawing.Point(4, 22);
            this.tabPage3.Name = "tabPage3";
            this.tabPage3.Size = new System.Drawing.Size(1057, 889);
            this.tabPage3.TabIndex = 2;
            this.tabPage3.Text = "Es";
            this.tabPage3.UseVisualStyleBackColor = true;
            // 
            // txtEsTranscript
            // 
            this.txtEsTranscript.Location = new System.Drawing.Point(9, 24);
            this.txtEsTranscript.Multiline = true;
            this.txtEsTranscript.Name = "txtEsTranscript";
            this.txtEsTranscript.Size = new System.Drawing.Size(1045, 174);
            this.txtEsTranscript.TabIndex = 17;
            this.txtEsTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label24
            // 
            this.label24.AutoSize = true;
            this.label24.Location = new System.Drawing.Point(6, 7);
            this.label24.Name = "label24";
            this.label24.Size = new System.Drawing.Size(54, 13);
            this.label24.TabIndex = 16;
            this.label24.Text = "Transcript";
            // 
            // grvEsRow
            // 
            this.grvEsRow.AllowUserToAddRows = false;
            this.grvEsRow.AllowUserToDeleteRows = false;
            this.grvEsRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvEsRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn6,
            this.GrammarExplainationEs});
            this.grvEsRow.Location = new System.Drawing.Point(6, 231);
            this.grvEsRow.Name = "grvEsRow";
            this.grvEsRow.Size = new System.Drawing.Size(1048, 655);
            this.grvEsRow.TabIndex = 15;
            // 
            // dataGridViewTextBoxColumn6
            // 
            this.dataGridViewTextBoxColumn6.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn6.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn6.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn6.Name = "dataGridViewTextBoxColumn6";
            // 
            // GrammarExplainationEs
            // 
            this.GrammarExplainationEs.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationEs.HeaderText = "Grammar Explaination";
            this.GrammarExplainationEs.Name = "GrammarExplainationEs";
            this.GrammarExplainationEs.Width = 200;
            // 
            // tabPage4
            // 
            this.tabPage4.Controls.Add(this.txtArTranscript);
            this.tabPage4.Controls.Add(this.label25);
            this.tabPage4.Controls.Add(this.grvArRow);
            this.tabPage4.Location = new System.Drawing.Point(4, 22);
            this.tabPage4.Name = "tabPage4";
            this.tabPage4.Size = new System.Drawing.Size(1057, 889);
            this.tabPage4.TabIndex = 3;
            this.tabPage4.Text = "Ar";
            this.tabPage4.UseVisualStyleBackColor = true;
            // 
            // txtArTranscript
            // 
            this.txtArTranscript.Location = new System.Drawing.Point(9, 24);
            this.txtArTranscript.Multiline = true;
            this.txtArTranscript.Name = "txtArTranscript";
            this.txtArTranscript.Size = new System.Drawing.Size(1045, 174);
            this.txtArTranscript.TabIndex = 17;
            this.txtArTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label25
            // 
            this.label25.AutoSize = true;
            this.label25.Location = new System.Drawing.Point(6, 7);
            this.label25.Name = "label25";
            this.label25.Size = new System.Drawing.Size(54, 13);
            this.label25.TabIndex = 16;
            this.label25.Text = "Transcript";
            // 
            // grvArRow
            // 
            this.grvArRow.AllowUserToAddRows = false;
            this.grvArRow.AllowUserToDeleteRows = false;
            this.grvArRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvArRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn10,
            this.GrammarExplainationAr});
            this.grvArRow.Location = new System.Drawing.Point(6, 231);
            this.grvArRow.Name = "grvArRow";
            this.grvArRow.Size = new System.Drawing.Size(1048, 655);
            this.grvArRow.TabIndex = 15;
            // 
            // dataGridViewTextBoxColumn10
            // 
            this.dataGridViewTextBoxColumn10.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn10.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn10.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn10.Name = "dataGridViewTextBoxColumn10";
            // 
            // GrammarExplainationAr
            // 
            this.GrammarExplainationAr.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationAr.HeaderText = "Grammar Explaination";
            this.GrammarExplainationAr.Name = "GrammarExplainationAr";
            this.GrammarExplainationAr.Width = 200;
            // 
            // tabPage5
            // 
            this.tabPage5.Controls.Add(this.txtJaTranscript);
            this.tabPage5.Controls.Add(this.label26);
            this.tabPage5.Controls.Add(this.grvJaRow);
            this.tabPage5.Location = new System.Drawing.Point(4, 22);
            this.tabPage5.Name = "tabPage5";
            this.tabPage5.Size = new System.Drawing.Size(1057, 889);
            this.tabPage5.TabIndex = 4;
            this.tabPage5.Text = "Ja";
            this.tabPage5.UseVisualStyleBackColor = true;
            // 
            // txtJaTranscript
            // 
            this.txtJaTranscript.Location = new System.Drawing.Point(9, 24);
            this.txtJaTranscript.Multiline = true;
            this.txtJaTranscript.Name = "txtJaTranscript";
            this.txtJaTranscript.Size = new System.Drawing.Size(1045, 174);
            this.txtJaTranscript.TabIndex = 17;
            this.txtJaTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label26
            // 
            this.label26.AutoSize = true;
            this.label26.Location = new System.Drawing.Point(6, 7);
            this.label26.Name = "label26";
            this.label26.Size = new System.Drawing.Size(54, 13);
            this.label26.TabIndex = 16;
            this.label26.Text = "Transcript";
            // 
            // grvJaRow
            // 
            this.grvJaRow.AllowUserToAddRows = false;
            this.grvJaRow.AllowUserToDeleteRows = false;
            this.grvJaRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvJaRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn14,
            this.GrammarExplainationJa});
            this.grvJaRow.Location = new System.Drawing.Point(6, 231);
            this.grvJaRow.Name = "grvJaRow";
            this.grvJaRow.Size = new System.Drawing.Size(1048, 655);
            this.grvJaRow.TabIndex = 15;
            // 
            // dataGridViewTextBoxColumn14
            // 
            this.dataGridViewTextBoxColumn14.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn14.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn14.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn14.Name = "dataGridViewTextBoxColumn14";
            // 
            // GrammarExplainationJa
            // 
            this.GrammarExplainationJa.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationJa.HeaderText = "Grammar Explaination";
            this.GrammarExplainationJa.Name = "GrammarExplainationJa";
            this.GrammarExplainationJa.Width = 200;
            // 
            // tabPage6
            // 
            this.tabPage6.Controls.Add(this.txtKoTranscript);
            this.tabPage6.Controls.Add(this.label27);
            this.tabPage6.Controls.Add(this.grvKoRow);
            this.tabPage6.Location = new System.Drawing.Point(4, 22);
            this.tabPage6.Name = "tabPage6";
            this.tabPage6.Size = new System.Drawing.Size(1057, 889);
            this.tabPage6.TabIndex = 5;
            this.tabPage6.Text = "Ko";
            this.tabPage6.UseVisualStyleBackColor = true;
            // 
            // txtKoTranscript
            // 
            this.txtKoTranscript.Location = new System.Drawing.Point(9, 24);
            this.txtKoTranscript.Multiline = true;
            this.txtKoTranscript.Name = "txtKoTranscript";
            this.txtKoTranscript.Size = new System.Drawing.Size(1048, 174);
            this.txtKoTranscript.TabIndex = 17;
            this.txtKoTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label27
            // 
            this.label27.AutoSize = true;
            this.label27.Location = new System.Drawing.Point(6, 7);
            this.label27.Name = "label27";
            this.label27.Size = new System.Drawing.Size(54, 13);
            this.label27.TabIndex = 16;
            this.label27.Text = "Transcript";
            // 
            // grvKoRow
            // 
            this.grvKoRow.AllowUserToAddRows = false;
            this.grvKoRow.AllowUserToDeleteRows = false;
            this.grvKoRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvKoRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn18,
            this.GrammarExplainationKo});
            this.grvKoRow.Location = new System.Drawing.Point(6, 231);
            this.grvKoRow.Name = "grvKoRow";
            this.grvKoRow.Size = new System.Drawing.Size(1048, 655);
            this.grvKoRow.TabIndex = 15;
            // 
            // dataGridViewTextBoxColumn18
            // 
            this.dataGridViewTextBoxColumn18.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn18.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn18.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn18.Name = "dataGridViewTextBoxColumn18";
            // 
            // GrammarExplainationKo
            // 
            this.GrammarExplainationKo.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationKo.HeaderText = "Grammar Explaination";
            this.GrammarExplainationKo.Name = "GrammarExplainationKo";
            this.GrammarExplainationKo.Width = 200;
            // 
            // tabPage7
            // 
            this.tabPage7.Controls.Add(this.txtPtTranscript);
            this.tabPage7.Controls.Add(this.label28);
            this.tabPage7.Controls.Add(this.grvPtRow);
            this.tabPage7.Location = new System.Drawing.Point(4, 22);
            this.tabPage7.Name = "tabPage7";
            this.tabPage7.Size = new System.Drawing.Size(1057, 889);
            this.tabPage7.TabIndex = 6;
            this.tabPage7.Text = "Pt";
            this.tabPage7.UseVisualStyleBackColor = true;
            // 
            // txtPtTranscript
            // 
            this.txtPtTranscript.Location = new System.Drawing.Point(9, 24);
            this.txtPtTranscript.Multiline = true;
            this.txtPtTranscript.Name = "txtPtTranscript";
            this.txtPtTranscript.Size = new System.Drawing.Size(1048, 174);
            this.txtPtTranscript.TabIndex = 17;
            this.txtPtTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label28
            // 
            this.label28.AutoSize = true;
            this.label28.Location = new System.Drawing.Point(6, 7);
            this.label28.Name = "label28";
            this.label28.Size = new System.Drawing.Size(54, 13);
            this.label28.TabIndex = 16;
            this.label28.Text = "Transcript";
            // 
            // grvPtRow
            // 
            this.grvPtRow.AllowUserToAddRows = false;
            this.grvPtRow.AllowUserToDeleteRows = false;
            this.grvPtRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvPtRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn22,
            this.GrammarExplainationPt});
            this.grvPtRow.Location = new System.Drawing.Point(6, 231);
            this.grvPtRow.Name = "grvPtRow";
            this.grvPtRow.Size = new System.Drawing.Size(1048, 655);
            this.grvPtRow.TabIndex = 15;
            // 
            // dataGridViewTextBoxColumn22
            // 
            this.dataGridViewTextBoxColumn22.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn22.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn22.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn22.Name = "dataGridViewTextBoxColumn22";
            // 
            // GrammarExplainationPt
            // 
            this.GrammarExplainationPt.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationPt.HeaderText = "Grammar Explaination";
            this.GrammarExplainationPt.Name = "GrammarExplainationPt";
            this.GrammarExplainationPt.Width = 200;
            // 
            // tabPage8
            // 
            this.tabPage8.Controls.Add(this.txtRuTranscript);
            this.tabPage8.Controls.Add(this.label29);
            this.tabPage8.Controls.Add(this.grvRuRow);
            this.tabPage8.Location = new System.Drawing.Point(4, 22);
            this.tabPage8.Name = "tabPage8";
            this.tabPage8.Size = new System.Drawing.Size(1057, 889);
            this.tabPage8.TabIndex = 7;
            this.tabPage8.Text = "Ru";
            this.tabPage8.UseVisualStyleBackColor = true;
            // 
            // txtRuTranscript
            // 
            this.txtRuTranscript.Location = new System.Drawing.Point(9, 24);
            this.txtRuTranscript.Multiline = true;
            this.txtRuTranscript.Name = "txtRuTranscript";
            this.txtRuTranscript.Size = new System.Drawing.Size(1045, 174);
            this.txtRuTranscript.TabIndex = 17;
            this.txtRuTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label29
            // 
            this.label29.AutoSize = true;
            this.label29.Location = new System.Drawing.Point(6, 7);
            this.label29.Name = "label29";
            this.label29.Size = new System.Drawing.Size(54, 13);
            this.label29.TabIndex = 16;
            this.label29.Text = "Transcript";
            // 
            // grvRuRow
            // 
            this.grvRuRow.AllowUserToAddRows = false;
            this.grvRuRow.AllowUserToDeleteRows = false;
            this.grvRuRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvRuRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn26,
            this.GrammarExplainationRu});
            this.grvRuRow.Location = new System.Drawing.Point(6, 231);
            this.grvRuRow.Name = "grvRuRow";
            this.grvRuRow.Size = new System.Drawing.Size(1048, 655);
            this.grvRuRow.TabIndex = 15;
            // 
            // dataGridViewTextBoxColumn26
            // 
            this.dataGridViewTextBoxColumn26.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn26.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn26.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn26.Name = "dataGridViewTextBoxColumn26";
            // 
            // GrammarExplainationRu
            // 
            this.GrammarExplainationRu.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationRu.HeaderText = "Grammar Explaination";
            this.GrammarExplainationRu.Name = "GrammarExplainationRu";
            this.GrammarExplainationRu.Width = 200;
            // 
            // tabPage9
            // 
            this.tabPage9.Controls.Add(this.txtZhTranscript);
            this.tabPage9.Controls.Add(this.label30);
            this.tabPage9.Controls.Add(this.grvZhRow);
            this.tabPage9.Location = new System.Drawing.Point(4, 22);
            this.tabPage9.Name = "tabPage9";
            this.tabPage9.Size = new System.Drawing.Size(1057, 889);
            this.tabPage9.TabIndex = 8;
            this.tabPage9.Text = "Zh";
            this.tabPage9.UseVisualStyleBackColor = true;
            // 
            // txtZhTranscript
            // 
            this.txtZhTranscript.Location = new System.Drawing.Point(9, 24);
            this.txtZhTranscript.Multiline = true;
            this.txtZhTranscript.Name = "txtZhTranscript";
            this.txtZhTranscript.Size = new System.Drawing.Size(1045, 174);
            this.txtZhTranscript.TabIndex = 17;
            this.txtZhTranscript.Leave += new System.EventHandler(this.LocaleTranscript_Leave);
            // 
            // label30
            // 
            this.label30.AutoSize = true;
            this.label30.Location = new System.Drawing.Point(6, 7);
            this.label30.Name = "label30";
            this.label30.Size = new System.Drawing.Size(54, 13);
            this.label30.TabIndex = 16;
            this.label30.Text = "Transcript";
            // 
            // grvZhRow
            // 
            this.grvZhRow.AllowUserToAddRows = false;
            this.grvZhRow.AllowUserToDeleteRows = false;
            this.grvZhRow.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.grvZhRow.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.dataGridViewTextBoxColumn30,
            this.GrammarExplainationZh});
            this.grvZhRow.Location = new System.Drawing.Point(6, 231);
            this.grvZhRow.Name = "grvZhRow";
            this.grvZhRow.Size = new System.Drawing.Size(1048, 655);
            this.grvZhRow.TabIndex = 15;
            // 
            // dataGridViewTextBoxColumn30
            // 
            this.dataGridViewTextBoxColumn30.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.dataGridViewTextBoxColumn30.DataPropertyName = "RowContent";
            this.dataGridViewTextBoxColumn30.HeaderText = "Row Content";
            this.dataGridViewTextBoxColumn30.Name = "dataGridViewTextBoxColumn30";
            // 
            // GrammarExplainationZh
            // 
            this.GrammarExplainationZh.DataPropertyName = "GrammarExplanationSummary";
            this.GrammarExplainationZh.HeaderText = "Grammar Explaination";
            this.GrammarExplainationZh.Name = "GrammarExplainationZh";
            this.GrammarExplainationZh.Width = 200;
            // 
            // btngetGrammarExplaimation
            // 
            this.btngetGrammarExplaimation.Location = new System.Drawing.Point(1396, 1008);
            this.btngetGrammarExplaimation.Name = "btngetGrammarExplaimation";
            this.btngetGrammarExplaimation.Size = new System.Drawing.Size(164, 79);
            this.btngetGrammarExplaimation.TabIndex = 23;
            this.btngetGrammarExplaimation.Text = "Get Grammar Explaination";
            this.btngetGrammarExplaimation.UseVisualStyleBackColor = true;
            this.btngetGrammarExplaimation.Click += new System.EventHandler(this.btngetGrammarExplaimation_Click);
            // 
            // statusStripGrammar
            // 
            this.statusStripGrammar.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.toolStripProgressGrammar,
            this.toolStripStatusLabelGrammar});
            this.statusStripGrammar.Location = new System.Drawing.Point(0, 1097);
            this.statusStripGrammar.Name = "statusStripGrammar";
            this.statusStripGrammar.Size = new System.Drawing.Size(2214, 22);
            this.statusStripGrammar.SizingGrip = false;
            this.statusStripGrammar.TabIndex = 100;
            this.statusStripGrammar.Text = "statusStripGrammar";
            // 
            // toolStripProgressGrammar
            // 
            this.toolStripProgressGrammar.Name = "toolStripProgressGrammar";
            this.toolStripProgressGrammar.Size = new System.Drawing.Size(200, 16);
            this.toolStripProgressGrammar.Visible = false;
            // 
            // toolStripStatusLabelGrammar
            // 
            this.toolStripStatusLabelGrammar.Name = "toolStripStatusLabelGrammar";
            this.toolStripStatusLabelGrammar.Size = new System.Drawing.Size(2199, 17);
            this.toolStripStatusLabelGrammar.Spring = true;
            this.toolStripStatusLabelGrammar.Text = "Sẵn sàng.";
            this.toolStripStatusLabelGrammar.TextAlign = System.Drawing.ContentAlignment.MiddleLeft;
            // 
            // groupBox4
            // 
            this.groupBox4.Controls.Add(this.btnPlay);
            this.groupBox4.Controls.Add(this.btnForward);
            this.groupBox4.Controls.Add(this.btnReward);
            this.groupBox4.Location = new System.Drawing.Point(855, 929);
            this.groupBox4.Name = "groupBox4";
            this.groupBox4.Size = new System.Drawing.Size(359, 100);
            this.groupBox4.TabIndex = 101;
            this.groupBox4.TabStop = false;
            this.groupBox4.Text = "Action";
            // 
            // frmMain
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(2214, 1119);
            this.Controls.Add(this.groupBox4);
            this.Controls.Add(this.btngetGrammarExplaimation);
            this.Controls.Add(this.tabControl1);
            this.Controls.Add(this.groupBox3);
            this.Controls.Add(this.groupBox2);
            this.Controls.Add(this.groupBox1);
            this.Controls.Add(this.btnConvertGridToResult);
            this.Controls.Add(this.txtGroupResult);
            this.Controls.Add(this.txtResult);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.statusStripGrammar);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Name = "frmMain";
            this.Text = "Play MP3";
            ((System.ComponentModel.ISupportInitialize)(this.grvRow)).EndInit();
            this.groupBox1.ResumeLayout(false);
            this.groupBox1.PerformLayout();
            this.groupBox2.ResumeLayout(false);
            this.groupBox2.PerformLayout();
            this.groupBox3.ResumeLayout(false);
            this.groupBox3.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvQuestions)).EndInit();
            this.tabControl2.ResumeLayout(false);
            this.tabPage10.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabEn)).EndInit();
            this.tabPage11.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabVi)).EndInit();
            this.tabPage12.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabEs)).EndInit();
            this.tabPage13.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabAr)).EndInit();
            this.tabPage14.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabJa)).EndInit();
            this.tabPage15.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabKo)).EndInit();
            this.tabPage16.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabPt)).EndInit();
            this.tabPage17.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabRu)).EndInit();
            this.tabPage18.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.grvVocabZh)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.txtDuration)).EndInit();
            this.tabControl1.ResumeLayout(false);
            this.tabPage1.ResumeLayout(false);
            this.tabPage1.PerformLayout();
            this.tabPage2.ResumeLayout(false);
            this.tabPage2.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvViRow)).EndInit();
            this.tabPage3.ResumeLayout(false);
            this.tabPage3.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvEsRow)).EndInit();
            this.tabPage4.ResumeLayout(false);
            this.tabPage4.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvArRow)).EndInit();
            this.tabPage5.ResumeLayout(false);
            this.tabPage5.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvJaRow)).EndInit();
            this.tabPage6.ResumeLayout(false);
            this.tabPage6.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvKoRow)).EndInit();
            this.tabPage7.ResumeLayout(false);
            this.tabPage7.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvPtRow)).EndInit();
            this.tabPage8.ResumeLayout(false);
            this.tabPage8.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvRuRow)).EndInit();
            this.tabPage9.ResumeLayout(false);
            this.tabPage9.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.grvZhRow)).EndInit();
            this.statusStripGrammar.ResumeLayout(false);
            this.statusStripGrammar.PerformLayout();
            this.groupBox4.ResumeLayout(false);
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
        private System.Windows.Forms.Button btnConvertGridToResult;
        private System.Windows.Forms.TextBox txtGroupResult;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Label label7;
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
        private System.Windows.Forms.TextBox txtViTranscript;
        private System.Windows.Forms.Label label23;
        private System.Windows.Forms.DataGridView grvViRow;
        private System.Windows.Forms.TabPage tabPage3;
        private System.Windows.Forms.TextBox txtEsTranscript;
        private System.Windows.Forms.Label label24;
        private System.Windows.Forms.DataGridView grvEsRow;
        private System.Windows.Forms.TabPage tabPage4;
        private System.Windows.Forms.TextBox txtArTranscript;
        private System.Windows.Forms.Label label25;
        private System.Windows.Forms.DataGridView grvArRow;
        private System.Windows.Forms.TabPage tabPage5;
        private System.Windows.Forms.TextBox txtJaTranscript;
        private System.Windows.Forms.Label label26;
        private System.Windows.Forms.DataGridView grvJaRow;
        private System.Windows.Forms.TabPage tabPage6;
        private System.Windows.Forms.TextBox txtKoTranscript;
        private System.Windows.Forms.Label label27;
        private System.Windows.Forms.DataGridView grvKoRow;
        private System.Windows.Forms.TabPage tabPage7;
        private System.Windows.Forms.TextBox txtPtTranscript;
        private System.Windows.Forms.Label label28;
        private System.Windows.Forms.DataGridView grvPtRow;
        private System.Windows.Forms.TabPage tabPage8;
        private System.Windows.Forms.TextBox txtRuTranscript;
        private System.Windows.Forms.Label label29;
        private System.Windows.Forms.DataGridView grvRuRow;
        private System.Windows.Forms.TabPage tabPage9;
        private System.Windows.Forms.TextBox txtZhTranscript;
        private System.Windows.Forms.Label label30;
        private System.Windows.Forms.DataGridView grvZhRow;
        private System.Windows.Forms.Button btngetGrammarExplaimation;
        private System.Windows.Forms.StatusStrip statusStripGrammar;
        private System.Windows.Forms.ToolStripProgressBar toolStripProgressGrammar;
        private System.Windows.Forms.ToolStripStatusLabel toolStripStatusLabelGrammar;
        private System.Windows.Forms.TabControl tabControl2;
        private System.Windows.Forms.TabPage tabPage10;
        private System.Windows.Forms.DataGridView grvVocabEn;
        private System.Windows.Forms.TabPage tabPage11;
        private System.Windows.Forms.DataGridView grvVocabVi;
        private System.Windows.Forms.TabPage tabPage12;
        private System.Windows.Forms.DataGridView grvVocabEs;
        private System.Windows.Forms.TabPage tabPage13;
        private System.Windows.Forms.DataGridView grvVocabAr;
        private System.Windows.Forms.TabPage tabPage14;
        private System.Windows.Forms.DataGridView grvVocabJa;
        private System.Windows.Forms.TabPage tabPage15;
        private System.Windows.Forms.DataGridView grvVocabKo;
        private System.Windows.Forms.TabPage tabPage16;
        private System.Windows.Forms.DataGridView grvVocabPt;
        private System.Windows.Forms.TabPage tabPage17;
        private System.Windows.Forms.DataGridView grvVocabRu;
        private System.Windows.Forms.TabPage tabPage18;
        private System.Windows.Forms.DataGridView grvVocabZh;
        private System.Windows.Forms.Button btnGetVocabTransLateAndObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn2;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationVi;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn6;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationEs;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn10;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationAr;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn14;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationJa;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn18;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationKo;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn22;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationPt;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn26;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationRu;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn30;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationZh;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabEnText;
        private System.Windows.Forms.DataGridViewTextBoxColumn dataGridViewTextBoxColumn34;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabEnObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabViText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabViMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabViObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabEsText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabEsMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabEsObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabArText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabArMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabArObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabJaText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabJaMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabJaObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabKoText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabKoMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabKoObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabPtText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabPtMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabPtObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabRuText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabRuMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabRuObject;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabZhText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabZhMeaning;
        private System.Windows.Forms.DataGridViewTextBoxColumn colVocabZhObject;
        private System.Windows.Forms.Label label12;
        private System.Windows.Forms.DataGridView grvQuestions;
        private System.Windows.Forms.DataGridViewTextBoxColumn colQuestionType;
        private System.Windows.Forms.DataGridViewTextBoxColumn colQuestionText;
        private System.Windows.Forms.DataGridViewTextBoxColumn colQuestionOptions;
        private System.Windows.Forms.DataGridViewTextBoxColumn colQuestionCorrect;
        private System.Windows.Forms.DataGridViewTextBoxColumn colQuestionExplanation;
        private System.Windows.Forms.Button btnGetQuestions;
        private System.Windows.Forms.GroupBox groupBox4;
        private System.Windows.Forms.DataGridViewTextBoxColumn FirstDuration;
        private System.Windows.Forms.DataGridViewTextBoxColumn RowContent;
        private System.Windows.Forms.DataGridViewTextBoxColumn LastDuration;
        private System.Windows.Forms.DataGridViewTextBoxColumn GrammarExplainationEn;
        private System.Windows.Forms.TextBox txtASSeriesChild;
        private System.Windows.Forms.Label lblASSeriesChild;
        private System.Windows.Forms.CheckBox cbExportGrammar;
        private System.Windows.Forms.CheckBox cbExportVocabulary;
        private System.Windows.Forms.CheckBox cbExportQuestions;
        private System.Windows.Forms.CheckBox cbExportEpisodeDetail;
        private System.Windows.Forms.CheckBox cbSendEpisodePush;
        private System.Windows.Forms.CheckBox cbExportTranslation;
        private System.Windows.Forms.ComboBox cbLevel;
        private System.Windows.Forms.Label label3;
    }
}

