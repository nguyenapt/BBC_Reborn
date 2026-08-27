using Firebase.Auth;
using Firebase.Database;
using Firebase.Database.Query;
using Firebase.Storage;
using playMP3.Base;
using playMP3.Properties;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Configuration;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using FirebaseAdmin.Auth;
using FirebaseAuth = FirebaseAdmin.Auth.FirebaseAuth;
using System.Xml;
using Google.Api.Gax;
using System.Text.RegularExpressions;

namespace playMP3
{
    public partial class frmMain : Form
    {
        private ConfigModel _configModel;
        public ConfigModel ConfigModel
        {
            get
            {
                if (_configModel == null)
                {
                    _configModel = new ConfigModel();
                }
                return _configModel;
            }
        }

        System.Windows.Media.MediaPlayer player;
        Boolean isPlay = false;
        int intCursorPos;
        readonly Dictionary<DataGridView, Label> _transcriptRowCountLabels = new Dictionary<DataGridView, Label>();

        public frmMain()
        {
            InitializeComponent();
            player = new System.Windows.Media.MediaPlayer();
            var transcriptGrids = new DataGridView[] { grvRow, grvViRow, grvEsRow, grvArRow, grvJaRow, grvKoRow, grvPtRow, grvRuRow, grvZhRow, grvFrRow, grvDeRow };
            foreach (var g in transcriptGrids)
            {
                ApplyTranscriptRowGridStyle(g);
                EnsureTranscriptRowCountLabel(g);
            }

            foreach (var g in new DataGridView[] {
                grvVocabEn, grvVocabVi, grvVocabEs, grvVocabAr, grvVocabJa, grvVocabKo, grvVocabPt, grvVocabRu, grvVocabZh, grvVocabFr, grvVocabDe })
            {
                ApplyVocabGridStyle(g);
            }

            for (int i = DateTime.Now.Year; i >= 2013; i--)
            {
                cbYear.Items.Add(i.ToString());
            }

            txtId.Text = Guid.NewGuid().ToString();
            cbYear.SelectedIndex = 0;
            ReadConfigFile();

            if (cbSendEpisodePush != null)
                cbSendEpisodePush.Checked = ConfigModel.SendEpisodePush;

            cbCloudService.DisplayMember = "Name";
            cbCloudService.ValueMember = "Name";
            cbCloudService.DataSource = this.ConfigModel.CloudServices;

            var preferredCloud = ConfigModel.CloudServices.FirstOrDefault(x => x.IsSelected)
                                 ?? ConfigModel.CloudServices.FirstOrDefault();
            if (preferredCloud != null)
            {
                cbCloudService.SelectedItem = preferredCloud;
                ConfigModel.SelectedCloudService = preferredCloud;
                ActiveRtdbContext.Set(preferredCloud.Url ?? txtUrl.Text, preferredCloud.Secret ?? txtSecret.Text);
            }

            // Filter Type theo Cloud Service (BBC → BBC, VOA → VOA, British → British).
            ApplyEpisodeTypeFilterForCloudService();

            // UI: only show AS-series child field when category == "AS".
            // (Designer does not wire cbCategory.SelectedIndexChanged.)
            if (cbCategory != null)
                cbCategory.SelectedIndexChanged += (_, __) => UpdateASSeriesChildVisibility();
            if (cbType != null)
                cbType.SelectedIndexChanged += (_, __) => UpdateASSeriesChildVisibility();

            UpdateASSeriesChildVisibility();
            UpdateCbLevelEnabled();
            UpdateSendEpisodePushLabel();
        }

        private bool IsVoaCloudService()
        {
            var name = (cbCloudService?.SelectedItem as CloudService)?.Name
                       ?? ConfigModel.SelectedCloudService?.Name;
            return string.Equals(name, "VOA", StringComparison.OrdinalIgnoreCase);
        }

        private bool IsBritishCloudService()
        {
            var name = (cbCloudService?.SelectedItem as CloudService)?.Name
                       ?? ConfigModel.SelectedCloudService?.Name;
            return string.Equals(name, "British", StringComparison.OrdinalIgnoreCase);
        }

        private string CurrentCloudServiceName()
        {
            return ((cbCloudService?.SelectedItem as CloudService)?.Name
                    ?? ConfigModel.SelectedCloudService?.Name
                    ?? string.Empty).Trim();
        }

        private RtdbLayoutKind CurrentRtdbLayout()
        {
            return RtdbLayoutStrategy.ResolveFromCloudName(CurrentCloudServiceName());
        }

        private string ResolveFcmProfileName()
        {
            if (IsBritishCloudService())
                return EpisodeFcmSender.ProfileBritish;
            if (IsVoaCloudService())
                return EpisodeFcmSender.ProfileVoa;
            return EpisodeFcmSender.ProfileBbc;
        }

        private string ResolveFcmServiceAccountPath()
        {
            if (IsBritishCloudService())
                return ConfigModel.FcmServiceAccountPathBritish;
            if (IsVoaCloudService())
                return ConfigModel.FcmServiceAccountPathVoa;
            return ConfigModel.FcmServiceAccountPath;
        }

        private void UpdateSendEpisodePushLabel()
        {
            if (cbSendEpisodePush == null)
                return;

            var path = ResolveFcmServiceAccountPath();
            if (string.IsNullOrWhiteSpace(path) && !IsVoaCloudService() && !IsBritishCloudService())
            {
                var env = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
                if (!string.IsNullOrWhiteSpace(env) && File.Exists(env))
                    path = env;
            }

            var fileName = string.IsNullOrWhiteSpace(path)
                ? null
                : Path.GetFileNameWithoutExtension(path.Trim());

            cbSendEpisodePush.Text = string.IsNullOrWhiteSpace(fileName)
                ? "Gửi push FCM"
                : "Gửi push FCM (" + fileName + ")";
        }

        /// <summary>BBC cloud → Type BBC; VOA → VOA; British → British; khác → tất cả EpisodeTypes.</summary>
        private void ApplyEpisodeTypeFilterForCloudService()
        {
            if (cbType == null || ConfigModel.EpisodeTypes == null || ConfigModel.EpisodeTypes.Count == 0)
                return;

            // UI selection là nguồn đúng (tránh SelectedCloudService lệch).
            var cloud = cbCloudService?.SelectedItem as CloudService;
            if (cloud != null)
                ConfigModel.SelectedCloudService = cloud;

            var cloudName = (cloud?.Name ?? ConfigModel.SelectedCloudService?.Name ?? string.Empty).Trim();
            var forceMatchCloud = string.Equals(cloudName, "BBC", StringComparison.OrdinalIgnoreCase)
                                  || string.Equals(cloudName, "VOA", StringComparison.OrdinalIgnoreCase)
                                  || string.Equals(cloudName, "British", StringComparison.OrdinalIgnoreCase);

            List<EpisodeTypeModel> filtered;
            if (forceMatchCloud)
            {
                filtered = ConfigModel.EpisodeTypes
                    .Where(t => string.Equals((t.Name ?? string.Empty).Trim(), cloudName, StringComparison.OrdinalIgnoreCase))
                    .ToList();
            }
            else
            {
                filtered = ConfigModel.EpisodeTypes.ToList();
            }

            EpisodeTypeModel toSelect = null;
            if (forceMatchCloud)
            {
                // Luôn chọn Type trùng cloud — không giữ BBC khi đổi sang VOA.
                toSelect = filtered.FirstOrDefault();
            }
            else
            {
                var previousName = (cbType.SelectedItem as EpisodeTypeModel)?.Name
                                   ?? ConfigModel.SelectedEpisodeType?.Name;
                if (!string.IsNullOrEmpty(previousName))
                {
                    toSelect = filtered.FirstOrDefault(t =>
                        string.Equals(t.Name, previousName, StringComparison.OrdinalIgnoreCase));
                }
                if (toSelect == null)
                    toSelect = filtered.FirstOrDefault(t => t.IsSelected) ?? filtered.FirstOrDefault();
            }

            // Tránh NRE trong SelectedIndexChanged khi clear/rebind (làm ComboBox giữ list cũ).
            cbType.SelectedIndexChanged -= cbType_SelectedIndexChanged;
            cbType.BeginUpdate();
            try
            {
                cbType.DataSource = null;
                cbType.Items.Clear();
                cbType.DisplayMember = "Name";
                foreach (var t in filtered)
                    cbType.Items.Add(t);

                if (toSelect != null)
                {
                    cbType.SelectedItem = toSelect;
                    ConfigModel.SelectedEpisodeType = toSelect;
                    if (cbCategory != null)
                    {
                        cbCategory.DataSource = toSelect.EpisodeCategories;
                        cbCategory.DisplayMember = "Category";
                        cbCategory.ValueMember = "Category";
                    }
                }
            }
            finally
            {
                cbType.EndUpdate();
                cbType.SelectedIndexChanged += cbType_SelectedIndexChanged;
            }

            // BBC/VOA chỉ còn 1 Type hợp lệ — khóa dropdown để khỏi chọn nhầm.
            cbType.Enabled = !forceMatchCloud || filtered.Count != 1;
        }

        private void UpdateCbLevelEnabled()
        {
            if (cbLevel == null) return;
            var enabled = IsVoaCloudService();
            cbLevel.Enabled = enabled;
            if (lblLevel != null)
                lblLevel.Enabled = enabled;
            if (!enabled)
            {
                cbLevel.SelectedIndex = 0;
            }
        }

        private void ApplyVoaLevelToEpisode(Episode episode)
        {
            if (!IsVoaCloudService() || cbLevel == null || !cbLevel.Enabled)
            {
                episode.Level = null;
                return;
            }

            var selectedLevel = (cbLevel.Text ?? string.Empty).Trim();
            episode.Level = string.IsNullOrEmpty(selectedLevel) || selectedLevel == "--Select--"
                ? null
                : selectedLevel;
        }

        private static Dictionary<string, object> BuildListEpisodePayload(Episode episode)
        {
            var payload = new Dictionary<string, object>
            {
                ["Category"] = episode.Category,
                ["EpisodeName"] = episode.EpisodeName,
                ["FileUrl"] = episode.FileUrl,
                ["Id"] = episode.Id,
                ["IsNew"] = episode.IsNew,
                ["PublishedDate"] = episode.PublishedDate,
                ["GrammarVocabularyCacheKeys"] = episode.GrammarVocabularyCacheKeys,
                ["Summary"] = episode.Summary,
                ["ThumbImage"] = episode.ThumbImage,
                ["Year"] = episode.Year,
            };

            if (!string.IsNullOrEmpty(episode.RtdbPath))
                payload["RtdbPath"] = episode.RtdbPath;

            if (!string.IsNullOrEmpty(episode.Level))
                payload["Level"] = episode.Level;

            return payload;
        }

        private void UpdateASSeriesChildVisibility()
        {
            var isAs = string.Equals((cbCategory?.Text ?? string.Empty).Trim(), "AS", StringComparison.OrdinalIgnoreCase);
            if (lblASSeriesChild != null) lblASSeriesChild.Visible = isAs;
            if (txtASSeriesChild != null) txtASSeriesChild.Visible = isAs;
        }

