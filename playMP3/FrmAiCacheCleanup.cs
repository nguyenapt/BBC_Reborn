using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace playMP3
{
    public partial class FrmAiCacheCleanup : Form
    {
        private readonly string _rtdbBaseUrl;
        private readonly string _authToken;
        private List<string> _lastExpiredPaths = new List<string>();
        private CancellationTokenSource _cts;
        private bool _busy;

        public FrmAiCacheCleanup(string firebaseRtdbBaseUrl, string firebaseAuthSecret)
        {
            _rtdbBaseUrl = GrammarCacheKeyHelper.NormalizeRtdbBaseUrl(firebaseRtdbBaseUrl);
            _authToken = firebaseAuthSecret ?? string.Empty;
            InitializeComponent();
            LoadNodes();
        }

        private void LoadNodes()
        {
            clbNodes.Items.Clear();
            foreach (var name in AiCacheExpiryCleaner.CacheNodeNames)
            {
                var ttl = AiCacheExpiryCleaner.DefaultTtlDaysForNode(name);
                clbNodes.Items.Add(name + "  (default TTL " + ttl + "d)", false);
            }
        }

        private IEnumerable<string> SelectedNodeNames()
        {
            for (var i = 0; i < clbNodes.Items.Count; i++)
            {
                if (!clbNodes.GetItemChecked(i))
                    continue;
                var text = clbNodes.Items[i].ToString() ?? string.Empty;
                var space = text.IndexOf("  ", StringComparison.Ordinal);
                yield return space > 0 ? text.Substring(0, space) : text.Trim();
            }
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

        private async void btnScan_Click(object sender, EventArgs e)
        {
            if (_busy)
                return;

            if (string.IsNullOrWhiteSpace(_authToken))
            {
                MessageBox.Show(this, "Thiếu Firebase secret (txtSecret trên form chính).", "AI Cache Cleanup",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var nodes = SelectedNodeNames().ToList();
            if (nodes.Count == 0)
            {
                MessageBox.Show(this, "Chọn ít nhất một node ai_cache.", "AI Cache Cleanup",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            await RunJobAsync(async ct =>
            {
                lblStatus.Text = "Đang quét…";
                txtLog.Clear();
                _lastExpiredPaths = new List<string>();

                var progress = new Progress<AiCacheExpiryCleaner.ScanProgress>(p =>
                {
                    lblStatus.Text = string.Format(
                        "Scan {0}: scanned={1}, expired={2}, invalid={3}",
                        p.Node ?? "",
                        p.ScannedLeaves,
                        p.ExpiredLeaves,
                        p.InvalidLeaves);
                });

                var result = await AiCacheExpiryCleaner.ScanAsync(_rtdbBaseUrl, nodes, _authToken, progress, ct)
                    .ConfigureAwait(true);

                _lastExpiredPaths = new List<string>(result.ExpiredPaths);
                AppendSummary(result);
                btnDelete.Enabled = _lastExpiredPaths.Count > 0;
                lblStatus.Text = string.Format(
                    "Xong scan: {0} leaf, {1} hết hạn, {2} invalid.",
                    result.ScannedLeaves,
                    result.ExpiredLeaves,
                    result.InvalidLeaves);
            }).ConfigureAwait(true);
        }

        private async void btnDelete_Click(object sender, EventArgs e)
        {
            if (_busy)
                return;

            if (_lastExpiredPaths == null || _lastExpiredPaths.Count == 0)
            {
                MessageBox.Show(this, "Chưa có danh sách hết hạn. Hãy Scan trước.", "AI Cache Cleanup",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            var confirm = MessageBox.Show(
                this,
                "Xóa " + _lastExpiredPaths.Count + " leaf cache hết hạn?\n\nChỉ xóa entry đã quá createdAt+ttlDays.",
                "Confirm delete",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning);
            if (confirm != DialogResult.Yes)
                return;

            var paths = new List<string>(_lastExpiredPaths);
            await RunJobAsync(async ct =>
            {
                lblStatus.Text = "Đang xóa…";
                var progress = new Progress<AiCacheExpiryCleaner.ScanProgress>(p =>
                {
                    lblStatus.Text = string.Format(
                        "Delete {0}/{1}: {2}",
                        p.ExpiredLeaves,
                        p.ScannedLeaves,
                        p.CurrentPath ?? "");
                });

                var result = await AiCacheExpiryCleaner.DeleteAsync(_rtdbBaseUrl, paths, _authToken, progress, ct)
                    .ConfigureAwait(true);

                txtLog.AppendText(Environment.NewLine + "=== DELETE ===" + Environment.NewLine);
                txtLog.AppendText("Deleted: " + result.Deleted + Environment.NewLine);
                txtLog.AppendText("Failed: " + result.Failed + Environment.NewLine);
                foreach (var err in result.Errors.Take(50))
                    txtLog.AppendText("  " + err + Environment.NewLine);

                if (result.Deleted > 0)
                {
                    _lastExpiredPaths.Clear();
                    btnDelete.Enabled = false;
                }

                lblStatus.Text = string.Format("Xóa xong: deleted={0}, failed={1}.", result.Deleted, result.Failed);
            }).ConfigureAwait(true);
        }

        private void btnCancel_Click(object sender, EventArgs e)
        {
            if (_cts != null)
                _cts.Cancel();
        }

        private void btnClose_Click(object sender, EventArgs e)
        {
            if (_busy && _cts != null)
                _cts.Cancel();
            Close();
        }

        private void AppendSummary(AiCacheExpiryCleaner.ScanResult result)
        {
            txtLog.AppendText("=== SCAN ===" + Environment.NewLine);
            foreach (var node in result.ScannedByNode.Keys.OrderBy(k => k))
            {
                int scanned = result.ScannedByNode[node];
                int expired = result.ExpiredByNode.ContainsKey(node) ? result.ExpiredByNode[node] : 0;
                txtLog.AppendText(string.Format("{0}: scanned={1}, expired={2}{3}",
                    node, scanned, expired, Environment.NewLine));
            }
            txtLog.AppendText(string.Format(
                "TOTAL scanned={0}, expired={1}, invalid={2}{3}",
                result.ScannedLeaves,
                result.ExpiredLeaves,
                result.InvalidLeaves,
                Environment.NewLine));

            const int maxLines = 200;
            var show = result.ExpiredPaths.Take(maxLines).ToList();
            if (show.Count > 0)
            {
                txtLog.AppendText(Environment.NewLine + "Expired paths (sample):" + Environment.NewLine);
                foreach (var p in show)
                    txtLog.AppendText("  " + p + Environment.NewLine);
                if (result.ExpiredPaths.Count > maxLines)
                {
                    txtLog.AppendText(string.Format(
                        "  … và {0} path khác{1}",
                        result.ExpiredPaths.Count - maxLines,
                        Environment.NewLine));
                }
            }
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
                txtLog.AppendText(Environment.NewLine + "(Cancelled)" + Environment.NewLine);
            }
            catch (Exception ex)
            {
                lblStatus.Text = "Lỗi.";
                MessageBox.Show(this, ex.Message, "AI Cache Cleanup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                txtLog.AppendText(Environment.NewLine + "ERROR: " + ex.Message + Environment.NewLine);
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
            btnScan.Enabled = !busy;
            btnDelete.Enabled = !busy && _lastExpiredPaths != null && _lastExpiredPaths.Count > 0;
            btnSelectAll.Enabled = !busy;
            btnSelectNone.Enabled = !busy;
            clbNodes.Enabled = !busy;
            btnCancel.Enabled = busy;
            progressBar.Style = busy ? ProgressBarStyle.Marquee : ProgressBarStyle.Blocks;
            progressBar.MarqueeAnimationSpeed = busy ? 40 : 0;
            UseWaitCursor = busy;
        }
    }
}
