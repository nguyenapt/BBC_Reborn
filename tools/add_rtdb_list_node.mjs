/**
 * Tạo tree `category/List` (bản mỏng) từ export RTDB British (gom dưới `category/`).
 * Bỏ Transcript, TranscriptHtml, Vocabulary, Vocabularies, Grammar.
 *
 * Inject `RtdbPath` = `category/` + parentPath + '/' + key khi thiếu.
 *
 * Input giả định: export full DB với top-level `category`, `config`, `ai_cache`, …
 * Output:
 * - database-list-british.json — nội dung nhánh `category/List` (không bọc thêm key List)
 *
 * Chạy: node tools/add_rtdb_list_node.mjs
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const INPUT = path.join(root, 'docs/rtdb_seed_british.json');
const OUTPUT_LIST = path.join(root, 'database-list-british.json');

const CATEGORY_ROOT = 'category';

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
    o.RtdbPath = rtdbPath.startsWith(`${CATEGORY_ROOT}/`)
      ? rtdbPath
      : `${CATEGORY_ROOT}/${rtdbPath}`;
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
    const parent = `${CATEGORY_ROOT}/List/HomePage/${k}`;
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

/**
 * @param {object} categoryNode — nội dung dưới top-level `category`
 */
function buildListTree(categoryNode) {
  const List = {};

  if (categoryNode.List?.HomePage) {
    List.HomePage = slimHomePage(categoryNode.List.HomePage);
  } else if (categoryNode.HomePage) {
    List.HomePage = slimHomePage(categoryNode.HomePage);
  }

  const skip = new Set(['HomePage', 'List', 'Grammar']);

  for (const key of Object.keys(categoryNode)) {
    if (skip.has(key)) continue;
    const val = categoryNode[key];
    if (isYearKeyedObject(val)) {
      List[key] = {};
      for (const [year, content] of Object.entries(val)) {
        List[key][year] = slimYearContent(
          content,
          `${CATEGORY_ROOT}/${key}/${year}`,
        );
      }
    } else if (Array.isArray(val)) {
      List[key] = slimYearContent(val, `${CATEGORY_ROOT}/${key}`);
    } else if (val && typeof val === 'object') {
      List[key] = slimYearContent(val, `${CATEGORY_ROOT}/${key}`);
    }
  }

  return List;
}

function main() {
  console.log('Reading', INPUT);
  if (!fs.existsSync(INPUT)) {
    console.error('Input not found:', INPUT);
    process.exit(1);
  }
  const raw = fs.readFileSync(INPUT, 'utf8');
  const data = JSON.parse(raw);
  const categoryNode = data.category ?? data;

  const listTree = buildListTree(categoryNode);

  fs.writeFileSync(OUTPUT_LIST, JSON.stringify(listTree, null, 2), 'utf8');
  console.log('Wrote', OUTPUT_LIST, '(import under category/List)');
}

main();
