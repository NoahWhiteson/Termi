// Optional artwork preparation; the app ships PNGs and needs no Node runtime.
// npm install --prefix /tmp/termi-icon-tools @resvg/resvg-js
// NODE_PATH=/tmp/termi-icon-tools/node_modules node scripts/render-tab-icons.cjs
const { Resvg } = require('@resvg/resvg-js');
const fs = require('node:fs');
const path = require('node:path');
const directory = path.resolve(__dirname, '../Sources/Termi/Resources/Icons');
for (const name of fs.readdirSync(directory).filter(name => name.endsWith('.svg'))) {
  const svg = fs.readFileSync(path.join(directory, name), 'utf8');
  const image = new Resvg(svg, { fitTo: { mode: 'width', value: 128 } }).render();
  fs.writeFileSync(path.join(directory, name.replace(/\.svg$/, '.png')), image.asPng());
}
