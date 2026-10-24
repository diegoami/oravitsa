// Execute the actual viewer draw function against measured opaque PNG bounds.
import {readFileSync,writeFileSync} from 'node:fs';
import vm from 'node:vm';
const root=new URL('../',import.meta.url);
const manifest=JSON.parse(readFileSync(new URL('build/fal-walk/render/manifest.json',root),'utf8'));
const html=readFileSync(new URL('art/imported_walk_review.html',root),'utf8');
const start=html.indexOf('function draw('),end=html.indexOf('\nfunction paint(',start);
if(start<0||end<0)throw new Error('Viewer draw function not found');
const draw=html.slice(start,end);
let cases=0,minimumMargin=Infinity,oldLayoutClips=0;
function check(bounds,source,pivot,scale,flip,zoom){
 let tx=0,ty=0,fx=1,fy=1;
 const canvas={width:440,height:300};
 const context={clearRect(){},save(){},restore(){},translate(x,y){tx+=x;ty+=y},scale(x,y){fx*=x;fy*=y},drawImage(image,sx,sy,sw,sh,dx,dy,dw,dh){
   for(const x of [bounds[0],bounds[0]+bounds[2]])for(const y of [bounds[1],bounds[1]+bounds[3]]){
     const px=tx+fx*(dx+(x-sx)/sw*dw),py=ty+fy*(dy+(y-sy)/sh*dh);
     const margin=Math.min(px,py,canvas.width-px,canvas.height-py);
     if(margin<29.99)throw new Error(`Clipped/insufficient margin: ${JSON.stringify({bounds,pivot,zoom,px,py,width:canvas.width,height:canvas.height})}`);
     minimumMargin=Math.min(minimumMargin,margin);
   }
 }};
 canvas.getContext=()=>context;
 vm.runInNewContext(draw+'\ndraw(canvas,image,source,pivot,scale,flip);',{manifest,canvas,image:{},source,pivot,scale,flip,$:()=>({value:zoom}),Math});
 const oldTop=(zoom===1?236:292)+(bounds[1]-source[1]-pivot[1])*scale*zoom;
 const oldBottom=oldTop+bounds[3]*scale*zoom;
 if(oldTop<0||oldBottom>300)oldLayoutClips++;
 cases++;
}
for(const zoom of [1,2]){
 for(const frames of Object.values(manifest.frame_bounds))for(const bounds of frames)check(bounds,[0,0,256,384],manifest.pivot,manifest.preview_scale,false,zoom);
 for(const ref of Object.values(manifest.reference_bounds))for(let i=0;i<4;i++)for(const flip of [false,true]){
   const width=ref.width/4,b=ref.frames[i];
   check([b[0]+i*width,b[1],b[2],b[3]],[i*width,0,width,ref.height],[width/2,ref.height/2+290],.2,flip,zoom);
 }
}
const report={cases,minimum_opaque_pixel_margin:minimumMargin,old_layout_clipped_cases:oldLayoutClips,zooms:[1,2]};
writeFileSync(new URL('build/fal-walk/layout-validation.json',root),JSON.stringify(report,null,2));
console.log(report);
