/// Cấu hình đọc nhánh RTDB `category/List/...` (payload mỏng).
///
/// Build pipeline: [tools/add_rtdb_list_node.mjs](tools/add_rtdb_list_node.mjs)
/// tạo slim tree để import dưới `category/List`.
///
/// App British **không** fallback HomePage full — slim list bắt buộc có `RtdbPath`.
///
/// Tắt tạm (vd. khi debug full tree):
/// `--dart-define=RTDB_SLIM_LIST=false`
class RtdbListConfig {
  RtdbListConfig._();

  static const bool useSlimListPaths = bool.fromEnvironment(
    'RTDB_SLIM_LIST',
    defaultValue: true,
  );
}
