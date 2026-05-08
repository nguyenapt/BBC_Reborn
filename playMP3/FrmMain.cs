using Firebase.Auth;
using Firebase.Database;
using Firebase.Database.Query;
using Firebase.Storage;
using playMP3.Base;
using playMP3.Properties;
using System;
using System.Collections.Generic;
using System.ComponentModel;
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
        public frmMain()
        {
            InitializeComponent();
            player = new System.Windows.Media.MediaPlayer();
            grvRow.AutoGenerateColumns = false;
            grvRow.RowTemplate.Height = 40;
            grvRow.DefaultCellStyle.WrapMode = DataGridViewTriState.True;
            grvRow.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.AllCellsExceptHeaders;

            for (int i = DateTime.Now.Year; i >= 2013; i--)
            {
                cbYear.Items.Add(i.ToString());
            }

            txtId.Text = Guid.NewGuid().ToString();
            cbYear.SelectedIndex = 0;
            ReadConfigFile();

            cbCloudService.DataSource = this.ConfigModel.CloudServices;
            cbCloudService.DisplayMember = "Name";
            cbCloudService.ValueMember = "Name";

            cbType.DataSource = this.ConfigModel.EpisodeTypes;
            cbType.DisplayMember = "Name";
            cbType.ValueMember = "Name";
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
                        DataGridViewRow row1 = grvRow.Rows[row.Index + 1];
                        row1.Selected = true;
                        row1.Cells["FirstDuration"].Value = (pos + 1);
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

        private void btnConvertToGrid_Click(object sender, EventArgs e)
        {
            ConvertToGrid();
        }

        public void ConvertToGrid()
        {
            grvRow.DataSource = null;

            var lstRows = txtTranscript.Text.Split(new string[] { Environment.NewLine + Environment.NewLine },
                               StringSplitOptions.RemoveEmptyEntries);
            var lstRowModels = new List<EpisodeRowModel>();

            foreach (var row in lstRows)
            {
                lstRowModels.Add(new EpisodeRowModel() { FirstDuration = 0, RowContent = row.Trim(), LastDuration = 0, Group = 0 });
            }
            grvRow.DataSource = lstRowModels;
            grvRow.AutoResizeRows(DataGridViewAutoSizeRowsMode.AllCellsExceptHeaders);
        }

        /// <summary>
        /// Một số bản UI bỏ cột "Group" (vd. chỉ còn Grammar…). Không được gọi row.Cells["Group"] khi cột không tồn tại.
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
            var actors = txtActor.Text.Split(new string[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries).ToList();

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
                                if (actors.Contains(rc))
                                {
                                    groupResult += $"<b>{rc}</b><br />";
                                    groupResult += Environment.NewLine;
                                }
                                else
                                {
                                    groupResult += $"{rc}<br />";
                                }
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
            string configFileName = Path.Combine(Directory.GetCurrentDirectory(), "service.config");
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

            }
            else
            {
                throw new Exception("Config file not found.");
            }
        }

        private void btnSubmit_Click(object sender, EventArgs e)
        {
            OnSubmit();
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
                txtSecondfileUrl.Text = task;
            }
            catch (Exception ex)
            {
                Console.WriteLine("Exception was thrown: {0}", ex);
            }
        }


        private void OnSubmit()
        {
            FirebaseClient firebaseClient = new FirebaseClient(txtUrl.Text, new FirebaseOptions
            {
                AuthTokenAsyncFactory = () => Task.FromResult(txtSecret.Text)
            });

            var episode = new Episode();
            if (!string.IsNullOrEmpty(txtId.Text))
            {
                Guid id = Guid.Empty;
                Guid.TryParse(txtId.Text, out id);
                episode.Id = id;
            }
            else
            {
                episode.Id = Guid.NewGuid();
            }
            episode.Category = cbCategory.Text;
            episode.Year = cbYear.Text;
            episode.PublishedDate = dpPublishDate.Value;
            episode.ThumbImage = txtThumb.Text;
            episode.EpisodeName = txtEpisodeName.Text;
            episode.FileUrl = txtFileUrl.Text;
            episode.SecondFileUrl = txtSecondfileUrl.Text;
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
            episode.Actor = txtActor.Text;

            bool isSupportYear = ConfigModel.SelectedEpisodeType.EpisodeCategories
                .Where(x => x.IsSupportYear)
                .Select(x => x.Category)
                .Contains(cbCategory.Text);
            string categoryPath = cbCategory.Text + (isSupportYear ? "/" + cbYear.Text : "");

            firebaseClient.Child(categoryPath + "/" + txtNumber.Text).PatchAsync(episode);

            var listEpisode = new
            {
                episode.Category,
                episode.EpisodeName,
                episode.FileUrl,
                episode.Id,
                episode.IsNew,
                episode.PublishedDate,
                episode.SecondFileUrl,
                episode.Summary,
                episode.ThumbImage,
                episode.Year
            };

            firebaseClient.Child("List/" + categoryPath + "/" + txtNumber.Text).PatchAsync(listEpisode);

            if (!string.IsNullOrEmpty(txtHomeNumber.Text))
            {
                if (cbType.Text == "BBC")
                {
                    firebaseClient.Child("HomePage/" + txtHomeNumber.Text).PatchAsync(episode);
                    firebaseClient.Child("List/HomePage/" + txtHomeNumber.Text).PatchAsync(listEpisode);
                }
                if (cbType.Text == "VOA")
                {
                    firebaseClient.Child("NewHomePage/" + txtHomeNumber.Text).PatchAsync(episode);
                }
            }
        }

        private void cbType_SelectedIndexChanged(object sender, EventArgs e)
        {
            var selectedEpisode = ((EpisodeTypeModel)(cbType.SelectedItem));
            cbCategory.DataSource = selectedEpisode.EpisodeCategories;
            cbCategory.DisplayMember = "Category";
            cbCategory.ValueMember = "Category";
            ConfigModel.SelectedEpisodeType = selectedEpisode;
        }

        private void cbCloudService_SelectedIndexChanged(object sender, EventArgs e)
        {
            txtUrl.Text = ((CloudService)(cbCloudService.SelectedItem)).Url;
            txtApiKey.Text = ((CloudService)(cbCloudService.SelectedItem)).ApiKey;
            txtSecret.Text = ((CloudService)(cbCloudService.SelectedItem)).Secret;
            ConfigModel.SelectedCloudService = ((CloudService)(cbCloudService.SelectedItem));
            cbType.Focus();
        }

        private void btnGetLink_Click(object sender, EventArgs e)
        {
            FileStream stream = new FileStream(txtFilePath.Text, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);

            var url = upload(Path.GetFileName(txtFilePath.Text), stream);
        }

        private void btnImageLink_Click(object sender, EventArgs e)
        {
            using (OpenFileDialog openFileDialog = new OpenFileDialog())
            {
                if (openFileDialog.ShowDialog() == DialogResult.OK)
                {
                    FileStream stream = new FileStream(openFileDialog.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);

                    var url = uploadThumb(Path.GetFileName(openFileDialog.FileName), stream);
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

        private void btnSubmitAndAddNew_Click(object sender, EventArgs e)
        {
            OnSubmit();

            txtFilePath.Text = "";
            txtLength.Text = "";
            txtPosition.Text = "";
            txtNextPosition.Text = "";
            txtTranscript.Text = "";
            txtActor.Text = "";
            txtResult.Text = "";
            txtGroupResult.Text = "";
            grvRow.DataSource = null;
            txtId.Text = Guid.NewGuid().ToString();
            txtEpisodeName.Text = "";
            txtThumb.Text = "";
            txtFileUrl.Text = "";
            txtSecondfileUrl.Text = "";
            txtDuration.Value = 0;
            txtVocab.Text = "";
            txtSummary.Text = "";
            txtGrammar.Text = "";

            int nextNumber = int.Parse(txtNumber.Text) + 1;

            txtNumber.Text = nextNumber + "";

            var resultString = Regex.Match(txtHomeNumber.Text, @"\d+").Value;

            int nextHomeNumber = int.Parse(resultString) + 1;

            txtHomeNumber.Text = cbCategory.Text + "/" + nextHomeNumber;

        }

        private void btnConfig_Click(object sender, EventArgs e)
        {

        }
    }

    public class EpisodeRowModel
    {
        public double FirstDuration { get; set; }
        public string RowContent { get; set; }
        public double LastDuration { get; set; }
        public int Group { get; set; }
    }
}