using System;
using System.Drawing;
using System.Windows.Forms;
using System.Windows.Forms.VisualStyles;

namespace playMP3.Base
{
    /// <summary>Column header with a checkbox (checked / unchecked / indeterminate).</summary>
    public class DataGridViewCheckBoxHeaderCell : DataGridViewColumnHeaderCell
    {
        public CheckState CheckState { get; set; } = CheckState.Checked;

        public event EventHandler CheckBoxClicked;

        protected override void Paint(
            Graphics graphics,
            Rectangle clipBounds,
            Rectangle cellBounds,
            int rowIndex,
            DataGridViewElementStates dataGridViewElementState,
            object value,
            object formattedValue,
            string errorText,
            DataGridViewCellStyle cellStyle,
            DataGridViewAdvancedBorderStyle advancedBorderStyle,
            DataGridViewPaintParts paintParts)
        {
            base.Paint(
                graphics,
                clipBounds,
                cellBounds,
                rowIndex,
                dataGridViewElementState,
                value,
                formattedValue,
                errorText,
                cellStyle,
                advancedBorderStyle,
                paintParts);

            var checkBoxState = ToCheckBoxState(CheckState);
            var checkSize = CheckBoxRenderer.GetGlyphSize(graphics, checkBoxState);
            var x = cellBounds.Left + (cellBounds.Width - checkSize.Width) / 2;
            var y = cellBounds.Top + (cellBounds.Height - checkSize.Height) / 2;
            CheckBoxRenderer.DrawCheckBox(graphics, new Point(x, y), checkBoxState);
        }

        private static CheckBoxState ToCheckBoxState(CheckState state)
        {
            switch (state)
            {
                case CheckState.Checked:
                    return CheckBoxState.CheckedNormal;
                case CheckState.Indeterminate:
                    return CheckBoxState.MixedNormal;
                default:
                    return CheckBoxState.UncheckedNormal;
            }
        }

        protected override void OnMouseClick(DataGridViewCellMouseEventArgs e)
        {
            base.OnMouseClick(e);
            CheckBoxClicked?.Invoke(this, EventArgs.Empty);
        }
    }
}
