using System.Text.Json;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;
using Microsoft.Extensions.Configuration;

namespace FirestoreMigration;

/// <summary>
/// Đọc file JSON export từ Realtime Database, ghi lên Firestore (mỗi key cấp 1 = 1 document).
/// Firestore giới hạn ~1 MiB/document — nếu một nhánh quá lớn, cần tách export hoặc bổ sung logic chia nhỏ.
/// </summary>
internal static class Program
{
    private const int MaxBatchOperations = 450;

    public static async Task<int> Main(string[] args)
    {
        var basePath = AppContext.BaseDirectory;
        var config = new ConfigurationBuilder()
            .SetBasePath(basePath)
            .AddJsonFile("appsettings.json", optional: true)
            .AddEnvironmentVariables(prefix: "FSM_")
            .Build();

        var jsonPath = args.Length > 0
            ? args[0]
            : config["Firestore:ExportJsonPath"] ?? "exported.json";

        if (!Path.IsPathRooted(jsonPath))
            jsonPath = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), jsonPath));

        if (!File.Exists(jsonPath))
        {
            Console.Error.WriteLine($"Không tìm thấy file: {jsonPath}");
            Console.Error.WriteLine("Dùng: dotnet run -- <đường_dẫn_export.json>");
            Console.Error.WriteLine("Hoặc đặt Firestore:ExportJsonPath trong appsettings.json");
            return 1;
        }

        var projectId = config["Firestore:ProjectId"]
            ?? Environment.GetEnvironmentVariable("FIRESTORE_PROJECT_ID");
        if (string.IsNullOrWhiteSpace(projectId) || projectId == "YOUR_FIREBASE_PROJECT_ID")
        {
            Console.Error.WriteLine("Thiết lập Firestore:ProjectId trong appsettings.json hoặc biến môi trường FIRESTORE_PROJECT_ID.");
            return 1;
        }

        var collectionName = config["Firestore:CollectionName"] ?? "rtdb_import";
        var credentialPath = config["Firestore:CredentialPath"];
        if (!string.IsNullOrWhiteSpace(credentialPath) && !Path.IsPathRooted(credentialPath))
            credentialPath = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), credentialPath));

        FirestoreDb db;
        if (!string.IsNullOrWhiteSpace(credentialPath) && File.Exists(credentialPath))
        {
            var credential = GoogleCredential.FromFile(credentialPath);
            var builder = new FirestoreDbBuilder
            {
                ProjectId = projectId,
                Credential = credential
            };
            db = await builder.BuildAsync();
        }
        else if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS")))
        {
            db = await FirestoreDb.CreateAsync(projectId);
        }
        else
        {
            Console.Error.WriteLine("Cần một trong hai:");
            Console.Error.WriteLine("  - Firestore:CredentialPath trong appsettings.json trỏ tới service account JSON, hoặc");
            Console.Error.WriteLine("  - Biến môi trường GOOGLE_APPLICATION_CREDENTIALS (đường dẫn file service account).");
            return 1;
        }

        var jsonText = await File.ReadAllTextAsync(jsonPath);
        using var doc = JsonDocument.Parse(jsonText);
        var root = doc.RootElement;

        if (root.ValueKind != JsonValueKind.Object)
        {
            Console.Error.WriteLine("JSON gốc phải là object { ... }. Nếu export là array, bọc trong object trước khi import.");
            return 1;
        }

        var collection = db.Collection(collectionName);
        var topLevel = new List<(string Id, Dictionary<string, object> Data)>();

        foreach (var prop in root.EnumerateObject())
        {
            var converted = JsonElementToFirestoreValue(prop.Value);
            if (converted is Dictionary<string, object> map)
                topLevel.Add((SanitizeDocumentId(prop.Name), map));
            else
                topLevel.Add((SanitizeDocumentId(prop.Name), new Dictionary<string, object> { ["_value"] = converted! }));
        }

        Console.WriteLine($"Project: {projectId}, Collection: {collectionName}, Documents (cấp 1): {topLevel.Count}");

        for (var i = 0; i < topLevel.Count; i += MaxBatchOperations)
        {
            var batch = db.StartBatch();
            var slice = topLevel.Skip(i).Take(MaxBatchOperations).ToList();
            foreach (var (id, data) in slice)
            {
                var docRef = collection.Document(id);
                batch.Set(docRef, data);
            }

            await batch.CommitAsync();
            Console.WriteLine($"Đã ghi batch {i / MaxBatchOperations + 1} ({slice.Count} docs).");
        }

        Console.WriteLine("Xong.");
        return 0;
    }

    private static string SanitizeDocumentId(string key)
    {
        foreach (var c in Path.GetInvalidFileNameChars())
            key = key.Replace(c, '_');
        return string.IsNullOrEmpty(key) ? "empty" : key;
    }

    private static object? JsonElementToFirestoreValue(JsonElement el)
    {
        switch (el.ValueKind)
        {
            case JsonValueKind.Object:
                return JsonElementToFirestoreMap(el);
            case JsonValueKind.Array:
                var list = new List<object?>();
                foreach (var item in el.EnumerateArray())
                    list.Add(JsonElementToFirestoreValue(item));
                return list;
            case JsonValueKind.String:
                return el.GetString();
            case JsonValueKind.Number:
                if (el.TryGetInt64(out var l))
                    return l;
                return el.GetDouble();
            case JsonValueKind.True:
                return true;
            case JsonValueKind.False:
                return false;
            case JsonValueKind.Null:
            case JsonValueKind.Undefined:
                return null;
            default:
                return el.ToString();
        }
    }

    private static Dictionary<string, object> JsonElementToFirestoreMap(JsonElement el)
    {
        var map = new Dictionary<string, object>();
        foreach (var prop in el.EnumerateObject())
        {
            var v = JsonElementToFirestoreValue(prop.Value);
            if (v != null)
                map[prop.Name] = v;
        }

        return map;
    }
}
