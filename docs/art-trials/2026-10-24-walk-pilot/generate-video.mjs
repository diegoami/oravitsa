import {readFileSync, writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
const dir='C:/Users/diego/projects/oravitsa/docs/art-trials/2026-10-24-walk-pilot';
const args=['C:/Users/diego/AppData/Roaming/npm/node_modules/mmx-cli/dist/mmx.mjs','video','generate','--model','MiniMax-Hailuo-2.3','--image',`${dir}/reference/oravitsa-east-magenta.png`,'--prompt',readFileSync(`${dir}/prompt-video-01.txt`,'utf8'),'--async','--non-interactive','--quiet','--output','json'];
const result=spawnSync(process.execPath,args,{env:{...process.env,MMX_CONFIG_DIR:'\\\\wsl.localhost\\Ubuntu\\home\\diego\\projects\\mm_demos\\.secrets\\mmx'},encoding:'utf8',maxBuffer:1024*1024});
writeFileSync(`${dir}/generation-video-01.json`,result.stdout);
console.log(result.stdout); if(result.stderr)console.error(result.stderr);process.exitCode=result.status??1;

