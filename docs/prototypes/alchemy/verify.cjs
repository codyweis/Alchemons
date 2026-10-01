// Headless checks of the actual simulation, with only browser surfaces stubbed.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, 'simulation.js'), 'utf8');
const canonical = JSON.parse(fs.readFileSync(path.join(__dirname, '../../../assets/data/alchemons_element_recipes.json'), 'utf8'));
const nodes = new Map();
const node = () => ({style:{setProperty(){}},classList:{toggle(){}},dataset:{},setAttribute(){},addEventListener(){},append(){},remove(){},getContext(){return {createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)})}}});
const context = {console,assert,canonical,performance:{now:()=>0},requestAnimationFrame(){},ResizeObserver:class{observe(){}},document:{querySelector:s=>{if(!nodes.has(s))nodes.set(s,node());return nodes.get(s)},querySelectorAll:()=>[],createElement:node},window:{addEventListener(){}},fetch:async()=>({ok:true,json:async()=>canonical})};
vm.runInNewContext(`(async()=>{${source}\n
assert.equal(ready,true);
let checked=0;
for(const [pair,outputs] of Object.entries(canonical.recipes)){
 const names=pair.toLowerCase().split('+');if(names.length!==2)continue;
 const expected=byName[Object.entries(outputs).sort((a,b)=>b[1]-a[1])[0][0].toLowerCase()].id;
 for(const reverse of [false,true])for(let trial=0;trial<30;trial++){
  grid.fill(0);age.fill(0);const ids=names.map(n=>byName[n].id);if(reverse)ids.reverse();
  const i=50*W+50;grid[i]=ids[0];grid[i+1]=ids[1];
  assert.equal(react(i,i+1,50,50),true,pair);assert.equal(grid[i],expected,pair);assert.equal(grid[i+1],0);
 }checked++;
}
// Unlisted pairs survive contact unchanged.
grid.fill(0);grid[1000]=byName.blood.id;grid[1001]=byName.earth.id;
assert.equal(react(1000,1001,104,4),false);assert.equal(grid[1000],byName.blood.id);
// Each starter experiment sustains actual reactions and finite material IDs.
for(const name of Object.keys(scenes)){loadScene(name);for(let frame=0;frame<240;frame++)step();assert.ok(totalReactions>0,name);assert.ok(grid.every(id=>id<=17));}
clear();assert.equal(grid.some(Boolean),false);assert.equal(feeding,false);
console.log('PASS: '+checked+' recipes, 60 deterministic contacts each; unknown pairs; three live scenes; clear stops feed.');
})()`,context).catch(error=>{console.error(error);process.exitCode=1});
