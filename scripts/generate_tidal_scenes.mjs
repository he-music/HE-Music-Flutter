#!/usr/bin/env node
// Original vector illustration; rebuild with Node, librsvg and ImageMagick.
import { mkdir, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
const output = 'assets/skins/tidal_sanctuary';
const source = '.artifacts/tidal-sanctuary/source';
await mkdir(`${output}/icons`, { recursive: true });
await mkdir(source, { recursive: true });
const width = 900, height = 1600;
function random(seed) {
  let value = seed;
  return () => ((value = (Math.imul(value, 1664525) + 1013904223) >>> 0) / 4294967296);
}
function scene(dark) {
  const rand = random(2718);
  const p = dark ? {
    top: '#19576D', middle: '#0B344B', bottom: '#061D32', light: '#82E1E0',
    sand: '#17495A', sandLow: '#0D2A40', ridge: '#256077', far: '#246579',
    rock: '#153E50', rockLow: '#082C40', kelp: '#206579', coral: '#769AB4',
    coralLow: '#315A7A', warm: '#BBA8CE', glow: '#87EDDE',
  } : {
    top: '#DEEFE1', middle: '#9BD3CF', bottom: '#438F9B', light: '#FFF9DD',
    sand: '#E4E7C8', sandLow: '#7DB3A9', ridge: '#B7D7C2', far: '#73AAA9',
    rock: '#779F99', rockLow: '#3B787F', kelp: '#3E918A', coral: '#D6A18C',
    coralLow: '#AF7F80', warm: '#F2CEAB', glow: '#FFF6D4',
  };
  const s = [`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 900 1600"><defs>
    <linearGradient id="water" x2=".25" y2="1"><stop stop-color="${p.top}"/><stop offset=".50" stop-color="${p.middle}"/><stop offset="1" stop-color="${p.bottom}"/></linearGradient>
    <radialGradient id="sun" cx=".3" cy="0" r="1"><stop stop-color="${p.light}" stop-opacity="${dark ? '.32' : '.65'}"/><stop offset=".75" stop-color="${p.light}" stop-opacity="0"/></radialGradient>
    <linearGradient id="ray" x2=".2" y2="1"><stop stop-color="${p.light}" stop-opacity=".32"/><stop offset="1" stop-color="${p.light}" stop-opacity="0"/></linearGradient>
    <linearGradient id="sand" x2="0" y2="1"><stop stop-color="${p.sand}"/><stop offset="1" stop-color="${p.sandLow}"/></linearGradient>
    <linearGradient id="rock" x2=".7" y2="1"><stop stop-color="${p.rock}"/><stop offset="1" stop-color="${p.rockLow}"/></linearGradient>
    <linearGradient id="coral" x2="0" y2="1"><stop stop-color="${p.warm}"/><stop offset=".4" stop-color="${p.coral}"/><stop offset="1" stop-color="${p.coralLow}"/></linearGradient>
    <radialGradient id="glow"><stop stop-color="${p.glow}" stop-opacity=".5"/><stop offset="1" stop-color="${p.glow}" stop-opacity="0"/></radialGradient>
    <filter id="soft"><feGaussianBlur stdDeviation="9"/></filter>
    </defs><rect width="900" height="1600" fill="url(#water)"/><ellipse cx="290" cy="80" rx="900" ry="1000" fill="url(#sun)"/>`];
  // Refracted sunlight converges at the surface, opens into soft shafts below.
  for (let i = 0; i < 6; i++) {
    const x = 60 + i * 88;
    s.push(`<path d="M${x} -40 L${x + 18} -40 L${x + 410} 1260 L${x + 120} 1260Z" fill="url(#ray)" opacity="${dark ? '.22' : '.42'}" filter="url(#soft)"/>`);
  }
  // Water ceiling: irregular ribbons, never a horizontal UI-like stripe.
  for (let i = 0; i < 16; i++) {
    const y = 10 + i * 8, x = -100 + rand() * 250;
    s.push(`<path d="M${x} ${y} Q180 ${y - 22} 390 ${y + 9} T1000 ${y - 9}" fill="none" stroke="${p.light}" stroke-width="${2 + rand() * 4}" opacity="${.06 + rand() * .12}"/>`);
  }
  // Distant reefs and a winding open sand channel anchor the perspective.
  s.push(`<path d="M0 1060 Q80 1020 160 1060 T340 1160 Q140 1180 0 1340Z" fill="${p.far}" opacity=".26"/>
    <path d="M900 980 Q830 1010 760 1050 T590 1170 Q770 1190 900 1350Z" fill="${p.far}" opacity=".32"/>
    <path d="M0 1390 Q180 1260 380 1285 Q490 1260 575 1220 Q660 1190 710 1240 Q550 1270 570 1310 Q720 1400 900 1380 L900 1600 H0Z" fill="url(#sand)"/>
    <path d="M0 1260 Q40 1150 135 1175 Q150 1100 210 1150 Q225 1235 305 1235 Q325 1280 250 1330 Q130 1370 0 1480Z" fill="${p.far}" opacity=".64"/>
    <path d="M900 1205 Q845 1100 800 1155 Q760 1090 730 1170 Q640 1190 650 1270 Q770 1280 900 1410Z" fill="${p.far}" opacity=".62"/>`);
  for (let i = 0; i < 21; i++) {
    const y = 1310 + i * 16;
    s.push(`<path d="M${190 + i * -9} ${y} Q450 ${y - 26} ${770 + i * 2} ${y + 12}" fill="none" stroke="${p.light}" stroke-width="${1 + i * .12}" opacity="${dark ? '.035' : '.15'}"/>`);
  }
  // Rounded reef ledges with lit upper contours.
  s.push(`<path d="M-40 1410 Q20 1330 105 1345 Q120 1270 197 1305 Q265 1275 300 1360 Q255 1460 370 1600 H-40Z" fill="url(#rock)"/>
    <path d="M940 1290 Q885 1240 845 1275 Q805 1210 754 1270 Q710 1275 720 1355 Q650 1425 600 1600 H940Z" fill="url(#rock)"/>
    <path d="M0 1380 Q60 1332 107 1355 Q140 1292 190 1318 Q250 1297 280 1355 M900 1290 Q860 1265 840 1290 Q800 1245 764 1282" stroke="${p.ridge}" stroke-width="9" fill="none" opacity=".7"/>`);
  function fan(x, y, scale, flip = 1) {
    s.push(`<g transform="translate(${x} ${y}) scale(${scale * flip} ${scale})" fill="none" stroke="url(#coral)" stroke-linecap="round">`);
    for (let branch = -4; branch <= 4; branch++) {
      const tx = branch * 24, ty = -130 - (4 - Math.abs(branch)) * 18;
      s.push(`<path d="M0 0 Q${tx * .2} -85 ${tx} ${ty}" stroke-width="${4 + (4 - Math.abs(branch)) * .3}"/>`);
      for (let twig = 1; twig <= 4; twig++) {
        const t = twig / 5, cx = tx * t * t, cy = ty * t;
        for (const direction of [-1, 1]) {
          s.push(`<path d="M${cx} ${cy} Q${cx + direction * 24} ${cy - 20} ${cx + direction * (22 + twig * 3)} ${cy - 45}" stroke-width="2.3"/>`);
        }
      }
    }
    s.push('</g>');
  }
  fan(178, 1430, 1.15); fan(764, 1400, .98, -1); fan(845, 1295, .55);
  function kelp(x, y, scale, flip) {
    s.push(`<g transform="translate(${x} ${y}) scale(${scale * flip} ${scale})" fill="${p.kelp}" opacity=".8">`);
    for (let blade = 0; blade < 5; blade++) {
      const dx = (blade - 2) * 19, h = 145 + blade % 3 * 48;
      s.push(`<path d="M0 10 Q${dx - 40} ${-h / 2} ${dx + 12} ${-h} Q${dx - 8} ${-h / 2} 8 10Z"/>`);
    }
    s.push('</g>');
  }
  kelp(60, 1430, 1.4, 1); kelp(850, 1505, 1.7, -1); kelp(305, 1540, .7, 1);
  // Tubular corals and anemones have different, related silhouettes.
  for (const [cx, cy, scale] of [[95, 1515, 1.1], [755, 1510, 1], [248, 1435, .58]]) {
    s.push(`<g transform="translate(${cx} ${cy}) scale(${scale})" stroke-linecap="round">`);
    for (let j = 0; j < 8; j++) {
      const x = (j - 3.5) * 12, h = 30 + rand() * 70;
      s.push(`<path d="M0 25 Q${x * .8} -8 ${x} ${-h}" stroke="${p.coralLow}" stroke-width="15" fill="none"/>
        <path d="M-2 25 Q${x * .8 - 3} -8 ${x - 3} ${-h}" stroke="${p.coral}" stroke-width="7" fill="none"/>
        <ellipse cx="${x}" cy="${-h}" rx="7.5" ry="4" fill="${p.warm}" opacity=".8"/>`);
    }
    s.push('</g>');
  }
  // Shell on the sand; fine fan ribs echo the functional icon family.
  s.push(`<g transform="translate(470 1510) rotate(-12)" fill="${p.warm}" opacity=".75"><path d="M0 16 Q-75 -20 -45 -43 Q-15 -74 0 -46 Q25 -74 52 -37 Q72 -8 0 16Z"/>`);
  for (let i = -3; i <= 3; i++) s.push(`<path d="M0 12 Q${i * 13} -10 ${i * 14} ${-45 + Math.abs(i) * 3}" stroke="${p.coralLow}" stroke-width="1.5" fill="none" opacity=".4"/>`);
  s.push('</g>');
  // Fish belong to the articulated Rive layer; no baked silhouettes remain.
  // Deterministic restrained grain, fine suspended matter and nocturnal glow.
  for (let i = 0; i < 360; i++) {
    const x = rand() * width, y = rand() * height;
    s.push(`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(.3 + rand() * 1.1).toFixed(1)}" fill="${p.light}" opacity="${(.025 + rand() * .09).toFixed(3)}"/>`);
  }
  if (dark) {
    for (let i = 0; i < 25; i++) {
      const x = 80 + rand() * 740, y = 1110 + rand() * 440;
      s.push(`<circle cx="${x}" cy="${y}" r="${8 + rand() * 15}" fill="url(#glow)"/><circle cx="${x}" cy="${y}" r="1.6" fill="${p.glow}" opacity=".8"/>`);
    }
  }
  s.push('</svg>');
  return s.join('\n');
}
for (const dark of [false, true]) {
  const name = dark ? 'dark' : 'light';
  const svg = `${source}/scene_${name}.svg`;
  const png = `${source}/scene_${name}.png`;
  await writeFile(svg, scene(dark));
  execFileSync('rsvg-convert', ['-o', png, svg]);
  execFileSync('magick', [png, '-strip', '-sampling-factor', '4:2:0', '-quality', '91', `${output}/wallpaper_${name}.jpg`]);
}
// These original icons share the scalloped shell and tidal curve vocabulary.
const icons = {
  home: '<path d="M4 13c0-5 3.5-9 8-9s8 4 8 9l-3 7H7z"/><path d="M12 5v14M8 7l2 12M16 7l-2 12M5 11l3 8M19 11l-3 8"/>',
  library: '<path d="M4 6v13M9 4v15M14 6v13M18 5l3 13M3 21c3-2 5 2 8 0s5 2 9 0"/>',
  person: '<circle cx="12" cy="8" r="3.5"/><path d="M4 20c0-5 3.5-7 8-7s8 2 8 7M8 20c2-1 3 1 5 0s3 0 3 0"/>',
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21M6 11c2-2 4 2 6 0s3 0 3 0"/>',
  play: '<path d="M7 4.5c0-1 1-1.5 2-.8l11 7c1 .6 1 2 0 2.6l-11 7c-1 .7-2 .2-2-.8z"/>',
  pause: '<path d="M7 5v14M16 5v14" stroke-width="3.4"/>',
  queue: '<path d="M3 6c3-2 5 2 8 0s5 2 8 0M3 12c3-2 5 2 8 0M3 18c3-2 5 2 8 0M16 11v9l6-4.5z"/>',
  heart: '<path d="M12 20S3 15 3 8.5C3 3 10 2 12 7c2-5 9-4 9 1.5C21 15 12 20 12 20z"/><path d="M6 11c2-1 4 2 6 0s4 1 6 0"/>',
  tide: '<path d="M3 8c3-3 6 3 9 0s6 3 9 0M3 13c3-3 6 3 9 0s6 3 9 0M3 18c3-3 6 3 9 0s6 3 9 0"/>',
};
for (const [name, paths] of Object.entries(icons)) {
  await writeFile(`${output}/icons/${name}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#438F9B" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">${paths}</svg>\n`);
}
execFileSync('magick', [`${output}/wallpaper_light.jpg`, `${output}/wallpaper_dark.jpg`, '+append', `${source}/day-night-atlas.jpg`]);
console.log('Tidal Sanctuary: original 900×1600 day/night scenes and nine SVG icons.');
