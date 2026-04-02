FirestoreMigration — import JSON export RTDB sang Firestore (C# / net8.0)

Chuẩn bị:
1) Firebase Console: bật Firestore, lấy Project ID.
2) IAM: tạo service account, gán quyền ghi Firestore (vd. Cloud Datastore User), tải file JSON key.

Cấu hình:
- Sửa appsettings.json: Firestore:ProjectId
- Hoặc FIRESTORE_PROJECT_ID
- Credential: đặt GOOGLE_APPLICATION_CREDENTIALS=đường_dẫn_file_key.json
  hoặc Firestore:CredentialPath trong appsettings.json

Chạy:
  dotnet run --project tools/FirestoreMigration -- "D:\path\to\export.json"

Hoặc từ thư mục tools/FirestoreMigration:
  dotnet run -- "D:\path\to\export.json"

Mặc định: mỗi key cấp 1 của JSON gốc = 1 document trong collection rtdb_import.
Giới hạn Firestore ~1 MiB/document — nhánh quá lớn cần tách export hoặc sửa code.

Biến môi trường có prefix FSM_ (vd. FSM_Firestore__ProjectId) map vào appsettings.
