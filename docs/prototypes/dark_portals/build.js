// node build.js — inline the engine and the rooms into one self-contained page.
const fs = require('fs');
const src = fs.readFileSync(__dirname + '/portals.src.html', 'utf8');
const out = src
  .replace('/*ENGINE*/', () => fs.readFileSync(__dirname + '/portal-engine.js', 'utf8'))
  .replace('/*ROOMS*/', () => fs.readFileSync(__dirname + '/portal-rooms.js', 'utf8'));
fs.writeFileSync(__dirname + '/portals.html', out);
console.log('wrote portals.html', out.length, 'bytes');
