import {readFileSync, writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
const root = 'C:/Users/diego/projects/oravitsa';
const dir = path.join(root, 'docs/art-trials/2026-10-24-walk-pilot');
const prompt = readFileSync(path.join(dir, 'prompt-02.txt'), 'utf8');
const args = ['C:/Users/diego/AppData/Roaming/npm/node_modules/mmx-cli/dist/mmx.mjs', 'image', 'generate', '--prompt', prompt, '--subject-ref', `type=character,image=${dir}/reference/oravitsa-east.png`, '--width', '2048', '--height', '1536', '--n', '1', '--seed', '2401024', '--out', `${dir}/raw/east-8pose-03.jpg`, '--non-interactive', '--quiet', '--output', 'json'];
const dry = process.argv.includes('--dry-run');
if (dry) args.push('--dry-run');
const result = spawnSync(process.execPath, args, {cwd:root, env:{...process.env, MMX_CONFIG_DIR:'\\\\wsl.localhost\\Ubuntu\\home\\diego\\projects\\mm_demos\\.secrets\\mmx'}, encoding:'utf8', maxBuffer:10*1024*1024});
if (result.error) throw result.error;
writeFileSync(path.join(dir, dry ? 'request-03.json' : 'generation-03.json'), result.stdout);
if (dry) {
  const response = JSON.parse(result.stdout);
  function summarize(value) {
    if (typeof value === 'string' && value.length > 400) return value.startsWith('data:') ? '[reference image data omitted]' : `[text: ${value.length} characters]`;
    if (Array.isArray(value)) return value.map(summarize);
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,summarize(v)]));
    return value;
  }
  console.log(JSON.stringify(summarize(response), null, 2));
} else { console.log(result.stdout); }
if (result.stderr) console.error(result.stderr);
process.exitCode = result.status ?? 1;

