/**
 * Tách node `List` từ export RTDB gộp → file `database-list-*.json` (chỉ nội bên trong List, không bọc `"List"`),
 * và ghi lại file gốc không còn key `List`.
 *
 * Chạy: node tools/extract_list_node.mjs
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const MAIN = path.join(root, 'database - 17042026.json');
const LIST_OUT = path.join(root, 'database-list-17042026.json');

function main() {
  const raw = fs.readFileSync(MAIN, 'utf8');
  const data = JSON.parse(raw);

  if (!data.List) {
    console.error('Không có key List trong', MAIN);
    process.exit(1);
  }

  fs.writeFileSync(LIST_OUT, JSON.stringify(data.List, null, 2), 'utf8');
  console.log('Đã ghi', LIST_OUT);

  delete data.List;
  fs.writeFileSync(MAIN, JSON.stringify(data, null, 2), 'utf8');
  console.log('Đã cập nhật', MAIN, '(đã bỏ List)');
}

main();
