using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    public partial class FrmRtdbPathMigrate : Form
    {
        private readonly string _baseUrl;
        private readonly string _authToken;
        private JObject _root;
        private List<RtdbPathMigrator.EpisodeLeaf> _previewLeaves = new List<RtdbPathMigrator.EpisodeLeaf>();
        private CancellationTokenSource _cts;
        private bool _busy;

        public FrmRtdbPathMigrate(string firebaseBaseUrl, string firebaseAuthSecret)
        {
            _baseUrl = firebaseBaseUrl ?? string.Empty;
            _authToken = firebaseAuthSecret ?? string.Empty;
            InitializeComponent();
        }

        private void btnBrowse_Click(object sender, EventArgs e)
        {
            using (var dlg = new OpenFileDialog())
            {
                dlg.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*";
                dlg.Title = "Chọn file JSON full RTDB export";
                if (dlg.ShowDialog(this) != DialogResult.OK) return;

                try
                {
                    var text = File.ReadAllText(dlg.FileName);
                    var token = JToken.Parse(text);
                    if (!(token is JObject root))
                    {
                        MessageBox.Show(this, "File JSON phải là object root (toàn bộ database).",
                            "Migrate RtdbPath", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        return;
                    }

                    _root = root;
                    txtFile.Text = dlg.FileName;
                    PopulateNodes();
                    _previewLeaves.Clear();
                    lblStatus.Text = "Đã load JSON. Chọn node rồi Preview.";
                    AppendLog("Loaded " + dlg.FileName);
                }
                catch (Exception ex)
                {
                    MessageBox.Show(this, ex.Message, "Migrate RtdbPath", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        private void PopulateNodes()
        {
            clbNodes.Items.Clear();
            if (_root == null) return;
            foreach (var path in RtdbPathMigrator.LoadSelectableNodes(_root))
                clbNodes.Items.Add(path, false);
        }

        private List<string> SelectedPaths()
        {
            var list = new List<string>();
            for (var i = 0; i < clbNodes.Items.Count; i++)
            {
                if (!clbNodes.GetItemChecked(i)) continue;
                list.Add(clbNodes.Items[i].ToString());
            }
            return list;
        }

        private void btnSelectAll_Click(object sender, EventArgs e)
        {
            for (var i = 0; i < clbNodes.Items.Count; i++)
                clbNodes.SetItemChecked(i, true);
        }

        private void btnSelectNone_Click(object sender, EventArgs e)
        {
            for (var i = 0; i < clbNodes.Items.Count; i++)
                clbNodes.SetItemChecked(i, false);
        }

        private void btnPreview_Click(object sender, EventArgs e)
        {
            if (_root == null)
            {
                MessageBox.Show(this, "Chọn file JSON trước.", "Migrate RtdbPath",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var selected = SelectedPaths();
            if (selected.Count == 0)
            {
                MessageBox.Show(this, "Chọn ít nhất một node.", "Migrate RtdbPath",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            _previewLeaves = RtdbPathMigrator.EnumerateEpisodeLeaves(_root, selected);
            var needPatch = _previewLeaves.Count(l => !l.AlreadyHasCorrectPath && !l.Unresolved);
            var already = _previewLeaves.Count(l => l.AlreadyHasCorrectPath);
            var unresolved = _previewLeaves.Count(l => l.Unresolved);
            lblStatus.Text = string.Format(
                "Preview: {0} episode(s) — {1} cần patch, {2} đã có RtdbPath, {3} không resolve được.",
                _previewLeaves.Count, needPatch, already, unresolved);
            AppendLog(lblStatus.Text);
            foreach (var leaf in _previewLeaves.Where(l => l.IsHomePageSlot).Take(20))
            {
                AppendLog("  Home "
                    + (leaf.HomePageSlotPath ?? leaf.ListHomePageSlotPath)
                    + " → "
                    + (leaf.RtdbPath ?? "(UNRESOLVED)"));
            }
            btnMigrate.Enabled = _previewLeaves.Count > 0;
        }

        private async void btnMigrate_Click(object sender, EventArgs e)
        {
            if (_busy) return;
            if (string.IsNullOrWhiteSpace(_authToken))
            {
                MessageBox.Show(this, "Thiếu Firebase secret (txtSecret trên form chính).",
                    "Migrate RtdbPath", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (string.IsNullOrWhiteSpace(_baseUrl))
            {
                MessageBox.Show(this, "Thiếu Firebase URL (txtUrl trên form chính).",
                    "Migrate RtdbPath", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (_previewLeaves == null || _previewLeaves.Count == 0)
                btnPreview_Click(sender, e);
            if (_previewLeaves == null || _previewLeaves.Count == 0) return;

            var confirm = MessageBox.Show(
                this,
                "Patch RtdbPath cho " + _previewLeaves.Count + " episode(s) lên RTDB (full + List nếu có)?",
                "Migrate RtdbPath",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);
            if (confirm != DialogResult.Yes) return;

            await RunJobAsync(async ct =>
            {
                lblStatus.Text = "Đang migrate…";
                progressBar.Value = 0;
                var logProgress = new Progress<string>(AppendLog);
                var pctProgress = new Progress<int>(p =>
                {
                    progressBar.Value = Math.Max(0, Math.Min(100, p));
                });

                var result = await RtdbPathMigrator.MigrateAsync(
                    _baseUrl,
                    _authToken,
                    _previewLeaves,
                    logProgress,
                    pctProgress,
                    ct).ConfigureAwait(true);

                lblStatus.Text = string.Format(
                    "Xong: full={0}, list={1}, homeSlots={2}, skip={3}, listMissing={4}, unresolved={5}, fail={6}",
                    result.PatchedFull,
                    result.PatchedList,
                    result.PatchedHomeSlots,
                    result.Skipped,
                    result.ListMissing,
                    result.Unresolved,
                    result.Failed);
                AppendLog(lblStatus.Text);
            });
        }

        private void btnCancel_Click(object sender, EventArgs e)
        {
            if (_cts != null)
                _cts.Cancel();
        }

        private void btnClose_Click(object sender, EventArgs e)
        {
            if (_busy)
            {
                MessageBox.Show(this, "Đang chạy — Cancel trước khi đóng.", "Migrate RtdbPath",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            Close();
        }

        private async Task RunJobAsync(Func<CancellationToken, Task> work)
        {
            _busy = true;
            _cts = new CancellationTokenSource();
            SetBusyUi(true);
            try
            {
                await work(_cts.Token).ConfigureAwait(true);
            }
            catch (OperationCanceledException)
            {
                lblStatus.Text = "Đã hủy.";
                AppendLog("Cancelled.");
            }
            catch (Exception ex)
            {
                lblStatus.Text = "Lỗi: " + ex.Message;
                AppendLog("ERROR " + ex);
                MessageBox.Show(this, ex.Message, "Migrate RtdbPath", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                _busy = false;
                SetBusyUi(false);
                if (_cts != null)
                {
                    _cts.Dispose();
                    _cts = null;
                }
            }
        }

        private void SetBusyUi(bool busy)
        {
            btnBrowse.Enabled = !busy;
            btnSelectAll.Enabled = !busy;
            btnSelectNone.Enabled = !busy;
            btnPreview.Enabled = !busy;
            btnMigrate.Enabled = !busy && _previewLeaves != null && _previewLeaves.Count > 0;
            btnCancel.Enabled = busy;
            clbNodes.Enabled = !busy;
        }

        private void AppendLog(string line)
        {
            if (txtLog.IsDisposed) return;
            txtLog.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + line + Environment.NewLine);
        }
    }
}
