using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace playMP3.Base
{
    public class IconButton: Button
    {
        IconButton()
        {
            this.Resize += new System.EventHandler(CustomButton_Resize);
        }
        void CustomButton_Resize(object sender, EventArgs e)
        {
            if (this.BackgroundImage == null)
                return;
            var pic = new Bitmap(this.BackgroundImage, new Size(this.Width, this.Height));
            this.BackgroundImage = pic;
        }
    }
}
