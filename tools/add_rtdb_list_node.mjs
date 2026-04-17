/**
 * Tạo tree `List` (bản mỏng) từ export RTDB đầy đủ — bỏ Transcript, TranscriptHtml,
 * Vocabulary, Vocabularies, Grammar.
 *
 * Ghi:
 * - database-list-17042026.json — nội dung nhánh List (HomePage, 6M, …) **không** bọc thêm key `List`
 * - database - 17042026.json — toàn bộ DB **không** gồm key List
 *
 * Chạy: node tools/add_rtdb_list_node.mjs
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const INPUT = path.join(root, 'database - 17042026.json');
const OUTPUT_LIST = path.join(root, 'database-list-17042026.json');

const DROP_KEYS = new Set([
  'Transcript',
  'TranscriptHtml',
  'Vocabulary',
  'Vocabularies',
  'Grammar',
]);

function slimEpisode(ep) {
  if (ep == null || typeof ep !== 'object') return ep;
  const o = { ...ep };
  for (const k of DROP_KEYS) delete o[k];
  return o;
}

function slimYearContent(content) {
  if (Array.isArray(content)) return content.map(slimEpisode);
  if (content && typeof content === 'object' && !Array.isArray(content)) {
    const out = {};
    for (const [k, v] of Object.entries(content)) {
      out[k] = slimEpisode(v);
    }
    return out;
  }
  return content;
}

function slimHomePage(hp) {
  if (!hp || typeof hp !== 'object') return hp;
  const out = {};
  for (const [k, v] of Object.entries(hp)) {
    if (k === 'Grammar') {
      if (Array.isArray(v)) out[k] = v.map(slimEpisode);
      else out[k] = v;
    } else if (Array.isArray(v)) {
      out[k] = v.map(slimEpisode);
    } else {
      out[k] = v;
    }
  }
  return out;
}

function isYearKeyedObject(obj) {
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return false;
  const keys = Object.keys(obj);
  if (keys.length === 0) return false;
  return keys.every((k) => /^\d{4}$/.test(k));
}

function buildListTree(data) {
  const List = {};

  if (data.HomePage) {
    List.HomePage = slimHomePage(data.HomePage);
  }

  const skip = new Set(['HomePage', 'AppUpdate', 'ai_cache', 'List']);

  for (const key of Object.keys(data)) {
    if (skip.has(key)) continue;
    const val = data[key];
    if (isYearKeyedObject(val)) {
      List[key] = {};
      for (const [year, content] of Object.entries(val)) {
        List[key][year] = slimYearContent(content);
      }
    } else if (Array.isArray(val)) {
      List[key] = slimYearContent(val);
    }
  }

  return List;
}

function main() {
  console.log('Reading', INPUT);
  const raw = fs.readFileSync(INPUT, 'utf8');
  const data = JSON.parse(raw);

  delete data.List;
  const listTree = buildListTree(data);

  fs.writeFileSync(OUTPUT_LIST, JSON.stringify(listTree, null, 2), 'utf8');
  console.log('Wrote', OUTPUT_LIST);

  fs.writeFileSync(INPUT, JSON.stringify(data, null, 2), 'utf8');
  console.log('Wrote', INPUT, '(no List key). Top-level keys:', Object.keys(data).sort().join(', '));
}

main();
