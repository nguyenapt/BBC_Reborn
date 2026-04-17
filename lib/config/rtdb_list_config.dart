/// Cấu hình đọc nhánh RTDB `List/...` (payload mỏng) thay cho `HomePage`, `/{cat}/{year}`, …
///
/// Build pipeline: [tools/add_rtdb_list_node.mjs](tools/add_rtdb_list_node.mjs) tạo
/// [database-list-17042026.json](database-list-17042026.json) để import dưới node `List`.
///
/// Tắt tạm (vd. khi chưa deploy `List` trên server):  
/// `--dart-define=RTDB_SLIM_LIST=false`
class RtdbListConfig {
  RtdbListConfig._();

  static const bool useSlimListPaths = bool.fromEnvironment(
    'RTDB_SLIM_LIST',
    defaultValue: true,
  );
}
