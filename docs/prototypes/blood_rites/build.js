// node build.js — inline the engines and the rooms into one self-contained page.
const fs = require('fs');
const read = (f) => fs.readFileSync(__dirname + '/' + f, 'utf8');
const out = read('rites.src.html')
  .replace('/*EARTH*/', () => read('earth-engine.js'))
  .replace('/*WATER*/', () => read('water-engine.js'))
  .replace('/*HUB*/', () => read('hub-engine.js'))
  .replace('/*FIRE*/', () => read('fire-engine.js'))
  .replace('/*AIR*/', () => read('air-engine.js'))
  .replace('/*ROOMS*/', () => read('rites-rooms.js'));
fs.writeFileSync(__dirname + '/rites.html', out);
console.log('wrote rites.html', out.length, 'bytes');
