// Use the dominant product from each canonical recipe; reactions are deterministic.
const $ = s => document.querySelector(s);
const definitions = [
  ['Fire','#f6ac70','gas',.12,'Fi','A restless heat. Rises through matter and leaves a faint amber afterimage.'],
  ['Water','#70a9bd','liquid',1,'Wa','Seeks the lowest point. Carries motion across the surface in quiet waves.'],
  ['Earth','#b19c78','powder',2,'Ea','Accumulates in patient strata. The foundation of mineral transformations.'],
  ['Air','#a2c9c2','gas',.02,'Ai','Almost invisible movement. Reveals itself through pale, wandering currents.'],
  ['Steam','#c2d4cf','gas',.05,'St','A cloud of suspended light. Rises, curls, and gathers beneath the glass.'],
  ['Lava','#ea8055','liquid',1.7,'La','A slow mineral river. Heat glows beneath a darkening surface.'],
  ['Lightning','#c1bbef','gas',.04,'Li','A restless electrical trace. Turns contact with earth into crystalline matter.'],
  ['Mud','#8e8d6b','liquid',1.8,'Mu','Heavy, reluctant flow. Holds its shape before yielding to gravity.'],
  ['Ice','#a2d4d8','solid',2,'Ic','A translucent stillness. Suspends the chamber’s motion in pale blue facets.'],
  ['Dust','#c1ac81','powder',1.4,'Du','Fine mineral grains. Falls in delicate curtains and gathers in soft slopes.'],
  ['Crystal','#b9cbaa','solid',3,'Cr','An ordered residue. Records the geometry of the encounter that formed it.'],
  ['Plant','#86a77a','solid',1.4,'Pl','A quiet green structure. Rooted matter born from earth and light.'],
  ['Poison','#b0bd72','liquid',1.2,'Po','An olive iridescence. Flows like water with an unfamiliar inner life.'],
  ['Spirit','#a5a3c3','gas',.01,'Sp','Barely there. Its lilac shimmer describes the shape of unseen currents.'],
  ['Dark','#767b97','liquid',1.1,'Da','Dense, blue-black matter. Visible at its edges, elusive at its center.'],
  ['Light','#eee0ac','gas',.03,'Lu','A warm suspension. Drifts upward in fine threads of illumination.'],
  ['Blood','#b86a71','liquid',1.5,'Bl','A rhythmic red suspension. Born where light and darkness make contact.']
];
const elements = definitions.map(([name,color,phase,density,symbol,description],i)=>({id:i+1,name,color,phase,density,symbol,description,rgb:color.match(/\w\w/g).map(v=>parseInt(v,16))}));
const byName = Object.fromEntries(elements.map(e=>[e.name.toLowerCase(),e]));
const lookup = [null,...elements];
const W=224,H=150,N=W*H;
let grid=new Uint8Array(N), age=new Uint16Array(N), updated=new Uint32Array(N), tick=0, recipes=new Map(), totalReactions=0;
let selected=byName.water, tool='pour', radius=5, paused=false, scene='vapor', ready=false, sound=false, feeding=true;
let pointer={x:0,y:0,down:false,inside:false,shift:false};
let flashes=[], traces=[], journal=[], lastJournal=0, lastSound=0, lastHud=0, audio;
const canvas=$('#chamber'), ctx=canvas.getContext('2d'), buffer=document.createElement('canvas');
buffer.width=W;buffer.height=H;const bctx=buffer.getContext('2d');
const pixels=bctx.createImageData(W,H);
let viewW=1,viewH=1;
new ResizeObserver(()=>{const r=canvas.getBoundingClientRect();viewW=r.width;viewH=r.height;const dpr=Math.min(devicePixelRatio||1,2);canvas.width=Math.round(viewW*dpr);canvas.height=Math.round(viewH*dpr);ctx.setTransform(dpr,0,0,dpr,0,0)}).observe(canvas);
const key=(a,b)=>a<b?`${a}:${b}`:`${b}:${a}`;
for(const e of elements){const btn=document.createElement('button');btn.className='element';btn.style.setProperty('--color',e.color);btn.innerHTML=`<span class="swatch"></span>${e.name}`;btn.setAttribute('aria-pressed','false');btn.addEventListener('click',()=>select(e));btn.dataset.id=e.id;$('#palette').append(btn)}
function select(e){selected=e;document.querySelectorAll('.element').forEach(b=>{const active=+b.dataset.id===e.id;b.classList.toggle('active',active);b.setAttribute('aria-pressed',active)});$('#selected-name').textContent=e.name;$('#selected-symbol').textContent=e.symbol;$('#selected-symbol').style.color=e.color;$('#selected-description').textContent=e.description;updateHint();if(ready){const r=[...recipes.values()].find(r=>r.inputs.includes(e.id));if(r)showRecipe(r)}}
function updateHint(){$('#canvas-hint').textContent=tool==='pour'?`DRAG TO INTRODUCE ${selected.name.toUpperCase()}`:tool==='stir'?'DRAG TO DISTURB THE CURRENT':'DRAG TO REMOVE MATTER'}
function setTool(t){tool=t;document.querySelectorAll('.tool').forEach(b=>{const active=b.dataset.tool===t;b.classList.toggle('active',active);b.setAttribute('aria-pressed',active)});updateHint()}
function showRecipe(r){$('#recipe-title').textContent=r.inputs.map(i=>lookup[i].name).join(' + ');$('#recipe-results').innerHTML=r.outcomes.map(o=>`<div class="result-row"><span>${lookup[o.id].name}</span><em>ON CONTACT</em><div class="result-bar"><div style="width:100%;background:${lookup[o.id].color}"></div></div></div>`).join('')}
function put(x,y,id){x=Math.round(x);y=Math.round(y);if(x<2||x>=W-2||y<2||y>=H-4)return;const i=y*W+x;if(!grid[i]){grid[i]=id;age[i]=0;updated[i]=tick}}
function patch(cx,cy,rx,ry,name,fill=1){for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++)if(x*x/(rx*rx)+y*y/(ry*ry)<1&&Math.random()<fill)put(cx+x,cy+y,byName[name].id)}
function clear(){feeding=false;updateFeed();grid.fill(0);age.fill(0);updated.fill(0);flashes=[];traces=[];journal=[];totalReactions=0;$('#journal').innerHTML='<p class="empty-note">Every transformation leaves a trace.</p>';$('#reaction-count').textContent='000';$('#particle-count').textContent='0 PARTICLES'}
const scenes={
 vapor:{note:'Steam rises. Water settles. Bring fire beneath a pool and watch the chamber begin to breathe.',pair:['fire','water'],selected:'water',seed(){patch(112,130,83,12,'water');patch(108,113,32,7,'fire',.48);patch(60,80,20,11,'steam',.18);patch(167,99,8,5,'earth',.8)}},
 mineral:{note:'A storm can leave something permanent. Draw lightning through falling earth; crystal stays where the encounter happened.',pair:['earth','lightning'],selected:'lightning',seed(){patch(105,129,68,13,'earth');patch(107,115,62,7,'lightning',.65);patch(90,74,17,16,'earth',.55);patch(120,88,25,7,'lightning',.3)}},
 eclipse:{note:'Where light meets darkness, blood takes form. Stir the boundary to bring the two together.',pair:['dark','light'],selected:'light',seed(){patch(111,128,67,15,'dark');patch(110,117,57,10,'light',.7);patch(145,78,16,19,'spirit',.13)}}
};
function loadScene(name){if(!ready)return;scene=name;clear();scenes[name].seed();feeding=true;updateFeed();select(byName[scenes[name].selected]);showRecipe(recipes.get(key(...scenes[name].pair.map(n=>byName[n].id))));$('#field-note').textContent=scenes[name].note;document.querySelectorAll('.study').forEach(b=>b.classList.toggle('selected',b.dataset.scene===name))}
function swap(i,j){const id=grid[i],a=age[i];grid[i]=grid[j];age[i]=age[j];grid[j]=id;age[j]=a;updated[i]=updated[j]=tick}
function canMove(i,j){if(j<2*W||j>=(H-4)*W||j%W<2||j%W>=W-2)return false;if(!grid[j])return true;const a=lookup[grid[i]],b=lookup[grid[j]];return b.phase!=='solid'&&a.phase!=='solid'&&a.density>b.density+.12&&j>i&&Math.random()<.35}
function move(i,j){if(canMove(i,j)){swap(i,j);return true}return false}
function react(i,j,x,y){if(!grid[j]||grid[i]===grid[j])return false;const r=recipes.get(key(grid[i],grid[j]));if(!r)return false;const out=r.outcomes[0];grid[i]=out.id;grid[j]=0;age[i]=0;updated[i]=updated[j]=tick;totalReactions++;const e=lookup[out.id];if(flashes.length<100)flashes.push({x,y,life:1,color:e.color});const now=performance.now();if(now-lastJournal>600){lastJournal=now;journal.unshift({r,e});journal=journal.slice(0,5);$('#journal').innerHTML=journal.map(v=>`<div class="journal-entry"><span>${v.r.inputs.map(id=>lookup[id].symbol).join(' + ')} <span>→</span></span><b>${v.e.name}</b></div>`).join('');$('#reaction-count').textContent=String(totalReactions).padStart(3,'0');showRecipe(r);chime(e.id)}return true}
function updateFeed(){$('#feed').textContent=feeding?'Feed on':'Feed off';$('#feed').setAttribute('aria-pressed',feeding)}
$('#feed').addEventListener('click',()=>{feeding=!feeding;updateFeed()});
function feed(){if(!feeding||tick%3)return;const jitter=()=>Math.random()*8-4;
 if(scene==='vapor'){patch(105+jitter(),28,5,3,'water',.65);patch(114+jitter(),124,9,5,'fire',.7)}
 if(scene==='mineral'){patch(103+jitter(),25,5,3,'earth',.65);patch(118+jitter(),122,8,4,'lightning',.65)}
 if(scene==='eclipse'){patch(105+jitter(),28,5,3,'dark',.65);patch(117+jitter(),125,9,5,'light',.65)}
}
function step(){tick++;feed();if(pointer.down)paint();const fromLeft=tick%2===0;
 for(let y=H-5;y>=2;y--)for(let col=2;col<W-2;col++){const x=fromLeft?col:W-1-col,i=y*W+x,id=grid[i];if(!id||updated[i]===tick)continue;age[i]=Math.min(age[i]+1,65000);const e=lookup[id];
 const dir=Math.random()<.5?-1:1;let reacted=false;for(const offset of [dir,-dir,W,-W]){if(react(i,i+offset,x,y)){reacted=true;break}}if(reacted)continue;
 if(e.phase==='solid'){updated[i]=tick;continue}
 if(e.phase==='gas'){
   if(y<7&&Math.random()<.12){grid[i]=0;continue}const wind=Math.sin(y*.075+tick*.012)*1.5+Math.cos(x*.043-tick*.007);const dx=Math.random()<.7?Math.sign(wind):dir;
   if(Math.random()<.65&&(move(i,i-W+dx)||move(i,i+dx)))continue;
   if(age[i]>900&&Math.random()<.015){grid[i]=0;continue}
 }else{
   if((id===byName.lava.id||id===byName.mud.id)&&Math.random()<.45)continue;
   if(move(i,i+W)||move(i,i+W+dir)||move(i,i+W-dir))continue;
   if(e.phase==='liquid'){if(move(i,i+dir)||move(i,i-dir))continue}
 }updated[i]=tick;
 }
 for(const f of flashes)f.life-=.035;flashes=flashes.filter(f=>f.life>0);
 for(const t of traces)t.life-=.03;traces=traces.filter(t=>t.life>0);
}
function paint(){const cx=Math.round(pointer.x),cy=Math.round(pointer.y),mode=pointer.shift?'stir':tool;
 for(let dy=-radius;dy<=radius;dy++)for(let dx=-radius;dx<=radius;dx++){if(dx*dx+dy*dy>radius*radius)continue;const x=cx+dx,y=cy+dy;if(x<2||x>=W-2||y<2||y>=H-4)continue;const i=y*W+x;
 if(mode==='erase'){grid[i]=0;continue}
 if(mode==='stir'){if(grid[i]&&Math.random()<.4){const nx=x+Math.round(-dy*.55+(Math.random()-.5)*3),ny=y+Math.round(dx*.55-1);if(nx>=2&&nx<W-2&&ny>=2&&ny<H-4)swap(i,ny*W+nx)}continue}
 if(Math.random()<.16)put(x,y,selected.id);
 }
 if(mode==='stir'&&traces.length<70)traces.push({x:cx,y:cy,life:1});
}
function render(time){ctx.clearRect(0,0,viewW,viewH);const sx=viewW/W,sy=viewH/H;const d=pixels.data;d.fill(0);let count=0;
 for(let i=0;i<N;i++){const id=grid[i];if(!id)continue;count++;const e=lookup[id],x=i%W,y=(i/W)|0;let shade=.79+.1*Math.sin(x*127.1+y*311.7);if(e.phase==='gas')shade=.65+.25*Math.sin(x*.2+y*.17+time*.0008);if(id===17)shade=.77+.22*Math.sin(time*.003+y*.1);const p=i*4;d[p]=e.rgb[0]*shade;d[p+1]=e.rgb[1]*shade;d[p+2]=e.rgb[2]*shade;d[p+3]=e.phase==='gas'?100+Math.sin(x*.4+y*.3+time*.001)*50:230;
 // Surface glints articulate liquids; crystalline solids carry facets.
 if(e.phase==='liquid'&&!grid[i-W]){d[p]=Math.min(255,e.rgb[0]*1.2);d[p+1]=Math.min(255,e.rgb[1]*1.2);d[p+2]=Math.min(255,e.rgb[2]*1.2);d[p+3]=245}
 if(e.phase==='solid'&&(x+y)%6===0){d[p+3]=150}
 }
 bctx.putImageData(pixels,0,0);ctx.save();ctx.globalAlpha=.65;ctx.filter='blur(10px)';ctx.globalCompositeOperation='screen';ctx.drawImage(buffer,0,0,viewW,viewH);ctx.restore();ctx.imageSmoothingEnabled=true;ctx.drawImage(buffer,0,0,viewW,viewH);
 // Fine advected filaments distinguish the airy phases from settled matter.
 ctx.save();ctx.globalCompositeOperation='screen';ctx.lineWidth=.7;
 for(let i=0;i<N;i+=7){const id=grid[i];if(!id||lookup[id].phase!=='gas')continue;const e=lookup[id],x=i%W,y=(i/W)|0;
 ctx.strokeStyle=e.color+'35';const drift=Math.sin(y*.075+tick*.012)*4+Math.cos(x*.043-tick*.007)*3;
 ctx.beginPath();ctx.moveTo(x*sx,y*sy);ctx.quadraticCurveTo((x+drift)*sx,(y-2)*sy,(x+drift*.7)*sx,(y-5)*sy);ctx.stroke()}
 ctx.restore();
 // Subtle ruled glass and a curved vessel floor.
 ctx.strokeStyle='#73918112';ctx.lineWidth=1;for(let x=32;x<W-20;x+=32){ctx.beginPath();ctx.moveTo(x*sx,18);ctx.lineTo(x*sx,viewH-35);ctx.stroke()}ctx.strokeStyle='#9aaf9028';ctx.beginPath();ctx.moveTo(20,(H-3)*sy);ctx.lineTo(viewW-20,(H-3)*sy);ctx.stroke();
 for(const f of flashes){const r=(2+(1-f.life)*10)*sx;const g=ctx.createRadialGradient(f.x*sx,f.y*sy,0,f.x*sx,f.y*sy,r);g.addColorStop(0,f.color+Math.round(f.life*90).toString(16).padStart(2,'0'));g.addColorStop(1,f.color+'00');ctx.fillStyle=g;ctx.fillRect(f.x*sx-r,f.y*sy-r,2*r,2*r)}
 for(const t of traces){ctx.strokeStyle=`rgba(176,200,186,${t.life*.13})`;ctx.beginPath();ctx.ellipse(t.x*sx,t.y*sy,(1-t.life)*30+10,(1-t.life)*13+5,-.4,0,Math.PI*1.7);ctx.stroke()}
 if(pointer.inside){ctx.strokeStyle=tool==='erase'?'#d5a89b88':'#c7d7b85c';ctx.lineWidth=1;ctx.beginPath();ctx.ellipse(pointer.x*sx,pointer.y*sy,radius*sx,radius*sy,0,0,Math.PI*2);ctx.stroke();ctx.fillStyle='#d3dfc59c';ctx.fillRect(pointer.x*sx-.7,pointer.y*sy-.7,1.4,1.4)}
 if(time-lastHud>200){lastHud=time;$('#particle-count').textContent=`${count.toLocaleString()} PARTICLES`;$('#reaction-count').textContent=String(totalReactions).padStart(3,'0')}
}
let last=0,accumulator=0;
function frame(time){const elapsed=Math.min(time-last,80);last=time;if(ready&&!paused){accumulator+=elapsed;while(accumulator>=1000/30){step();accumulator-=1000/30}}else if(ready&&paused&&pointer.down)paint();render(time);requestAnimationFrame(frame)}
function locate(ev){const r=canvas.getBoundingClientRect();pointer.x=(ev.clientX-r.left)/r.width*W;pointer.y=(ev.clientY-r.top)/r.height*H;pointer.shift=ev.shiftKey;pointer.inside=true}
canvas.addEventListener('pointerdown',e=>{if(!ready)return;locate(e);pointer.down=true;paint();canvas.setPointerCapture(e.pointerId);canvas.focus();if(audio?.state==='suspended')audio.resume()});
canvas.addEventListener('pointermove',e=>{const oldX=pointer.x,oldY=pointer.y;locate(e);if(!pointer.down||!ready)return;const endX=pointer.x,endY=pointer.y,steps=Math.min(100,Math.max(1,Math.ceil(Math.hypot(endX-oldX,endY-oldY)/Math.max(1,radius*.5))));for(let n=1;n<=steps;n++){pointer.x=oldX+(endX-oldX)*n/steps;pointer.y=oldY+(endY-oldY)*n/steps;paint()}});canvas.addEventListener('pointerup',()=>pointer.down=false);canvas.addEventListener('pointercancel',()=>pointer.down=false);canvas.addEventListener('lostpointercapture',()=>pointer.down=false);canvas.addEventListener('pointerleave',()=>pointer.inside=false);window.addEventListener('blur',()=>pointer.down=false);canvas.addEventListener('contextmenu',e=>e.preventDefault());
function togglePause(){paused=!paused;$('#pause').textContent=paused?'Resume':'Pause';$('#pause').setAttribute('aria-pressed',paused);$('#state-label').textContent=paused?'SYSTEM AT REST':'SYSTEM ACTIVE'}
$('#pause').addEventListener('click',togglePause);$('#clear').addEventListener('click',clear);$('#reset').addEventListener('click',()=>loadScene(scene));$('#brush').addEventListener('input',e=>radius=+e.target.value);document.querySelectorAll('.tool').forEach(b=>b.addEventListener('click',()=>setTool(b.dataset.tool)));document.querySelectorAll('.study').forEach(b=>b.addEventListener('click',()=>loadScene(b.dataset.scene)));
window.addEventListener('keydown',e=>{if(['INPUT','BUTTON','A'].includes(e.target.tagName))return;if(e.code==='Space'){e.preventDefault();togglePause()}if(e.key==='1')setTool('pour');if(e.key==='2')setTool('stir');if(e.key==='3')setTool('erase');if(e.key==='['||e.key===']'){radius=Math.max(2,Math.min(12,radius+(e.key===']'?1:-1)));$('#brush').value=radius}if(e.key==='Shift')pointer.shift=true});window.addEventListener('keyup',e=>{if(e.key==='Shift')pointer.shift=false});
$('#sound').addEventListener('click',()=>{sound=!sound;if(sound){audio??=new (window.AudioContext||window.webkitAudioContext)();audio.resume()}$('#sound').textContent=sound?'Sound on':'Sound off';$('#sound').setAttribute('aria-pressed',sound)});
function chime(id){if(!sound||!audio||performance.now()-lastSound<240)return;lastSound=performance.now();const o=audio.createOscillator(),g=audio.createGain();o.type='sine';o.frequency.value=[130.81,146.83,164.81,196,220,261.63][id%6];g.gain.setValueAtTime(0,audio.currentTime);g.gain.linearRampToValueAtTime(.035,audio.currentTime+.03);g.gain.exponentialRampToValueAtTime(.001,audio.currentTime+1.4);o.connect(g);g.connect(audio.destination);o.start();o.stop(audio.currentTime+1.5)}
select(selected);requestAnimationFrame(frame);
try{const response=await fetch('../../../assets/data/alchemons_element_recipes.json');if(!response.ok)throw new Error(`Recipes returned ${response.status}`);const data=await response.json();for(const [pair,result] of Object.entries(data.recipes)){const names=pair.toLowerCase().split('+');if(names.length!==2)continue;const inputs=names.map(n=>byName[n]?.id);const outcomes=Object.entries(result).map(([name,weight])=>({id:byName[name.toLowerCase()]?.id,weight}));if(inputs.some(id=>!id)||outcomes.some(o=>!o.id)||outcomes.reduce((a,o)=>a+o.weight,0)!==100)throw new Error(`Invalid recipe: ${pair}`);const product=outcomes.reduce((best,o)=>o.weight>best.weight?o:best);recipes.set(key(...inputs),{inputs,outcomes:[{id:product.id,weight:100}]})}ready=true;$('#loading').remove();loadScene(scene)}catch(error){$('#loading').textContent='The recipe library could not be loaded. Serve this page from the repository root, then reload.';console.error(error)}
// Read-only inspection for prototype verification.
window.materia={snapshot:()=>({ready,paused,feeding,tool,selected:selected.name,recipes:recipes.size,reactions:totalReactions,particles:grid.reduce((n,id)=>n+(id?1:0),0),elements:Object.fromEntries(elements.map(e=>[e.name,grid.reduce((n,id)=>n+(id===e.id?1:0),0)]))})};
