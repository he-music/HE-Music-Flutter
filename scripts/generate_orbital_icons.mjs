#!/usr/bin/env node
// Original 24px orbital icon family. No bitmap or external icon inputs.
import { mkdir, writeFile } from 'node:fs/promises';
const root = 'assets/skins/orbital_observatory/icons';
const color = '#6FB7CE';
const paths = {
  home: '<path d="m4.5 10 7.5-6 7.5 6v8.5a1 1 0 0 1-1 1h-4v-6h-5v6h-4a1 1 0 0 1-1-1Z"/><path d="M2 17c1.8 4 13 5.3 19-.4" stroke-opacity=".6"/>',
  library: '<rect x="4" y="4" width="4" height="15" rx="1"/><rect x="10" y="4" width="4" height="15" rx="1"/><path d="m17 4 3.5 14.5M2 21h19"/>',
  person: '<circle cx="12" cy="8" r="3.3"/><path d="M5.5 20v-2a6.5 6.5 0 0 1 13 0v2M2.5 12c-1 5 4 10.5 11 10"/>',
  search: '<circle cx="10.5" cy="10.5" r="6.3"/><path d="m15.2 15.2 5.2 5.2M6.5 10.5a4 4 0 0 1 4-4"/>',
  play: '<path d="m10 7 7.5 5-7.5 5Z" fill="#6FB7CE" stroke-linejoin="round"/><path d="M18.8 4.8a9.6 9.6 0 1 0 2.8 6.8" stroke-opacity=".7"/>',
  pause: '<path d="M9 7v10M15 7v10" stroke-width="2.5"/><path d="M18.8 4.8a9.6 9.6 0 1 0 2.8 6.8" stroke-opacity=".7"/>',
  queue: '<path d="M3 5h17M3 10h12M3 15h8M17.5 12v7"/><ellipse cx="15.5" cy="19" rx="2" ry="1.5"/><path d="m17.5 12 3-1"/>',
  heart: '<path d="M20.1 5.4a4.8 4.8 0 0 0-6.8 0L12 6.7l-1.3-1.3a4.8 4.8 0 0 0-6.8 6.8L12 20l8.1-7.8a4.8 4.8 0 0 0 0-6.8Z"/>',
  orbit: '<circle cx="12" cy="12" r="6"/><ellipse cx="12" cy="12" rx="11" ry="4" transform="rotate(-30 12 12)"/><circle cx="19" cy="5" r="1.3" fill="#6FB7CE" stroke="none"/>',
  download: '<path d="M12 3v12m-4-4 4 4 4-4M4 17v2a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-2"/>',
  more: '<circle cx="5" cy="12" r="1" fill="#6FB7CE"/><circle cx="12" cy="12" r="1" fill="#6FB7CE"/><circle cx="19" cy="12" r="1" fill="#6FB7CE"/>',
};
await mkdir(root, { recursive: true });
for (const [name, body] of Object.entries(paths)) {
  await writeFile(`${root}/${name}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${body}</svg>\n`);
}
console.log(`Generated ${Object.keys(paths).length} original orbital SVG icons.`);
