using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;

namespace playMP3.Base
{
    public class ConfigModel
    {
        public List<EpisodeTypeModel> EpisodeTypes { get; set; }
        public List<CloudService> CloudServices { get; set; }

        /// <summary>Optional Gemini API key(s) from service.config (Configurations/GeminiApiKey). Multiple: key1;key2 (also accepts comma).</summary>
        public string GeminiApiKey { get; set; }

        /// <summary>Delay (ms) between grammar API calls; optional GeminiRequestDelayMs in service.config.</summary>
        public int GeminiRequestDelayMs { get; set; } = 4500;

        /// <summary>Path to Firebase service account JSON for FCM (Configurations/FcmServiceAccountPath) — BBC.</summary>
        public string FcmServiceAccountPath { get; set; }

        /// <summary>Path to Firebase service account JSON for FCM VOA project (Configurations/FcmServiceAccountPathVOA).</summary>
        public string FcmServiceAccountPathVoa { get; set; }

        /// <summary>Default on/off for episode push; UI checkbox can override per submit.</summary>
        public bool SendEpisodePush { get; set; } = true;

        private EpisodeTypeModel _selectedEpisodeType;
        private CloudService _selectedCloudService;

        public ConfigModel()
        {
            EpisodeTypes = new List<EpisodeTypeModel>();
            CloudServices = new List<CloudService>();
        }

        public EpisodeTypeModel SelectedEpisodeType
        {
            get
            {
                if (this.EpisodeTypes != null && _selectedEpisodeType == null)
                    _selectedEpisodeType = this.EpisodeTypes.FirstOrDefault(x => x.IsSelected) ?? this.EpisodeTypes.FirstOrDefault();
                return _selectedEpisodeType;
            }
            set { _selectedEpisodeType = value; }
        }
        public CloudService SelectedCloudService
        {
            get
            {
                if (this.CloudServices != null && _selectedCloudService==null)
                    _selectedCloudService =  this.CloudServices.FirstOrDefault(x => x.IsSelected) ?? this.CloudServices.FirstOrDefault();
                return _selectedCloudService;
            }
            set { _selectedCloudService = value; }
        }

        public List<EpisodeCategoryModel> GetCategoriesByName(string Name)
        {
            return EpisodeTypes.Where(x => x.Name == Name).FirstOrDefault()?.EpisodeCategories;
        }
    }

    public class EpisodeTypeModel
    {
        public EpisodeTypeModel()
        {
            EpisodeCategories = new List<EpisodeCategoryModel>();
        }
        public string Name { get; set; }
        public bool IsSelected { get; set; }
        public List<EpisodeCategoryModel> EpisodeCategories { get; set; }
    }

    public class EpisodeCategoryModel
    {
        public string Category { get; set; }
        public bool IsSupportYear { get; set; }
        public bool IsSelected { get; set; }
    }

    public class CloudService
    {
        public string Name { get; set; }
        public string Url { get; set; }
        public string ApiKey { get; set; }
        public string Secret { get; set; }
        public string Storage { get; set; }
        public bool IsSelected { get; set; }
    }
}