        private bool IsAnotherSeriesCategorySelected()
        {
            return string.Equals((cbCategory?.Text ?? string.Empty).Trim(), "AS", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Khi Category = AS (Another Series), field Category của episode và nhánh RTDB phải là mã con (OF, EIM…),
        /// không phải chữ "AS". Đường dẫn đầy đủ thêm năm nếu category có IsSupportYear.
        /// </summary>
        private void ResolveCategoryForEpisodeAndFirebasePaths(out string episodeCategory, out string firebaseCategoryPathRoot)
        {
            var sel = (cbCategory?.Text ?? string.Empty).Trim();
            if (IsAnotherSeriesCategorySelected())
            {
                var sub = (txtASSeriesChild?.Text ?? string.Empty).Trim().Trim('/');
                if (string.IsNullOrEmpty(sub))
                {
                    throw new InvalidOperationException(
                        "Khi Category = AS, hãy nhập mã series con (ví dụ OF, EIM) vào ô AS series.");
                }

                episodeCategory = sub;
                firebaseCategoryPathRoot = "AS/" + sub;
                return;
            }

            episodeCategory = sel;
            firebaseCategoryPathRoot = sel;
        }

        private void btnBrowse_Click(object sender, EventArgs e)
        {
            if (openFileDialog1.ShowDialog() == DialogResult.OK)
            {
                txtFilePath.Text = openFileDialog1.FileName;
                player.Open(new System.Uri(txtFilePath.Text));
            }
        }

        private void btnPlay_Click(object sender, EventArgs e)
        {
            if (grvRow.SelectedRows.Count == 0)
            {
                grvRow.Rows[0].Selected = true;
            }

            if (!isPlay)
            {
                player.Play();
                if (player.NaturalDuration.HasTimeSpan)
                {
                    txtLength.Text = "[" + player.NaturalDuration.TimeSpan.TotalMilliseconds.ToString() + "]";
                }
                isPlay = true;
                btnPlay.Image = Resources.pause_48;
            }
            else
            {
                btnPlay.Image = Resources.play_6_48;
                isPlay = false;
                if (player != null)
                {
                    player.Pause();
                    var pos = Math.Truncate(player.Position.TotalMilliseconds);
                    txtPosition.Text = "[" + pos + "]";
                    txtNextPosition.Text = "[" + (pos + 1) + "]";

                    if (grvRow.SelectedRows.Count != 0)
                    {
                        DataGridViewRow row = this.grvRow.SelectedRows[0];
                        row.Cells["LastDuration"].Value = pos;
                        row.Selected = false;
                        if (row.Index + 1 < grvRow.Rows.Count)
                        {
                            DataGridViewRow row1 = grvRow.Rows[row.Index + 1];
                            row1.Selected = true;
                            row1.Cells["FirstDuration"].Value = (pos + 1);
                        }
                        else
                        {
                            var endPos = txtLength.Text.Replace("[", "").Replace("]", "");
                            row.Cells["LastDuration"].Value = endPos;
                        }
                    }
                }
            }
        }

        private void btnForward_Click(object sender, EventArgs e)
        {
            TimeSpan newPosition = player.Position.Add(new TimeSpan(0, 0, 5));
            player.Position = newPosition;
        }

        private void btnReward_Click(object sender, EventArgs e)
        {
            TimeSpan newPosition = player.Position.Add(new TimeSpan(0, 0, -5));
            player.Position = newPosition;
        }

        private void txtPosition_Click(object sender, EventArgs e)
        {
            txtPosition.SelectAll();

            // Copy the contents of the control to the Clipboard.
            txtPosition.Copy();

            txtTranscript.Text.Insert(intCursorPos, txtPosition.Text);
        }

        private void txtNextPosition_Click(object sender, EventArgs e)
        {
            txtNextPosition.SelectAll();

            // Copy the contents of the control to the Clipboard.
            txtNextPosition.Copy();

            txtTranscript.Text.Insert(intCursorPos, txtNextPosition.Text);
        }

        private void txtTranscript_Leave(object sender, EventArgs e)
        {
            ConvertToGrid();
        }

        private void LocaleTranscript_Leave(object sender, EventArgs e)
        {
            if (!(sender is TextBox tb))
            {
                return;
            }

            var grid = GetLocaleGridForTranscript(tb);
            if (grid != null)
            {
                FillGridFromTranscriptText(tb.Text, grid);
            }
        }

        private DataGridView GetLocaleGridForTranscript(TextBox tb)
        {
            if (ReferenceEquals(tb, null))
            {
                return null;
            }

            if (ReferenceEquals(tb, txtViTranscript)) return grvViRow;
            if (ReferenceEquals(tb, txtEsTranscript)) return grvEsRow;
            if (ReferenceEquals(tb, txtArTranscript)) return grvArRow;
            if (ReferenceEquals(tb, txtJaTranscript)) return grvJaRow;
            if (ReferenceEquals(tb, txtKoTranscript)) return grvKoRow;
            if (ReferenceEquals(tb, txtPtTranscript)) return grvPtRow;
            if (ReferenceEquals(tb, txtRuTranscript)) return grvRuRow;
            if (ReferenceEquals(tb, txtZhTranscript)) return grvZhRow;
            if (ReferenceEquals(tb, txtFrTranscript)) return grvFrRow;
            if (ReferenceEquals(tb, txtDeTranscript)) return grvDeRow;
            return null;
        }

        private static void ApplyTranscriptRowGridStyle(DataGridView grid)
        {
            grid.AutoGenerateColumns = false;
            grid.RowTemplate.Height = 40;
            grid.DefaultCellStyle.WrapMode = DataGridViewTriState.True;
            grid.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.AllCellsExceptHeaders;
            if (!grid.Columns.Contains("RowNumber"))
            {
                grid.Columns.Insert(0, new DataGridViewTextBoxColumn
                {
                    Name = "RowNumber",
                    DataPropertyName = "RowNumber",
                    HeaderText = "Number Row",
                    Width = 50,
                    ReadOnly = true,
                });
            }
        }

        private void EnsureTranscriptRowCountLabel(DataGridView grid)
        {
            if (_transcriptRowCountLabels.ContainsKey(grid))
                return;

            var lbl = new Label
            {
                AutoSize = true,
                Text = "Rows: 0",
            };
            grid.Parent.Controls.Add(lbl);
            lbl.BringToFront();
            _transcriptRowCountLabels[grid] = lbl;

            void reposition()
            {
                lbl.Location = new Point(grid.Right - lbl.PreferredWidth, grid.Top - lbl.Height - 2);
            }

            grid.LocationChanged += (_, __) => reposition();
            grid.SizeChanged += (_, __) => reposition();
            reposition();
        }

        private void UpdateTranscriptGridRowCountLabel(DataGridView grid)
        {
            if (!_transcriptRowCountLabels.TryGetValue(grid, out var lbl))
                return;

            lbl.Text = "Rows: " + GetEpisodeRowCount(grid);
            lbl.Location = new Point(grid.Right - lbl.PreferredWidth, grid.Top - lbl.Height - 2);
        }

        private void btnConvertToGrid_Click(object sender, EventArgs e)
        {
            ConvertToGrid();
        }

        public void FillGridFromTranscriptText(string text, DataGridView grid)
        {
            // Capture before clear: Leave transcript rebuilds the grid and would wipe GrammarExplanation* unless we copy back per matching row.
            var previous = grid.DataSource as BindingList<EpisodeRowModel>;
            grid.DataSource = null;

            var lstRows = (text ?? string.Empty).Split(new string[] { Environment.NewLine + Environment.NewLine },
                               StringSplitOptions.RemoveEmptyEntries);
            var lstRowModels = new BindingList<EpisodeRowModel>();

            for (var i = 0; i < lstRows.Length; i++)
            {
                var trimmed = lstRows[i].Trim();
                var m = new EpisodeRowModel { RowNumber = i, FirstDuration = 0, RowContent = trimmed, LastDuration = 0, Group = 0 };

                if (previous != null && i < previous.Count)
                {
                    var prev = previous[i];
                    var prevContent = (prev.RowContent ?? string.Empty).Trim();
                    if (string.Equals(prevContent, trimmed, StringComparison.Ordinal))
                    {
                        m.FirstDuration = prev.FirstDuration;
                        m.LastDuration = prev.LastDuration;
                        m.Group = prev.Group;
                        m.GrammarExplanationSummary = prev.GrammarExplanationSummary;
                        m.GrammarExplanationJson = prev.GrammarExplanationJson;
                    }
                }

                lstRowModels.Add(m);
            }

            grid.DataSource = lstRowModels;
            grid.AutoResizeRows(DataGridViewAutoSizeRowsMode.AllCellsExceptHeaders);
            UpdateTranscriptGridRowCountLabel(grid);
        }

        public void ConvertToGrid()
        {
            FillGridFromTranscriptText(txtTranscript.Text, grvRow);
        }

        /// <summary>
        /// Một số layout grid không có cột Group — không được indexer Cells["Group"] khi cột không tồn tại.
        /// </summary>
        private int GetRowGroupValue(DataGridViewRow row)
        {
            if (!grvRow.Columns.Contains("Group"))
                return 0;
            var val = row.Cells["Group"].Value;
            if (val == null)
                return 0;
            return int.TryParse(val.ToString(), out var g) ? g : 0;
        }

        private void btnConvertGridToResult_Click(object sender, EventArgs e)
        {
            string result = "";
            foreach (DataGridViewRow row in grvRow.Rows)
            {
                result += $"[{row.Cells["FirstDuration"].Value}]{row.Cells["RowContent"].Value}[{row.Cells["LastDuration"].Value}]";
                result += Environment.NewLine + Environment.NewLine;
            }

            txtResult.Text = result;

            var dics = new Dictionary<int, List<DataGridViewRow>>();

            foreach (DataGridViewRow row in grvRow.Rows)
            {
                var group = GetRowGroupValue(row);
                if (!dics.ContainsKey(group))
                {
                    var lstRowTemp = new List<DataGridViewRow>();
                    lstRowTemp.Add(row);
                    dics.Add(group, lstRowTemp);
                }
                else
                {
                    var lstRowTemp = dics[group];
                    lstRowTemp.Add(row);
                    dics[group] = lstRowTemp;
                }
            }

            string groupResult = "";

            foreach (var group in dics)
            {
                if (group.Value != null && group.Value.Any())
                {
                    var lstRowTemp = group.Value;
                    for (int i = 0; i < lstRowTemp.Count; i++)
                    {
                        DataGridViewRow row = lstRowTemp[i];
                        if (i == 0)
                        {
                            groupResult += $"[{row.Cells["FirstDuration"].Value}]";
                            groupResult += Environment.NewLine;
                        }

                        var rowContents = row.Cells["RowContent"].Value.ToString().Split(new string[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries).ToList();

                        if (rowContents != null && rowContents.Any())
                        {
                            foreach (var rc in rowContents)
                            {
                                
                                groupResult += $"{rc}<br />";
                                
                            }
                        }

                        groupResult += Environment.NewLine;
                        if (i == lstRowTemp.Count - 1)
                        {
                            groupResult += $"[{row.Cells["LastDuration"].Value}]";
                            groupResult += Environment.NewLine;
                            groupResult += $"[ER]";
                            groupResult += Environment.NewLine;
                        }
                    }
                }
            }

            txtGroupResult.Text = groupResult;

        }

        private void ReadConfigFile()
        {
            var baseDir = AppDomain.CurrentDomain.BaseDirectory ?? "";
            string configFileName = Path.Combine(baseDir, "service.config");
            if (!File.Exists(configFileName))
                configFileName = Path.Combine(Directory.GetCurrentDirectory(), "service.config");
            if (File.Exists(configFileName))
            {
                XmlDocument m_xmld = default(XmlDocument);
                XmlNodeList m_nodelistKey = default(XmlNodeList);
                m_xmld = new XmlDocument();
                m_xmld.Load(configFileName);

                m_nodelistKey = m_xmld.SelectNodes(@"/Configurations/EpisodeTypes/EpisodeType");

                foreach (XmlNode m_node in m_nodelistKey)
                {
                    var episodeType = new EpisodeTypeModel();
                    episodeType.IsSelected = m_node.Attributes != null && m_node.Attributes["isselected"] != null ? bool.Parse(m_node.Attributes["isselected"].Value) : false;

                    foreach (XmlNode node in m_node.ChildNodes)
                    {
                        if (node.Name.Equals("Name", StringComparison.CurrentCultureIgnoreCase))
                            episodeType.Name = node.InnerText;
                        else if (node.Name.Equals("Category", StringComparison.CurrentCultureIgnoreCase))
                        {
                            var episodeCategory = new EpisodeCategoryModel();
                            episodeCategory.IsSelected = node.Attributes != null && node.Attributes["isselected"] != null ? bool.Parse(node.Attributes["isselected"].Value) : false;
                            episodeCategory.IsSupportYear = node.Attributes != null && node.Attributes["issupportyear"] != null ? bool.Parse(node.Attributes["issupportyear"].Value) : false;
                            episodeCategory.Category = node.InnerText;
                            episodeType.EpisodeCategories.Add(episodeCategory);
                        }
                    }

                    ConfigModel.EpisodeTypes.Add(episodeType);
                }

                m_nodelistKey = m_xmld.SelectNodes(@"/Configurations/CloudServices/CloudService");

                foreach (XmlNode m_node in m_nodelistKey)
                {
                    var cloudService = new CloudService();
                    cloudService.IsSelected = m_node.Attributes != null && m_node.Attributes["isselected"] != null ? bool.Parse(m_node.Attributes["isselected"].Value) : false;

                    foreach (XmlNode node in m_node.ChildNodes)
                    {
                        if (node.Name.Equals("Name", StringComparison.CurrentCultureIgnoreCase))
                            cloudService.Name = node.InnerText;
                        else if (node.Name.Equals("Url", StringComparison.CurrentCultureIgnoreCase))
                        {
                            cloudService.Url = node.InnerText;
                        }
                        else if (node.Name.Equals("ApiKey", StringComparison.CurrentCultureIgnoreCase))
                        {
                            cloudService.ApiKey = node.InnerText;
                        }
                        else if (node.Name.Equals("Secret", StringComparison.CurrentCultureIgnoreCase))
                        {
                            cloudService.Secret = node.InnerText;
                        }
                        else if (node.Name.Equals("Storage", StringComparison.CurrentCultureIgnoreCase))
                        {
                            cloudService.Storage = node.InnerText;
                        }
                    }

                    ConfigModel.CloudServices.Add(cloudService);
                }

                var geminiNode = m_xmld.SelectSingleNode("/Configurations/GeminiApiKey");
                if (geminiNode != null)
                    ConfigModel.GeminiApiKey = (geminiNode.InnerText ?? string.Empty).Trim();

                var delayNode = m_xmld.SelectSingleNode("/Configurations/GeminiRequestDelayMs");
                if (delayNode != null && int.TryParse((delayNode.InnerText ?? string.Empty).Trim(), out var delayMs) && delayMs >= 0 && delayMs <= 120_000)
                    ConfigModel.GeminiRequestDelayMs = delayMs;

                var fcmPathNode = m_xmld.SelectSingleNode("/Configurations/FcmServiceAccountPath");
                if (fcmPathNode != null)
                    ConfigModel.FcmServiceAccountPath = (fcmPathNode.InnerText ?? string.Empty).Trim();

                var fcmVoaPathNode = m_xmld.SelectSingleNode("/Configurations/FcmServiceAccountPathVOA");
                if (fcmVoaPathNode != null)
                    ConfigModel.FcmServiceAccountPathVoa = (fcmVoaPathNode.InnerText ?? string.Empty).Trim();

                var fcmBritishPathNode = m_xmld.SelectSingleNode("/Configurations/FcmServiceAccountPathBritish");
                if (fcmBritishPathNode != null)
                    ConfigModel.FcmServiceAccountPathBritish = (fcmBritishPathNode.InnerText ?? string.Empty).Trim();

                var sendPushNode = m_xmld.SelectSingleNode("/Configurations/SendEpisodePush");
                if (sendPushNode != null)
                {
                    var pushText = (sendPushNode.InnerText ?? string.Empty).Trim();
                    if (bool.TryParse(pushText, out var sendPush))
                        ConfigModel.SendEpisodePush = sendPush;
                }
            }
            else
            {
                throw new Exception("Config file not found.");
            }
        }

        /// <summary>GEMINI_API_KEY → GOOGLE_API_KEY → service.config; each value may be comma-separated keys.</summary>
        private IReadOnlyList<string> TryResolveGeminiApiKeys()
        {
            var a = GeminiApiKeyList.Parse(Environment.GetEnvironmentVariable("GEMINI_API_KEY"));
            if (a.Length > 0)
                return a;
            a = GeminiApiKeyList.Parse(Environment.GetEnvironmentVariable("GOOGLE_API_KEY"));
            if (a.Length > 0)
                return a;
            a = GeminiApiKeyList.Parse(ConfigModel.GeminiApiKey);
            if (a.Length > 0)
                return a;
            return Array.Empty<string>();
        }

        private async void btnSubmit_Click(object sender, EventArgs e)
        {
            try
            {
                await OnSubmitAsync().ConfigureAwait(true);
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Submit", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private async Task upload(string fileName, FileStream fileStream)
        {

            var task = await new FirebaseStorage(ConfigModel.SelectedCloudService.Storage, new FirebaseStorageOptions
            {
                AuthTokenAsyncFactory = () => Task.FromResult(txtSecret.Text),

            })
                .Child(cbCategory.Text + (ConfigModel.SelectedEpisodeType.EpisodeCategories.Where(x => x.IsSupportYear).Select(x => x.Category).Contains(cbCategory.Text) ? "/" + cbYear.Text : "") + "/" + fileName)
                .PutAsync(fileStream);

            try
            {
                // error during upload will be thrown when you await the task
                txtFileUrl.Text = task;
            }
            catch (Exception ex)
            {
                Console.WriteLine("Exception was thrown: {0}", ex);
            }
        }


        private async Task<bool> OnSubmitAsync()
        {
            if (string.IsNullOrWhiteSpace(txtResult.Text))
            {
                MessageBox.Show(
                    this,
                    "Result (Transcript HTML) is required before submit.",
                    "Submit",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                txtResult.Focus();
                return false;
            }

            FirebaseClient firebaseClient = new FirebaseClient(txtUrl.Text, new FirebaseOptions
            {
                AuthTokenAsyncFactory = () => Task.FromResult(txtSecret.Text)
            });

            var exportEpisodeDetail = cbExportEpisodeDetail != null && cbExportEpisodeDetail.Checked;
            var exportTranslation = cbExportTranslation != null && cbExportTranslation.Checked;
            var exportQuestions = cbExportQuestions != null && cbExportQuestions.Checked;
            var exportVocabulary = cbExportVocabulary != null && cbExportVocabulary.Checked;
            var exportGrammar = cbExportGrammar != null && cbExportGrammar.Checked;

            var episode = new Episode();
            if (!string.IsNullOrEmpty(txtId.Text))
            {
                Guid id = Guid.Empty;
                Guid.TryParse(txtId.Text, out id);
                episode.Id = id == Guid.Empty ? Guid.NewGuid() : id;
            }
            else
            {
                episode.Id = Guid.NewGuid();
            }
            txtId.Text = episode.Id.ToString();
            ResolveCategoryForEpisodeAndFirebasePaths(out var episodeCategory, out var firebaseCategoryPathRoot);
            episode.Category = episodeCategory;
            episode.Year = cbYear.Text;
            episode.PublishedDate = dpPublishDate.Value;
            episode.ThumbImage = txtThumb.Text;
            episode.EpisodeName = txtEpisodeName.Text;
            episode.FileUrl = txtFileUrl.Text;
            episode.Transcript = txtTranscript.Text;
            episode.TranscriptHtml = txtResult.Text;
            //episode.TranscriptHtml = txtGroupResult.Text;
            episode.Vocabulary = txtVocab.Text;
            if (int.TryParse(txtDuration.Text, out var duration))
            {
                episode.Duration = duration;
            }

            var vocabularies = txtVocab.Text.Split(new string[] { Environment.NewLine }, StringSplitOptions.None);
            List<Vocabulary> listVocabulary = new List<Vocabulary>();
            foreach (var vocab in vocabularies)
            {
                var vocabTemp = vocab.Split(':');
                if (vocabTemp.Length >= 2)
                {
                    var vocabulary = new Vocabulary();
                    vocabulary.Id = Guid.NewGuid();
                    vocabulary.BBCEpisodeId = episode.Id;
                    vocabulary.Vocab = vocabTemp[0].Trim();
                    vocabulary.Mean = vocabTemp[1].Trim();
                    listVocabulary.Add(vocabulary);
                }
            }

            episode.Vocabularies = listVocabulary;
            episode.Summary = txtSummary.Text;
            episode.Grammar = txtGrammar.Text;
            ApplyVoaLevelToEpisode(episode);

            var canonicalEpisodeId = episode.Id.ToString();
            var episodeIdForCacheKeys = canonicalEpisodeId;
            episode.GrammarVocabularyCacheKeys = BuildGrammarVocabularyCacheKeysCsv(episodeIdForCacheKeys);

            bool isSupportYear = ConfigModel.SelectedEpisodeType.EpisodeCategories
                .Where(x => x.IsSupportYear)
                .Select(x => x.Category)
                .Contains(cbCategory.Text);
            string categoryPath = firebaseCategoryPathRoot + (isSupportYear ? "/" + cbYear.Text : "");
            var layout = CurrentRtdbLayout();
            episode.RtdbPath = RtdbLayoutStrategy.BuildRtdbPathField(layout, categoryPath, txtNumber.Text);

            if (exportEpisodeDetail)
            {
                var fullPath = RtdbLayoutStrategy.BuildFullEpisodePath(layout, categoryPath, txtNumber.Text);
                await firebaseClient.Child(fullPath).PatchAsync(episode).ConfigureAwait(true);

                var listEpisode = BuildListEpisodePayload(episode);
                var listPath = RtdbLayoutStrategy.BuildListEpisodePath(layout, categoryPath, txtNumber.Text);
                await firebaseClient.Child(listPath).PatchAsync(listEpisode).ConfigureAwait(true);

                if (!string.IsNullOrEmpty(txtHomeNumber.Text))
                {
                    if (RtdbLayoutStrategy.TryGetHomeFullPath(layout, txtHomeNumber.Text, out var homeFullPath))
                        await firebaseClient.Child(homeFullPath).PatchAsync(episode).ConfigureAwait(true);

                    if (RtdbLayoutStrategy.TryGetHomeListPath(layout, txtHomeNumber.Text, out var homeListPath))
                        await firebaseClient.Child(homeListPath).PatchAsync(listEpisode).ConfigureAwait(true);
                }
            }

            if (exportEpisodeDetail && cbSendEpisodePush != null && cbSendEpisodePush.Checked)
            {
                try
                {
                    var fcmProfile = ResolveFcmProfileName();
                    var fcmPath = ResolveFcmServiceAccountPath();
                    if (!EpisodeFcmSender.TryConfigure(fcmProfile, fcmPath))
                    {
                        string hint;
                        if (IsBritishCloudService())
                            hint = "thêm FcmServiceAccountPathBritish trong service.config.";
                        else if (IsVoaCloudService())
                            hint = "thêm FcmServiceAccountPathVOA trong service.config.";
                        else
                            hint = "thêm FcmServiceAccountPath trong service.config "
                                   + "hoặc đặt biến môi trường GOOGLE_APPLICATION_CREDENTIALS.";
                        MessageBox.Show(
                            this,
                            "FCM chưa cấu hình cho " + fcmProfile.ToUpperInvariant() + ": " + hint,
                            "Push FCM",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Warning);
                    }
                    else
                    {
                        var messageId = await EpisodeFcmSender.SendNewEpisodeAsync(
                            fcmProfile,
                            episode,
                            txtNumber.Text).ConfigureAwait(true);
                        Debug.WriteLine("EpisodeFcmSender[" + fcmProfile + "]: sent message " + messageId);
                    }
                }
                catch (Exception ex)
                {
                    MessageBox.Show(
                        this,
                        "Upload RTDB thành công nhưng gửi FCM thất bại: " + ex.Message,
                        "Push FCM",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning);
                }
            }

            if (exportTranslation)
                await UploadTranslationsAiCachesAsync(canonicalEpisodeId).ConfigureAwait(true);
            if (exportGrammar)
                await UploadGrammarAiCachesAsync(canonicalEpisodeId).ConfigureAwait(true);
            if (exportVocabulary)
                await UploadVocabularyAiCachesAsync(canonicalEpisodeId).ConfigureAwait(true);
            if (exportQuestions)
                await UploadQuestionsAiCachesAsync(canonicalEpisodeId).ConfigureAwait(true);

            return true;
        }

        private void cbType_SelectedIndexChanged(object sender, EventArgs e)
        {
            var selectedEpisode = cbType.SelectedItem as EpisodeTypeModel;
            if (selectedEpisode == null)
                return;

            cbCategory.DataSource = selectedEpisode.EpisodeCategories;
            cbCategory.DisplayMember = "Category";
            cbCategory.ValueMember = "Category";
            ConfigModel.SelectedEpisodeType = selectedEpisode;
        }

        private void cbCloudService_SelectedIndexChanged(object sender, EventArgs e)
        {
            var selected = cbCloudService.SelectedItem as CloudService;
            if (selected == null)
                return;

            txtUrl.Text = selected.Url;
            txtApiKey.Text = selected.ApiKey;
            txtSecret.Text = selected.Secret;
            ConfigModel.SelectedCloudService = selected;
            ActiveRtdbContext.Set(txtUrl.Text, txtSecret.Text);
            ApplyEpisodeTypeFilterForCloudService();
            UpdateCbLevelEnabled();
            UpdateSendEpisodePushLabel();
            cbType.Focus();
        }

        private void btnGetLink_Click(object sender, EventArgs e)
        {
            FileStream stream = new FileStream(txtFilePath.Text, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);

            var fileName = Path.GetFileName(txtFilePath.Text);
            var subNode = (txtASSeriesChild?.Text ?? string.Empty).Trim().Trim('/');
            if (!string.IsNullOrWhiteSpace(subNode))
                fileName = subNode + "/" + fileName;

            var url = upload(fileName, stream);
        }

        private void btnImageLink_Click(object sender, EventArgs e)
        {
            using (OpenFileDialog openFileDialog = new OpenFileDialog())
            {
                if (openFileDialog.ShowDialog() == DialogResult.OK)
                {
                    FileStream stream = new FileStream(openFileDialog.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);

                    var fileName = Path.GetFileName(openFileDialog.FileName);
                    var subNode = (txtASSeriesChild?.Text ?? string.Empty).Trim().Trim('/');
                    if (!string.IsNullOrWhiteSpace(subNode))
                        fileName = subNode + "/" + fileName;

                    var url = uploadThumb(fileName, stream);
                }
            }
        }
        private async Task uploadThumb(string fileName, FileStream fileStream)
        {
            var task = await new FirebaseStorage(ConfigModel.SelectedCloudService.Storage, new FirebaseStorageOptions
            {
                AuthTokenAsyncFactory = () => Task.FromResult(txtSecret.Text),

            })
                .Child(cbCategory.Text + (ConfigModel.SelectedEpisodeType.EpisodeCategories.Where(x => x.IsSupportYear).Select(x => x.Category).Contains(cbCategory.Text) ? "/" + cbYear.Text : "") + "/" + fileName)
                .PutAsync(fileStream);

            try
            {
                // error during upload will be thrown when you await the task
                txtThumb.Text = task;
            }
            catch (Exception ex)
            {
                Console.WriteLine("Exception was thrown: {0}", ex);
            }
        }

        private async void btnSubmitAndAddNew_Click(object sender, EventArgs e)
        {
            try
            {
                if (!await OnSubmitAsync().ConfigureAwait(true))
                    return;
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Submit", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            txtFilePath.Text = "";
            txtLength.Text = "";
            txtPosition.Text = "";
            txtNextPosition.Text = "";
            txtTranscript.Text = "";
            txtResult.Text = "";
            txtGroupResult.Text = "";
            grvRow.DataSource = null;
            UpdateTranscriptGridRowCountLabel(grvRow);
            txtId.Text = Guid.NewGuid().ToString();
            txtEpisodeName.Text = "";
            txtThumb.Text = "";
            txtFileUrl.Text = "";
            txtDuration.Value = 0;
            txtVocab.Text = "";
            txtSummary.Text = "";
            txtGrammar.Text = "";
            grvVocabEn.DataSource = null;
            grvVocabVi.DataSource = null;
            grvVocabEs.DataSource = null;
            grvVocabAr.DataSource = null;
            grvVocabJa.DataSource = null;
            grvVocabKo.DataSource = null;
            grvVocabPt.DataSource = null;
            grvVocabRu.DataSource = null;
            grvVocabZh.DataSource = null;
            grvVocabFr.DataSource = null;
            grvVocabDe.DataSource = null;

            int nextNumber = int.Parse(txtNumber.Text) + 1;

            txtNumber.Text = nextNumber + "";

            var resultString = Regex.Match(txtHomeNumber.Text, @"\d+").Value;

            int nextHomeNumber = int.Parse(resultString) + 1;

            txtHomeNumber.Text = cbCategory.Text + "/" + nextHomeNumber;

        }

        private void btnExportJson_Click(object sender, EventArgs e)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(txtResult.Text))
                {
                    MessageBox.Show(
                        this,
                        "Result (Transcript HTML) is required before export.",
                        "Export JSON",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning);
                    txtResult.Focus();
                    return;
                }

                var root = BuildFullEpisodeExportJson();
                var episodeId = root["episode"]?["Id"]?.ToString() ?? "episode";
                var number = (txtNumber.Text ?? "").Trim();
                var defaultName = string.IsNullOrEmpty(number)
                    ? ("episode_" + episodeId + ".json")
                    : ("episode_" + number + "_" + episodeId + ".json");

                using (var dlg = new SaveFileDialog())
                {
                    dlg.Title = "Export episode JSON";
                    dlg.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*";
                    dlg.FileName = defaultName;
                    dlg.DefaultExt = "json";
                    dlg.AddExtension = true;
                    if (dlg.ShowDialog(this) != DialogResult.OK)
                        return;

                    File.WriteAllText(dlg.FileName, root.ToString(Newtonsoft.Json.Formatting.Indented), Encoding.UTF8);
                    MessageBox.Show(
                        this,
                        "Đã export JSON:\n" + dlg.FileName,
                        "Export JSON",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Export JSON", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        /// <summary>
        /// Build one JSON document mirroring what Submit would push (episode + list + optional home + ai_cache payloads).
        /// Does not write to RTDB.
        /// </summary>
        private JObject BuildFullEpisodeExportJson()
        {
            var episode = BuildEpisodeFromForm();
            txtId.Text = episode.Id.ToString();

            ResolveCategoryForEpisodeAndFirebasePaths(out _, out var firebaseCategoryPathRoot);
            bool isSupportYear = ConfigModel.SelectedEpisodeType.EpisodeCategories
                .Where(x => x.IsSupportYear)
                .Select(x => x.Category)
                .Contains(cbCategory.Text);
            string categoryPath = firebaseCategoryPathRoot + (isSupportYear ? "/" + cbYear.Text : "");
            var canonicalEpisodeId = episode.Id.ToString();
            episode.GrammarVocabularyCacheKeys = BuildGrammarVocabularyCacheKeysCsv(canonicalEpisodeId);

            var layout = CurrentRtdbLayout();
            episode.RtdbPath = RtdbLayoutStrategy.BuildRtdbPathField(layout, categoryPath, txtNumber.Text);

            var listEpisode = new JObject
            {
                ["Category"] = episode.Category,
                ["EpisodeName"] = episode.EpisodeName,
                ["FileUrl"] = episode.FileUrl,
                ["Id"] = episode.Id,
                ["IsNew"] = episode.IsNew,
                ["PublishedDate"] = episode.PublishedDate,
                ["GrammarVocabularyCacheKeys"] = episode.GrammarVocabularyCacheKeys,
                ["Summary"] = episode.Summary,
                ["ThumbImage"] = episode.ThumbImage,
                ["Year"] = episode.Year,
                ["RtdbPath"] = episode.RtdbPath,
            };
            if (!string.IsNullOrEmpty(episode.Level))
                listEpisode["Level"] = episode.Level;

            var root = new JObject
            {
                ["exportedAt"] = DateTime.UtcNow.ToString("o"),
                ["schemaVersion"] = 1,
                ["episodeNumber"] = txtNumber.Text,
                ["homeNumber"] = txtHomeNumber.Text,
                ["categoryPath"] = categoryPath,
                ["rtdbPath"] = episode.RtdbPath,
                ["listPath"] = RtdbLayoutStrategy.BuildListEpisodePath(layout, categoryPath, txtNumber.Text),
                ["episode"] = JObject.FromObject(episode),
                ["listEpisode"] = listEpisode,
            };

            if (!string.IsNullOrEmpty(txtHomeNumber.Text))
            {
                if (RtdbLayoutStrategy.TryGetHomeFullPath(layout, txtHomeNumber.Text, out var homeFullPath))
                {
                    if (layout == RtdbLayoutKind.VoaLegacy)
                        root["newHomePagePath"] = homeFullPath;
                    else
                        root["homePagePath"] = homeFullPath;
                }

                if (RtdbLayoutStrategy.TryGetHomeListPath(layout, txtHomeNumber.Text, out var homeListPath))
                    root["listHomePagePath"] = homeListPath;
            }

            root["ai_cache"] = BuildAiCacheExportPayload(canonicalEpisodeId);
            return root;
        }

        private Episode BuildEpisodeFromForm()
        {
            var episode = new Episode();
            if (!string.IsNullOrEmpty(txtId.Text))
            {
                Guid id = Guid.Empty;
                Guid.TryParse(txtId.Text, out id);
                episode.Id = id == Guid.Empty ? Guid.NewGuid() : id;
            }
            else
            {
                episode.Id = Guid.NewGuid();
            }

            ResolveCategoryForEpisodeAndFirebasePaths(out var episodeCategory, out _);
            episode.Category = episodeCategory;
            episode.Year = cbYear.Text;
            episode.PublishedDate = dpPublishDate.Value;
            episode.ThumbImage = txtThumb.Text;
            episode.EpisodeName = txtEpisodeName.Text;
            episode.FileUrl = txtFileUrl.Text;
            episode.Transcript = txtTranscript.Text;
            episode.TranscriptHtml = txtResult.Text;
            episode.Vocabulary = txtVocab.Text;
            if (int.TryParse(txtDuration.Text, out var duration))
                episode.Duration = duration;

            var vocabularies = txtVocab.Text.Split(new string[] { Environment.NewLine }, StringSplitOptions.None);
            var listVocabulary = new List<Vocabulary>();
            foreach (var vocab in vocabularies)
            {
                var vocabTemp = vocab.Split(':');
                if (vocabTemp.Length >= 2)
                {
                    var vocabulary = new Vocabulary();
                    vocabulary.Id = Guid.NewGuid();
                    vocabulary.BBCEpisodeId = episode.Id;
                    vocabulary.Vocab = vocabTemp[0].Trim();
                    vocabulary.Mean = vocabTemp[1].Trim();
                    listVocabulary.Add(vocabulary);
                }
            }

            episode.Vocabularies = listVocabulary;
            episode.Summary = txtSummary.Text;
            episode.Grammar = txtGrammar.Text;
            ApplyVoaLevelToEpisode(episode);
            return episode;
        }

        private JObject BuildAiCacheExportPayload(string episodeId)
        {
            var ai = new JObject();

            var translations = CollectTranslationsExport(episodeId);
            if (translations.Count > 0)
                ai["translations"] = translations;

            var grammar = CollectGrammarExport(episodeId);
            if (grammar["grammar_by_episode"] is JArray gArr && gArr.Count > 0)
                ai["grammar_by_episode"] = gArr;

            var vocabulary = CollectVocabularyExport(episodeId);
            if (vocabulary.Count > 0)
                ai["vocabulary"] = vocabulary;

            var questions = CollectQuestionsExport(episodeId);
            if (questions != null)
                ai["questions"] = questions;

            return ai;
        }

        private JObject CollectTranslationsExport(string episodeId)
        {
            var byLang = new JObject();
            if (!(grvRow.DataSource is BindingList<EpisodeRowModel> enRows) || enRows.Count == 0)
                return byLang;

            var localeSpecs = new[]
            {
                Tuple.Create(grvViRow, "vi"),
                Tuple.Create(grvEsRow, "es"),
                Tuple.Create(grvArRow, "ar"),
                Tuple.Create(grvJaRow, "ja"),
                Tuple.Create(grvKoRow, "ko"),
                Tuple.Create(grvPtRow, "pt"),
                Tuple.Create(grvRuRow, "ru"),
                Tuple.Create(grvZhRow, "zh"),
                Tuple.Create(grvFrRow, "fr"),
                Tuple.Create(grvDeRow, "de"),
            };

            foreach (var spec in localeSpecs)
            {
                var grid = spec.Item1;
                var langCode = spec.Item2;
                if (!(grid.DataSource is BindingList<EpisodeRowModel> locRows) || locRows.Count == 0)
                    continue;

                var n = Math.Min(enRows.Count, locRows.Count);
                var arr = new JArray();
                for (var i = 0; i < n; i++)
                {
                    var original = (enRows[i].RowContent ?? string.Empty).Trim();
                    var translated = (locRows[i].RowContent ?? string.Empty).Trim();
                    if (original.Length == 0 || translated.Length == 0)
                        continue;

                    arr.Add(new JObject
                    {
                        ["original"] = original,
                        ["translated"] = translated,
                        ["lineNumber"] = i,
                    });
                }

                if (arr.Count == 0)
                    continue;

                byLang[langCode] = new JObject
                {
                    ["path"] = "ai_cache/translations/" + episodeId + "/" + langCode,
                    ["data"] = new JObject { ["translations"] = arr },
                };
            }

            return byLang;
        }

        private JObject CollectGrammarExport(string episodeId)
        {
            var result = new JObject
            {
                ["grammar_by_episode"] = new JArray(),
            };
            var englishRows = grvRow.DataSource as BindingList<EpisodeRowModel>;
            if (englishRows == null || englishRows.Count == 0)
                return result;

            var locales = new[]
            {
                Tuple.Create(grvRow, "en"),
                Tuple.Create(grvViRow, "vi"),
                Tuple.Create(grvEsRow, "es"),
                Tuple.Create(grvArRow, "ar"),
                Tuple.Create(grvJaRow, "ja"),
                Tuple.Create(grvKoRow, "ko"),
                Tuple.Create(grvPtRow, "pt"),
                Tuple.Create(grvRuRow, "ru"),
                Tuple.Create(grvZhRow, "zh"),
                Tuple.Create(grvFrRow, "fr"),
                Tuple.Create(grvDeRow, "de"),
            };

            var byEpisodeArr = (JArray)result["grammar_by_episode"];

            foreach (var loc in locales)
            {
                var grid = loc.Item1;
                var langCode = loc.Item2;
                if (GetEpisodeRowCount(grid) == 0)
                    continue;
                if (!(grid.DataSource is BindingList<EpisodeRowModel> rows))
                    continue;

                int n = Math.Min(englishRows.Count, rows.Count);
                for (int i = 0; i < n; i++)
                {
                    var json = rows[i].GrammarExplanationJson;
                    if (string.IsNullOrWhiteSpace(json))
                        continue;

                    JObject data;
                    try
                    {
                        data = JObject.Parse(json);
                    }
                    catch
                    {
                        continue;
                    }

                    var sentence = (englishRows[i].RowContent ?? string.Empty).Trim();
                    if (string.IsNullOrEmpty(sentence))
                        continue;

                    // Sentence-only or passage dual-map — same export path as RTDB upload.
                    byEpisodeArr.Add(new JObject
                    {
                        ["lang"] = langCode,
                        ["lineNumber"] = i,
                        ["lineKey"] = "line_" + i,
                        ["sentence"] = sentence,
                        ["pathHint"] = "ai_cache/grammar_by_episode/" + episodeId + "/line_" + i + "/" + langCode,
                        ["data"] = data,
                    });
                }
            }

            return result;
        }

        private JArray CollectVocabularyExport(string episodeId)
        {
            var arr = new JArray();
            if (!(grvVocabEn.DataSource is BindingList<VocabularyGridRowModel> enRows) || enRows.Count == 0)
                return arr;

            var localeSpecs = new[]
            {
                Tuple.Create(grvVocabEn, "en"),
                Tuple.Create(grvVocabVi, "vi"),
                Tuple.Create(grvVocabEs, "es"),
                Tuple.Create(grvVocabAr, "ar"),
                Tuple.Create(grvVocabJa, "ja"),
                Tuple.Create(grvVocabKo, "ko"),
                Tuple.Create(grvVocabPt, "pt"),
                Tuple.Create(grvVocabRu, "ru"),
                Tuple.Create(grvVocabZh, "zh"),
                Tuple.Create(grvVocabFr, "fr"),
                Tuple.Create(grvVocabDe, "de"),
            };

            foreach (var spec in localeSpecs)
            {
                var grid = spec.Item1;
                var langCode = spec.Item2;
                BindingList<VocabularyGridRowModel> locRows;
                if (string.Equals(langCode, "en", StringComparison.OrdinalIgnoreCase))
                    locRows = enRows;
                else if (!(grid.DataSource is BindingList<VocabularyGridRowModel> lr) || lr.Count != enRows.Count)
                    continue;
                else
                    locRows = lr;

                for (var i = 0; i < enRows.Count; i++)
                {
                    var lemma = (enRows[i].EnglishLemma ?? string.Empty).Trim();
                    if (lemma.Length == 0)
                        continue;

                    var enhancementJson = string.Equals(langCode, "en", StringComparison.OrdinalIgnoreCase)
                        ? enRows[i].EnhancementJson
                        : (i < locRows.Count ? locRows[i].EnhancementJson : null) ?? enRows[i].EnhancementJson;

                    var meaning = string.Equals(langCode, "en", StringComparison.OrdinalIgnoreCase)
                        ? enRows[i].Meaning ?? string.Empty
                        : (i < locRows.Count ? locRows[i].Meaning : null) ?? string.Empty;

                    JObject enhancementObj = null;
                    if (!string.IsNullOrWhiteSpace(enhancementJson))
                    {
                        try
                        {
                            enhancementObj = JToken.Parse(enhancementJson) as JObject;
                        }
                        catch
                        {
                            enhancementObj = null;
                        }
                    }

                    var payload = enhancementObj != null ? (JObject)enhancementObj.DeepClone() : new JObject();
                    payload["meaning"] = meaning ?? string.Empty;

                    if (payload.Properties().All(p => p.Name == "meaning" && string.IsNullOrWhiteSpace(meaning)))
                        continue;

                    var wordHash = GrammarCacheKeyHelper.HashString(lemma.ToLowerInvariant());
                    arr.Add(new JObject
                    {
                        ["word"] = lemma,
                        ["wordHash"] = wordHash,
                        ["lang"] = langCode,
                        ["episodeId"] = episodeId,
                        ["pathHint"] = "ai_cache/vocabulary/" + wordHash + "/" + langCode,
                        ["data"] = payload,
                    });
                }
            }

            return arr;
        }

        private JObject CollectQuestionsExport(string episodeId)
        {
            if (!(grvQuestions.DataSource is BindingList<QuestionGridRowModel> rows) || rows.Count == 0)
                return null;

            var count = rows.Count;
            var arr = new JArray();
            for (var i = 0; i < rows.Count; i++)
                arr.Add(rows[i].ToFlutterQuestionObject(i));

            return new JObject
            {
                ["path"] = "ai_cache/questions/" + episodeId + "/" + count,
                ["count"] = count,
                ["data"] = new JObject
                {
                    ["questions"] = arr,
                    ["count"] = count,
                },
            };
        }

        private void btnConfig_Click(object sender, EventArgs e)
        {

        }

        private void btnPurgeAiCache_Click(object sender, EventArgs e)
        {
            var secret = (txtSecret.Text ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(secret))
            {
                MessageBox.Show(this,
                    "Nhập Firebase secret vào txtSecret trước khi purge cache.",
                    "Purge expired AI cache",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                txtSecret.Focus();
                return;
            }

            using (var dlg = new FrmAiCacheCleanup(secret))
            {
                dlg.ShowDialog(this);
            }
        }

        private void btnMigrateRtdbPath_Click(object sender, EventArgs e)
        {
            var secret = (txtSecret.Text ?? string.Empty).Trim();
            var url = (txtUrl.Text ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(secret))
            {
                MessageBox.Show(this,
                    "Nhập Firebase secret vào txtSecret trước khi migrate.",
                    "Migrate RtdbPath",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                txtSecret.Focus();
                return;
            }
            if (string.IsNullOrEmpty(url))
            {
                MessageBox.Show(this,
                    "Nhập Firebase URL vào txtUrl trước khi migrate.",
                    "Migrate RtdbPath",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                txtUrl.Focus();
                return;
            }

            using (var dlg = new FrmRtdbPathMigrate(url, secret, CurrentRtdbLayout()))
            {
                dlg.ShowDialog(this);
            }
        }

        private static BindingList<EpisodeRowModel> GetEpisodeRowsOrThrow(DataGridView grid)
        {
            if (grid.DataSource is BindingList<EpisodeRowModel> bl)
                return bl;
            throw new InvalidOperationException("Grid " + grid.Name + " must be bound to BindingList<EpisodeRowModel>. Leave transcript field to refresh.");
        }

        private static int GetEpisodeRowCount(DataGridView grid)
        {
            if (grid.DataSource is BindingList<EpisodeRowModel> bl)
                return bl.Count;
            return 0;
        }

        private bool ValidateGrammarGridRowCounts()
        {
            int n = GetEpisodeRowCount(grvRow);
            if (n == 0)
            {
                MessageBox.Show(this, "Chưa có dòng trên lưới En (txtTranscript → grvRow).", "Grammar", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return false;
            }

            // Tab locale không có transcript (0 dòng) sẽ được bỏ qua khi fill grammar.
            var grids = new[] { grvViRow, grvEsRow, grvArRow, grvJaRow, grvKoRow, grvPtRow, grvRuRow, grvZhRow, grvFrRow, grvDeRow };
            foreach (var g in grids)
            {
                int c = GetEpisodeRowCount(g);
                if (c > 0 && c != n)
                {
                    MessageBox.Show(this,
                        "Số dòng không khớp: grvRow có " + n + " nhưng " + g.Name + " có " + c + ". Đồng bộ transcript hoặc xóa transcript tab đó (0 dòng = bỏ qua ngôn ngữ).",
                        "Grammar", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return false;
                }
            }

            return true;
        }

        private static string GrammarTargetLanguageLabel(string langCode)
        {
            switch ((langCode ?? "").ToLowerInvariant())
            {
                case "vi": return "Vietnamese";
                case "zh": return "Chinese";
                case "ja": return "Japanese";
                case "ko": return "Korean";
                case "es": return "Spanish";
                case "pt": return "Portuguese";
                case "ar": return "Arabic";
                case "ru": return "Russian";
                case "fr": return "French";
                case "de": return "German";
                case "en": return "English";
                default: return "English";
            }
        }

        private static string BuildGrammarSummary(JObject grammar)
        {
            var gp = grammar["grammarPoint"]?.ToString() ?? "";
            var ex = grammar["explanation"]?.ToString() ?? "";
            var oneLine = (gp + " — " + ex).Replace("\r\n", " ").Replace("\n", " ");
            if (string.IsNullOrWhiteSpace(gp) && string.IsNullOrWhiteSpace(ex))
                oneLine = (grammar["rulePattern"]?.ToString() ?? "").Replace("\r\n", " ").Replace("\n", " ");
            if (string.IsNullOrWhiteSpace(oneLine))
                oneLine = "(Đã nhận phản hồi grammar)";
            if (oneLine.Length > 200)
                oneLine = oneLine.Substring(0, 197) + "...";
            return oneLine;
        }

        private static string TruncateGrammarCellError(string message, int maxLen)
        {
            if (string.IsNullOrEmpty(message))
                return "Lỗi (không có chi tiết).";
            var t = message.Replace("\r\n", " ").Replace("\n", " ").Trim();
            if (t.Length <= maxLen)
                return "Lỗi: " + t;
            return "Lỗi: " + t.Substring(0, maxLen - 3) + "...";
        }

        private void SetGrammarJobUiBusy(bool busy, string statusLine = null)
        {
            if (InvokeRequired)
            {
                BeginInvoke(new Action(() => SetGrammarJobUiBusy(busy, statusLine)));
                return;
            }

            UseWaitCursor = busy;
            Cursor = busy ? Cursors.WaitCursor : Cursors.Default;
            if (busy)
            {
                toolStripProgressGrammar.Visible = true;
                toolStripProgressGrammar.Style = ProgressBarStyle.Marquee;
                toolStripProgressGrammar.MarqueeAnimationSpeed = 40;
                toolStripStatusLabelGrammar.Text = string.IsNullOrWhiteSpace(statusLine)
                    ? "Đang chạy grammar (Gemini)…"
                    : statusLine;
            }
            else
            {
                toolStripProgressGrammar.Visible = false;
                toolStripProgressGrammar.Style = ProgressBarStyle.Blocks;
                toolStripStatusLabelGrammar.Text = "Sẵn sàng.";
            }
        }

        private void SetGrammarJobUiDetail(string detail)
        {
            if (InvokeRequired)
            {
                BeginInvoke(new Action(() => SetGrammarJobUiDetail(detail)));
                return;
            }

            toolStripStatusLabelGrammar.Text = "Đang chạy grammar — " + (detail ?? string.Empty);
        }

        private static void ApplyVocabGridStyle(DataGridView grid)
        {
            grid.AutoGenerateColumns = false;
            grid.RowTemplate.Height = 36;
            grid.DefaultCellStyle.WrapMode = DataGridViewTriState.True;
            grid.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.AllCellsExceptHeaders;
        }

        private static List<Tuple<string, string>> ParseVocabSourceLines(string text)
        {
            var lines = (text ?? "").Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
            var r = new List<Tuple<string, string>>();
            foreach (var line in lines)
            {
                var t = line.Trim();
                if (t.Length == 0)
                    continue;
                var idx = t.IndexOf(':');
                if (idx <= 0)
                {
                    r.Add(Tuple.Create(t, ""));
                    continue;
                }

                var word = t.Substring(0, idx).Trim();
                var mean = t.Substring(idx + 1).Trim();
                r.Add(Tuple.Create(word, mean));
            }

            return r;
        }

        private void txtVocab_Leave(object sender, EventArgs e)
        {
            FillVocabGridsFromTxtVocab();
        }

        private void FillVocabGridsFromTxtVocab()
        {
            var pairs = ParseVocabSourceLines(txtVocab.Text);
            var prevEn = grvVocabEn.DataSource as BindingList<VocabularyGridRowModel>;
            var localeGrids = new[]
            {
                grvVocabVi, grvVocabEs, grvVocabAr, grvVocabJa, grvVocabKo, grvVocabPt, grvVocabRu, grvVocabZh, grvVocabFr, grvVocabDe
            };
            var prevLocales = new BindingList<VocabularyGridRowModel>[localeGrids.Length];
            for (var g = 0; g < localeGrids.Length; g++)
                prevLocales[g] = localeGrids[g].DataSource as BindingList<VocabularyGridRowModel>;

            var enList = new BindingList<VocabularyGridRowModel>();
            for (var i = 0; i < pairs.Count; i++)
            {
                var word = pairs[i].Item1;
                var mean = pairs[i].Item2;
                var row = new VocabularyGridRowModel { EnglishLemma = word, DisplayText = word, Meaning = mean };
                if (prevEn != null && i < prevEn.Count
                    && string.Equals(prevEn[i].EnglishLemma, word, StringComparison.Ordinal))
                {
                    row.EnhancementJson = prevEn[i].EnhancementJson;
                }

                enList.Add(row);
            }

            grvVocabEn.DataSource = enList;

            for (var g = 0; g < localeGrids.Length; g++)
            {
                var prev = prevLocales[g];
                var list = new BindingList<VocabularyGridRowModel>();
                for (var i = 0; i < pairs.Count; i++)
                {
                    var word = pairs[i].Item1;
                    var row = new VocabularyGridRowModel { EnglishLemma = word, DisplayText = word };
                    if (prev != null && i < prev.Count
                        && string.Equals(prev[i].EnglishLemma, word, StringComparison.Ordinal))
                    {
                        row.DisplayText = prev[i].DisplayText;
                        row.Meaning = prev[i].Meaning;
                        row.EnhancementJson = prev[i].EnhancementJson;
                    }

                    list.Add(row);
                }

                localeGrids[g].DataSource = list;
            }

            grvVocabEn.Refresh();
            foreach (var grid in localeGrids)
                grid.Refresh();
        }

        private async void btnGetVocabFromTranscript_Click(object sender, EventArgs e)
        {
            var transcript = (txtTranscript.Text ?? "").Trim();
            if (transcript.Length == 0)
            {
                MessageBox.Show(this,
                    "Chưa có transcript tiếng Anh (txtTranscript).",
                    "Vocabulary",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            var apiKeys = TryResolveGeminiApiKeys();
            if (apiKeys == null || apiKeys.Count == 0)
            {
                MessageBox.Show(this,
                    "Thiếu Gemini API key: đặt GEMINI_API_KEY / GOOGLE_API_KEY hoặc <GeminiApiKey> trong service.config.",
                    "Vocabulary",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            var count = GrammarCacheConstants.DefaultVocabularySuggestionCount;
            var btnText = btnGetVocabFromTranscript.Text;
            var formTitleOriginal = Text;
            btnGetVocabFromTranscript.Enabled = false;
            var ok = false;
            var filled = 0;
            try
            {
                SetGrammarJobUiBusy(true, "Đang lấy vocabulary từ transcript (Gemini)…");
                Text = formTitleOriginal + " — Vocab from transcript…";
                SetGrammarJobUiDetail("Extract vocab × " + count);

                var pairs = await VocabularyGeminiService.ExtractVocabularyFromTranscriptAsync(apiKeys, transcript, count)
                    .ConfigureAwait(true);

                var sb = new StringBuilder();
                foreach (var p in pairs)
                {
                    var word = (p.Item1 ?? "").Trim();
                    if (word.Length == 0)
                        continue;
                    var meaning = (p.Item2 ?? "").Trim();
                    if (sb.Length > 0)
                        sb.AppendLine();
                    sb.Append(word);
                    sb.Append(" : ");
                    sb.Append(meaning);
                    filled++;
                }

                if (filled == 0)
                {
                    MessageBox.Show(this, "Không parse được vocabulary từ Gemini.", "Vocabulary",
                        MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }

                txtVocab.Text = sb.ToString();
                FillVocabGridsFromTxtVocab();
                ok = true;
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Vocabulary", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                Text = formTitleOriginal;
                SetGrammarJobUiBusy(false);
                btnGetVocabFromTranscript.Text = btnText;
                btnGetVocabFromTranscript.Enabled = true;
            }

            if (ok)
            {
                MessageBox.Show(this, "Đã điền " + filled + " từ/cụm vào txtVocab (word : meaning).", "Vocabulary",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private async void btnGetVocabTransLateAndObject_Click(object sender, EventArgs e)
        {
            var apiKeys = TryResolveGeminiApiKeys();
            if (apiKeys == null || apiKeys.Count == 0)
            {
                MessageBox.Show(this,
                    "Thiếu Gemini API key: đặt GEMINI_API_KEY / GOOGLE_API_KEY hoặc <GeminiApiKey> trong service.config.",
                    "Vocabulary", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (!(grvVocabEn.DataSource is BindingList<VocabularyGridRowModel> enRows) || enRows.Count == 0)
            {
                MessageBox.Show(this, "Chưa có dòng vocabulary trên lưới En (txtVocab → Leave để đổ lưới).", "Vocabulary",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var localeSpecs = new[]
            {
                Tuple.Create(grvVocabVi, "vi"),
                Tuple.Create(grvVocabEs, "es"),
                Tuple.Create(grvVocabAr, "ar"),
                Tuple.Create(grvVocabJa, "ja"),
                Tuple.Create(grvVocabKo, "ko"),
                Tuple.Create(grvVocabPt, "pt"),
                Tuple.Create(grvVocabRu, "ru"),
                Tuple.Create(grvVocabZh, "zh"),
                Tuple.Create(grvVocabFr, "fr"),
                Tuple.Create(grvVocabDe, "de"),
            };

            foreach (var loc in localeSpecs)
            {
                var grid = loc.Item1;
                var nLoc = grid.DataSource is BindingList<VocabularyGridRowModel> lr ? lr.Count : 0;
                if (nLoc > 0 && nLoc != enRows.Count)
                {
                    MessageBox.Show(this,
                        "Số dòng vocab không khớp: En có " + enRows.Count + " nhưng " + grid.Name + " có " + nLoc + ".",
                        "Vocabulary", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
            }

            int delayMs = Math.Max(250, ConfigModel.GeminiRequestDelayMs);
            var vocabBtnText = btnGetVocabTransLateAndObject.Text;
            var formTitleOriginal = Text;
            btnGetVocabTransLateAndObject.Enabled = false;
            var ok = false;
            try
            {
                SetGrammarJobUiBusy(true, "Đang chạy vocabulary (Gemini)…");
                Text = formTitleOriginal + " — Vocabulary đang chạy…";

                for (var i = 0; i < enRows.Count; i++)
                {
                    var enRow = enRows[i];
                    var lemma = (enRow.EnglishLemma ?? "").Trim();
                    if (lemma.Length == 0)
                        continue;

                    var detailEn = "Vocab EN object " + (i + 1) + "/" + enRows.Count;
                    btnGetVocabTransLateAndObject.Text = detailEn;
                    SetGrammarJobUiDetail(detailEn);

                    try
                    {
                        var raw = await VocabularyGeminiService.EnhanceVocabularyJsonAsync(apiKeys, lemma, enRow.Meaning ?? "")
                            .ConfigureAwait(true);
                        var jo = JObject.Parse(raw);
                        enRow.EnhancementJson = jo.ToString(Newtonsoft.Json.Formatting.None);
                    }
                    catch (Exception ex)
                    {
                        enRow.EnhancementJson = TruncateGrammarCellError(ex.Message, 480);
                    }

                    var enhCompact = (enRow.EnhancementJson ?? "").Trim();
                    foreach (var loc in localeSpecs)
                    {
                        if (!(loc.Item1.DataSource is BindingList<VocabularyGridRowModel> lr))
                            continue;
                        if (lr.Count != enRows.Count || i >= lr.Count)
                            continue;
                        lr[i].EnhancementJson = enhCompact;
                    }

                    await Task.Delay(delayMs).ConfigureAwait(true);
                }

                grvVocabEn.Refresh();
                foreach (var loc in localeSpecs)
                {
                    loc.Item1.EndEdit();
                    loc.Item1.Refresh();
                }

                for (var li = 0; li < localeSpecs.Length; li++)
                {
                    var grid = localeSpecs[li].Item1;
                    var langCode = localeSpecs[li].Item2;
                    if (!(grid.DataSource is BindingList<VocabularyGridRowModel> locRows) || locRows.Count != enRows.Count)
                        continue;

                    var label = GrammarTargetLanguageLabel(langCode);

                    var pairs = new List<Tuple<string, string>>();
                    for (var j = 0; j < enRows.Count; j++)
                    {
                        var lm = (enRows[j].EnglishLemma ?? "").Trim();
                        pairs.Add(Tuple.Create(lm, enRows[j].Meaning ?? ""));
                    }

                    var detailBatch = "Vocab batch meaning " + langCode + " (" + pairs.Count + ")";
                    btnGetVocabTransLateAndObject.Text = detailBatch;
                    SetGrammarJobUiDetail(detailBatch);

                    if (!pairs.Any(p => !string.IsNullOrWhiteSpace(p.Item2)))
                    {
                        for (var i = 0; i < enRows.Count; i++)
                        {
                            var lemma = (enRows[i].EnglishLemma ?? "").Trim();
                            locRows[i].DisplayText = lemma;
                            locRows[i].Meaning = "";
                        }

                        grid.EndEdit();
                        grid.Refresh();
                        await Task.Delay(delayMs).ConfigureAwait(true);
                        continue;
                    }

                    try
                    {
                        var dict = await VocabularyGeminiService.TranslateMeaningsBatchAsync(apiKeys, pairs, label)
                            .ConfigureAwait(true);
                        for (var i = 0; i < enRows.Count; i++)
                        {
                            var lemma = (enRows[i].EnglishLemma ?? "").Trim();
                            locRows[i].DisplayText = lemma;
                            locRows[i].Meaning = dict.TryGetValue(i + 1, out var m) ? m : "";
                        }
                    }
                    catch (Exception)
                    {
                        for (var i = 0; i < enRows.Count; i++)
                        {
                            var enRow = enRows[i];
                            var locRow = locRows[i];
                            var lemma = (enRow.EnglishLemma ?? "").Trim();
                            locRow.DisplayText = lemma;
                            try
                            {
                                var meaningEn = enRow.Meaning ?? "";
                                locRow.Meaning = string.IsNullOrWhiteSpace(meaningEn)
                                    ? ""
                                    : await VocabularyGeminiService.TranslateMeaningAsync(apiKeys, meaningEn, label)
                                        .ConfigureAwait(true);
                            }
                            catch (Exception ex2)
                            {
                                locRow.Meaning = TruncateGrammarCellError(ex2.Message, 240);
                            }

                            await Task.Delay(delayMs).ConfigureAwait(true);
                        }
                    }

                    grid.EndEdit();
                    grid.Refresh();
                    await Task.Delay(delayMs).ConfigureAwait(true);
                }

                ok = true;
            }
            finally
            {
                Text = formTitleOriginal;
                SetGrammarJobUiBusy(false);
                btnGetVocabTransLateAndObject.Text = vocabBtnText;
                btnGetVocabTransLateAndObject.Enabled = true;
            }

            if (ok)
            {
                MessageBox.Show(this, "Đã lấy vocab object (En) và dịch sang các tab Vi→Zh.", "Vocabulary",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private async void btnGetQuestions_Click(object sender, EventArgs e)
        {
            var transcript = (txtTranscript.Text ?? "").Trim();
            if (transcript.Length == 0)
            {
                MessageBox.Show(this,
                    "Chưa có transcript tiếng Anh (txtTranscript). Nhập hoặc đổ từ lưới transcript.",
                    "Questions",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            var apiKeys = TryResolveGeminiApiKeys();
            if (apiKeys == null || apiKeys.Count == 0)
            {
                MessageBox.Show(this,
                    "Thiếu Gemini API key: đặt GEMINI_API_KEY / GOOGLE_API_KEY hoặc <GeminiApiKey> trong service.config.",
                    "Questions",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            var count = GrammarCacheConstants.DefaultQuestionCount;
            var btnText = btnGetQuestions.Text;
            var formTitleOriginal = Text;
            btnGetQuestions.Enabled = false;
            try
            {
                SetGrammarJobUiBusy(true, "Đang sinh câu hỏi (Gemini)…");
                Text = formTitleOriginal + " — Questions…";
                SetGrammarJobUiDetail("Questions × " + count);

                var list = await QuestionsGeminiService.GenerateQuestionsAsync(apiKeys, transcript, count).ConfigureAwait(true);
                grvQuestions.DataSource = new BindingList<QuestionGridRowModel>(list);
                grvQuestions.Refresh();

                if (list.Count == 0)
                {
                    MessageBox.Show(this, "Không parse được câu hỏi từ Gemini.", "Questions",
                        MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Questions", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                Text = formTitleOriginal;
                SetGrammarJobUiBusy(false);
                btnGetQuestions.Text = btnText;
                btnGetQuestions.Enabled = true;
            }
        }

        private async void btngetGrammarExplaimation_Click(object sender, EventArgs e)
        {
            if (!ValidateGrammarGridRowCounts())
                return;

            var apiKeys = TryResolveGeminiApiKeys();
            if (apiKeys == null || apiKeys.Count == 0)
            {
                MessageBox.Show(this,
                    "Thiếu Gemini API key: đặt GEMINI_API_KEY / GOOGLE_API_KEY hoặc thẻ <GeminiApiKey> trong service.config (cùng thư mục với playMP3.exe). "
                    + "Có thể nhập nhiều key phân tách bằng dấu phẩy (,) — khi một key hết quota (429) sẽ thử key kế.",
                    "Grammar", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var episodeId = txtId.Text.Trim();
            if (string.IsNullOrEmpty(episodeId))
            {
                MessageBox.Show(this, "txtId (episode Id) trống.", "Grammar", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var englishRows = GetEpisodeRowsOrThrow(grvRow);
            int count = englishRows.Count;
            int delayBetweenRequestsMs = Math.Max(250, ConfigModel.GeminiRequestDelayMs);

            var locales = new[]
            {
                Tuple.Create(grvRow, "en"),
                Tuple.Create(grvViRow, "vi"),
                Tuple.Create(grvEsRow, "es"),
                Tuple.Create(grvArRow, "ar"),
                Tuple.Create(grvJaRow, "ja"),
                Tuple.Create(grvKoRow, "ko"),
                Tuple.Create(grvPtRow, "pt"),
                Tuple.Create(grvRuRow, "ru"),
                Tuple.Create(grvZhRow, "zh"),
                Tuple.Create(grvFrRow, "fr"),
                Tuple.Create(grvDeRow, "de"),
            };

            var grammarBtnOriginalText = btngetGrammarExplaimation.Text;
            var formTitleOriginal = Text;
            btngetGrammarExplaimation.Enabled = false;
            var grammarJobOk = false;
            try
            {
                SetGrammarJobUiBusy(true);
                Text = formTitleOriginal + " — Grammar đang chạy…";

                int activeLocales = 0;
                foreach (var loc in locales)
                {
                    if (GetEpisodeRowCount(loc.Item1) > 0)
                        activeLocales++;
                }

                int localeIndex = 0;
                foreach (var loc in locales)
                {
                    var grid = loc.Item1;
                    var langCode = loc.Item2;
                    var localeRows = GetEpisodeRowCount(grid);
                    if (localeRows == 0)
                        continue;

                    localeIndex++;
                    var targetLabel = GrammarTargetLanguageLabel(langCode);
                    var rows = GetEpisodeRowsOrThrow(grid);

                    for (int i = 0; i < count; i++)
                    {
                        var progressLine = "Grammar " + langCode + " " + (i + 1) + "/" + count
                            + " (tab " + localeIndex + "/" + Math.Max(1, activeLocales) + ")";
                        btngetGrammarExplaimation.Text = progressLine;
                        SetGrammarJobUiDetail(progressLine);
                        var sentence = (englishRows[i].RowContent ?? string.Empty).Trim();
                        if (string.IsNullOrEmpty(sentence))
                            continue;

                        try
                        {
                            var raw = await GrammarGeminiService.ExplainGrammarAsync(apiKeys, sentence, targetLabel).ConfigureAwait(true);
                            var merged = GrammarGeminiService.ToFlutterGrammarData(raw, sentence);
                            rows[i].GrammarExplanationJson = merged.ToString(Newtonsoft.Json.Formatting.None);
                            rows[i].GrammarExplanationSummary = BuildGrammarSummary(merged);
                        }
                        catch (Exception ex)
                        {
                            rows[i].GrammarExplanationSummary = TruncateGrammarCellError(ex.Message, 380);
                            rows[i].GrammarExplanationJson = "";
                        }

                        await Task.Delay(delayBetweenRequestsMs).ConfigureAwait(true);
                    }

                    grid.EndEdit();
                    grid.Refresh();
                }

                grammarJobOk = true;
            }
            finally
            {
                Text = formTitleOriginal;
                SetGrammarJobUiBusy(false);
                btngetGrammarExplaimation.Text = grammarBtnOriginalText;
                btngetGrammarExplaimation.Enabled = true;
            }

            if (grammarJobOk)
            {
                MessageBox.Show(this, "Đã điền grammar cho các tab đã có transcript (tab 0 dòng được bỏ qua).", "Grammar", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        /// <summary>
        /// Passage grammar fill: same sequential En-line × locale loop as sentence fill,
        /// but one Gemini call per cell returns overall + sentenceAnalyses (no progressive split).
        /// </summary>
        private async void btnGetGrammarPassage_Click(object sender, EventArgs e)
        {
            if (!ValidateGrammarGridRowCounts())
                return;

            var apiKeys = TryResolveGeminiApiKeys();
            if (apiKeys == null || apiKeys.Count == 0)
            {
                MessageBox.Show(this,
                    "Thiếu Gemini API key: đặt GEMINI_API_KEY / GOOGLE_API_KEY hoặc thẻ <GeminiApiKey> trong service.config (cùng thư mục với playMP3.exe). "
                    + "Có thể nhập nhiều key phân tách bằng dấu phẩy (,) — khi một key hết quota (429) sẽ thử key kế.",
                    "Grammar Passage", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var episodeId = txtId.Text.Trim();
            if (string.IsNullOrEmpty(episodeId))
            {
                MessageBox.Show(this, "txtId (episode Id) trống.", "Grammar Passage", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var englishRows = GetEpisodeRowsOrThrow(grvRow);
            int count = englishRows.Count;
            int delayBetweenRequestsMs = Math.Max(250, ConfigModel.GeminiRequestDelayMs);

            var locales = new[]
            {
                Tuple.Create(grvRow, "en"),
                Tuple.Create(grvViRow, "vi"),
                Tuple.Create(grvEsRow, "es"),
                Tuple.Create(grvArRow, "ar"),
                Tuple.Create(grvJaRow, "ja"),
                Tuple.Create(grvKoRow, "ko"),
                Tuple.Create(grvPtRow, "pt"),
                Tuple.Create(grvRuRow, "ru"),
                Tuple.Create(grvZhRow, "zh"),
                Tuple.Create(grvFrRow, "fr"),
                Tuple.Create(grvDeRow, "de"),
            };

            var grammarBtnOriginalText = btnGetGrammarPassage.Text;
            var sentenceBtnWasEnabled = btngetGrammarExplaimation.Enabled;
            var formTitleOriginal = Text;
            btnGetGrammarPassage.Enabled = false;
            btngetGrammarExplaimation.Enabled = false;
            var grammarJobOk = false;
            try
            {
                SetGrammarJobUiBusy(true, "Đang chạy grammar passage (Gemini, 1-shot)…");
                Text = formTitleOriginal + " — Grammar Passage đang chạy…";

                int activeLocales = 0;
                foreach (var loc in locales)
                {
                    if (GetEpisodeRowCount(loc.Item1) > 0)
                        activeLocales++;
                }

                int localeIndex = 0;
                foreach (var loc in locales)
                {
                    var grid = loc.Item1;
                    var langCode = loc.Item2;
                    var localeRows = GetEpisodeRowCount(grid);
                    if (localeRows == 0)
                        continue;

                    localeIndex++;
                    var targetLabel = GrammarTargetLanguageLabel(langCode);
                    var rows = GetEpisodeRowsOrThrow(grid);

                    for (int i = 0; i < count; i++)
                    {
                        var progressLine = "Passage " + langCode + " " + (i + 1) + "/" + count
                            + " (tab " + localeIndex + "/" + Math.Max(1, activeLocales) + ")";
                        btnGetGrammarPassage.Text = progressLine;
                        SetGrammarJobUiDetail(progressLine);
                        var sentence = (englishRows[i].RowContent ?? string.Empty).Trim();
                        if (string.IsNullOrEmpty(sentence))
                            continue;

                        try
                        {
                            var raw = await GrammarGeminiService.ExplainGrammarPassageAsync(apiKeys, sentence, targetLabel)
                                .ConfigureAwait(true);
                            var merged = GrammarGeminiService.ToFlutterGrammarPassageData(raw, sentence);
                            rows[i].GrammarExplanationJson = merged.ToString(Newtonsoft.Json.Formatting.None);
                            rows[i].GrammarExplanationSummary = BuildGrammarSummary(merged);
                        }
                        catch (Exception ex)
                        {
                            rows[i].GrammarExplanationSummary = TruncateGrammarCellError(ex.Message, 380);
                            rows[i].GrammarExplanationJson = "";
                        }

                        await Task.Delay(delayBetweenRequestsMs).ConfigureAwait(true);
                    }

                    grid.EndEdit();
                    grid.Refresh();
                }

                grammarJobOk = true;
            }
            finally
            {
                Text = formTitleOriginal;
                SetGrammarJobUiBusy(false);
                btnGetGrammarPassage.Text = grammarBtnOriginalText;
                btnGetGrammarPassage.Enabled = true;
                btngetGrammarExplaimation.Enabled = sentenceBtnWasEnabled;
            }

            if (grammarJobOk)
            {
                MessageBox.Show(this,
                    "Đã điền grammar passage (1 request/dòng) cho các tab có transcript. Export Grammar sẽ ghi dual payload vào ai_cache/grammar_by_episode (app cũ đọc sentence fields; app mới đọc overall/sentenceAnalyses).",
                    "Grammar Passage", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        /// <summary>
        /// CSV trên episode: <c>g:{grammarPathSegmentEn},v:{vocabularyWordHash}</c> — khớp RTDB
        /// <c>ai_cache/grammar/{g}/en.json</c> và <c>ai_cache/vocabulary/{v}/en.json</c>.
        /// </summary>
        private string BuildGrammarVocabularyCacheKeysCsv(string episodeIdStr)
        {
            var episodeId = episodeIdStr ?? "";
            var modelVersion = GrammarCacheConstants.GrammarModelVersion;
            var promptVersion = GrammarCacheConstants.GrammarPromptVersion;

            var grammarSegments = new HashSet<string>(StringComparer.Ordinal);
            var vocabHashes = new HashSet<string>(StringComparer.Ordinal);

            if (grvRow.DataSource is BindingList<EpisodeRowModel> enRows)
            {
                foreach (var row in enRows)
                {
                    var s = (row.RowContent ?? "").Trim();
                    if (s.Length == 0)
                        continue;
                    grammarSegments.Add(GrammarCacheKeyHelper.GrammarSentenceHashPathSegment(s, "en", episodeId, modelVersion, promptVersion));
                }
            }

            if (grvVocabEn.DataSource is BindingList<VocabularyGridRowModel> vocabRows)
            {
                foreach (var row in vocabRows)
                {
                    var w = (row.EnglishLemma ?? "").Trim();
                    if (w.Length == 0)
                        continue;
                    vocabHashes.Add(GrammarCacheKeyHelper.HashString(w.ToLowerInvariant()));
                }
            }

            var parts = new List<string>();
            foreach (var g in grammarSegments.OrderBy(x => x, StringComparer.Ordinal))
                parts.Add("g:" + g);
            foreach (var v in vocabHashes.OrderBy(x => x, StringComparer.Ordinal))
                parts.Add("v:" + v);

            return string.Join(",", parts);
        }

        /// <summary>
        /// Upload grammar_by_episode với <paramref name="lineNumber"/> 0-based (i trong vòng lặp = line_0 cho dòng đầu).
        /// RTDB cũ dùng line_1 cho dòng đầu cần re-upload hoặc chạy script migrate trước khi phát hành app mới.
        /// </summary>
        private async Task UploadGrammarAiCachesAsync(string episodeId)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                return;

            var englishRows = grvRow.DataSource as BindingList<EpisodeRowModel>;
            if (englishRows == null || englishRows.Count == 0)
                return;

            var locales = new[]
            {
                Tuple.Create(grvRow, "en"),
                Tuple.Create(grvViRow, "vi"),
                Tuple.Create(grvEsRow, "es"),
                Tuple.Create(grvArRow, "ar"),
                Tuple.Create(grvJaRow, "ja"),
                Tuple.Create(grvKoRow, "ko"),
                Tuple.Create(grvPtRow, "pt"),
                Tuple.Create(grvRuRow, "ru"),
                Tuple.Create(grvZhRow, "zh"),
                Tuple.Create(grvFrRow, "fr"),
                Tuple.Create(grvDeRow, "de"),
            };

            foreach (var loc in locales)
            {
                var grid = loc.Item1;
                var langCode = loc.Item2;
                if (GetEpisodeRowCount(grid) == 0)
                    continue;
                if (!(grid.DataSource is BindingList<EpisodeRowModel> rows))
                    continue;

                int n = Math.Min(englishRows.Count, rows.Count);
                for (int i = 0; i < n; i++)
                {
                    var json = rows[i].GrammarExplanationJson;
                    if (string.IsNullOrWhiteSpace(json))
                        continue;

                    JObject data;
                    try
                    {
                        data = JObject.Parse(json);
                    }
                    catch
                    {
                        continue;
                    }

                    var sentence = (englishRows[i].RowContent ?? string.Empty).Trim();
                    if (string.IsNullOrEmpty(sentence))
                        continue;

                    try
                    {
                        // Sentence schema or passage dual-map → same path (grammar + grammar_by_episode).
                        // Dual payload keeps grammarPoint/explanation for old apps + overall/sentenceAnalyses for new apps.
                        await GrammarFirebaseCacheWriter.PutGrammarCacheAsync(
                            sentence, langCode, episodeId, data, i).ConfigureAwait(true);
                    }
                    catch
                    {
                        // best-effort cache upload
                    }

                    await Task.Delay(50).ConfigureAwait(true);
                }
            }
        }

        /// <summary>
        /// Đẩy lên Firebase RTDB giống Flutter <c>AIFirebaseCacheService</c>: mỗi từ × mỗi mã ngôn ngữ.
        /// <c>data</c> = object enhancement (synonyms, …) + <c>meaning</c> gloss theo tab (En hoặc đã dịch).
        /// </summary>
        private async Task UploadVocabularyAiCachesAsync(string episodeId)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                return;

            if (!(grvVocabEn.DataSource is BindingList<VocabularyGridRowModel> enRows) || enRows.Count == 0)
                return;

            var localeSpecs = new[]
            {
                Tuple.Create(grvVocabEn, "en"),
                Tuple.Create(grvVocabVi, "vi"),
                Tuple.Create(grvVocabEs, "es"),
                Tuple.Create(grvVocabAr, "ar"),
                Tuple.Create(grvVocabJa, "ja"),
                Tuple.Create(grvVocabKo, "ko"),
                Tuple.Create(grvVocabPt, "pt"),
                Tuple.Create(grvVocabRu, "ru"),
                Tuple.Create(grvVocabZh, "zh"),
                Tuple.Create(grvVocabFr, "fr"),
                Tuple.Create(grvVocabDe, "de"),
            };

            foreach (var spec in localeSpecs)
            {
                var grid = spec.Item1;
                var langCode = spec.Item2;
                BindingList<VocabularyGridRowModel> locRows;
                if (string.Equals(langCode, "en", StringComparison.OrdinalIgnoreCase))
                    locRows = enRows;
                else if (!(grid.DataSource is BindingList<VocabularyGridRowModel> lr) || lr.Count != enRows.Count)
                    continue;
                else
                    locRows = lr;

                for (var i = 0; i < enRows.Count; i++)
                {
                    var lemma = (enRows[i].EnglishLemma ?? string.Empty).Trim();
                    if (lemma.Length == 0)
                        continue;

                    var enhancementJson = string.Equals(langCode, "en", StringComparison.OrdinalIgnoreCase)
                        ? enRows[i].EnhancementJson
                        : (i < locRows.Count ? locRows[i].EnhancementJson : null) ?? enRows[i].EnhancementJson;

                    var meaning = string.Equals(langCode, "en", StringComparison.OrdinalIgnoreCase)
                        ? enRows[i].Meaning ?? string.Empty
                        : (i < locRows.Count ? locRows[i].Meaning : null) ?? string.Empty;

                    JObject enhancementObj = null;
                    if (!string.IsNullOrWhiteSpace(enhancementJson))
                    {
                        try
                        {
                            var tok = JToken.Parse(enhancementJson);
                            enhancementObj = tok as JObject;
                        }
                        catch
                        {
                            enhancementObj = null;
                        }
                    }

                    var payload = enhancementObj != null ? (JObject)enhancementObj.DeepClone() : new JObject();
                    payload["meaning"] = meaning ?? string.Empty;

                    if (payload.Properties().All(p => p.Name == "meaning" && string.IsNullOrWhiteSpace(meaning)))
                        continue;

                    try
                    {
                        await VocabularyFirebaseCacheWriter.PutVocabularyCacheAsync(lemma, langCode, payload, episodeId).ConfigureAwait(true);
                    }
                    catch
                    {
                        // best-effort cache upload
                    }

                    await Task.Delay(50).ConfigureAwait(true);
                }
            }
        }

        /// <summary>
        /// Firebase RTDB <c>ai_cache/translations/{episodeId}/{lang}.json</c> — khớp Flutter <c>AIFirebaseCacheService.saveTranslation</c>.
        /// Dữ liệu lưu trong <c>data.translations</c> là mảng item có
        /// <c>original</c>, <c>translated</c>, <c>lineNumber</c> (0-based, khớp transcript row index).
        /// </summary>
        private async Task UploadTranslationsAiCachesAsync(string episodeId)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                return;

            if (!(grvRow.DataSource is BindingList<EpisodeRowModel> enRows) || enRows.Count == 0)
                return;

            var localeSpecs = new[]
            {
                Tuple.Create(grvViRow, "vi"),
                Tuple.Create(grvEsRow, "es"),
                Tuple.Create(grvArRow, "ar"),
                Tuple.Create(grvJaRow, "ja"),
                Tuple.Create(grvKoRow, "ko"),
                Tuple.Create(grvPtRow, "pt"),
                Tuple.Create(grvRuRow, "ru"),
                Tuple.Create(grvZhRow, "zh"),
                Tuple.Create(grvFrRow, "fr"),
                Tuple.Create(grvDeRow, "de"),
            };

            foreach (var spec in localeSpecs)
            {
                var grid = spec.Item1;
                var langCode = spec.Item2;
                if (!(grid.DataSource is BindingList<EpisodeRowModel> locRows) || locRows.Count == 0)
                    continue;

                var n = Math.Min(enRows.Count, locRows.Count);
                var arr = new JArray();
                for (var i = 0; i < n; i++)
                {
                    var original = (enRows[i].RowContent ?? string.Empty).Trim();
                    var translated = (locRows[i].RowContent ?? string.Empty).Trim();
                    if (original.Length == 0 || translated.Length == 0)
                        continue;

                    arr.Add(new JObject
                    {
                        ["original"] = original,
                        ["translated"] = translated,
                        ["lineNumber"] = i,
                    });
                }

                if (arr.Count == 0)
                    continue;

                try
                {
                    await TranslationsFirebaseCacheWriter.PutTranslationsCacheAsync(episodeId, langCode, arr).ConfigureAwait(true);
                }
                catch
                {
                    // best-effort cache upload
                }

                await Task.Delay(50).ConfigureAwait(true);
            }
        }

        /// <summary>
        /// Firebase RTDB <c>ai_cache/questions/{episodeId}/{count}.json</c> — khớp Flutter <c>AIFirebaseCacheService.saveQuestions</c>.
        /// </summary>
        private async Task UploadQuestionsAiCachesAsync(string episodeId)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                return;

            if (!(grvQuestions.DataSource is BindingList<QuestionGridRowModel> rows) || rows.Count == 0)
                return;

            var count = rows.Count;
            var arr = new JArray();
            for (var i = 0; i < rows.Count; i++)
                arr.Add(rows[i].ToFlutterQuestionObject(i));

            try
            {
                await QuestionsFirebaseCacheWriter.PutQuestionsCacheAsync(episodeId, count, arr).ConfigureAwait(true);
            }
            catch
            {
                // best-effort cache upload
            }

            await Task.Delay(50).ConfigureAwait(true);
        }
    }
}