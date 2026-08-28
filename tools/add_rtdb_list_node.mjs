/**
 * Tạo tree `List` (bản mỏng) từ export RTDB đầy đủ — bỏ Transcript, TranscriptHtml,
 * Vocabulary, Vocabularies, Grammar.
 *
 * Inject `RtdbPath` = parentPath + '/' + key khi thiếu (để Flutter hydrate 1 GET).
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

function looksLikeEpisode(ep) {
  if (ep == null || typeof ep !== 'object' || Array.isArray(ep)) return false;
  return (
    ep.Id != null ||
    ep.EpisodeName != null ||
    ep.Transcript != null ||
    ep.FileUrl != null
  );
}

function slimEpisode(ep, rtdbPath) {
  if (ep == null || typeof ep !== 'object') return ep;
  const o = { ...ep };
  for (const k of DROP_KEYS) delete o[k];
  if (rtdbPath && (!o.RtdbPath || String(o.RtdbPath).trim() === '')) {
    o.RtdbPath = rtdbPath;
  }
  return o;
}

function slimYearContent(content, parentPath) {
  if (Array.isArray(content)) {
    return content.map((ep, i) =>
      slimEpisode(ep, parentPath != null ? `${parentPath}/${i}` : undefined),
    );
  }
  if (content && typeof content === 'object' && !Array.isArray(content)) {
    const out = {};
    for (const [k, v] of Object.entries(content)) {
      const childPath = parentPath != null ? `${parentPath}/${k}` : k;
      if (looksLikeEpisode(v)) {
        out[k] = slimEpisode(v, childPath);
      } else {
        out[k] = slimYearContent(v, childPath);
      }
    }
    return out;
  }
  return content;
}

function slimHomePage(hp) {
  if (!hp || typeof hp !== 'object') return hp;
  const out = {};
  for (const [k, v] of Object.entries(hp)) {
    const parent = `HomePage/${k}`;
    if (k === 'Grammar') {
      if (Array.isArray(v)) {
        out[k] = v.map((ep, i) => slimEpisode(ep, `${parent}/${i}`));
      } else {
        out[k] = v;
      }
    } else if (Array.isArray(v)) {
      out[k] = v.map((ep, i) => slimEpisode(ep, `${parent}/${i}`));
    } else if (v && typeof v === 'object') {
      out[k] = slimYearContent(v, parent);
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
        List[key][year] = slimYearContent(content, `${key}/${year}`);
      }
    } else if (Array.isArray(val)) {
      List[key] = slimYearContent(val, key);
    } else if (val && typeof val === 'object') {
      // AS / flat category maps
      List[key] = slimYearContent(val, key);
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
