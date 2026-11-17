#!/usr/bin/env node
// npm install --prefix .artifacts/rive-tools rive-mcp-server@0.3.0 --ignore-scripts
// node scripts/generate_forest_ambient.mjs
// 仅制作资源时使用；生成器及其依赖不进入 Flutter 应用。
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const generatorDirectory = resolve(
  process.env.RIVE_GENERATOR_DIR ?? '.artifacts/rive-tools/node_modules/rive-mcp-server',
);
const { createRiv } = await import(pathToFileURL(resolve(generatorDirectory, 'dist/rivWriter.js')));
const { importSvg } = await import(pathToFileURL(resolve(generatorDirectory, 'dist/svgImport.js')));
const width = 768;
const height = 1024;
const fps = 30;
const duration = 1080;
const lights = [
  [.08, .34], [.88, .27], [.19, .71], [.75, .61], [.34, .82],
  [.92, .78], [.12, .53], [.69, .39], [.48, .68], [.84, .87],
  [.29, .46], [.58, .91], [.05, .87], [.95, .46],
];

function cycle(target, property, base, amplitude, period, phase = 0) {
  const keyframes = [];
  for (let frame = 0; frame <= duration; frame += period / 8) {
    keyframes.push({
      frame: Math.round(frame),
      value: base + amplitude * Math.sin(frame / period * Math.PI * 2 + phase),
      ...(frame > 0 ? { easing: 'ease-in-out' } : {}),
    });
  }
  return { target, property, keyframes };
}

function fern(id, color) {
  const length = 150;
  const paths = [
    `<path d="M0 0 Q${length * .15} ${-length * .5} ${length * .08} ${-length}" fill="none" stroke="${color}" stroke-opacity=".65" stroke-width="1"/>`,
  ];
  for (let i = 1; i <= 7; i++) {
    const y = -length * i / 8;
    const x = length * .08 * Math.sin(i / 8 * Math.PI);
    const leaf = length * .24 * (1 - i / 10);
    for (const side of [-1, 1]) {
      paths.push(`<path d="M${x} ${y} Q${x + side * leaf * .75} ${y + leaf * .1} ${x + side * leaf} ${y - leaf * .7} Q${x + side * leaf * .25} ${y - leaf * .9} ${x} ${y}Z" fill="${color}" fill-opacity=".65"/>`);
    }
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="768" height="1024" viewBox="0 0 768 1024">${paths.join('')}</svg>`;
  return importSvg(svg, { idPrefix: id }).shapes;
}

function artboard(dark) {
  const groups = [];
  const shapes = [];
  const tracks = [];
  const mistColor = dark ? '#8ABDA8' : '#FCF5D1';
  for (let i = 0; i < 2; i++) {
    const id = `mist_${i}`;
    const x = width / 2;
    const y = height * (.49 + i * .24);
    shapes.push({
      id, type: 'ellipse', x, y, width: width * 1.4, height: 150,
      opacity: dark ? .18 : .20,
      fill: { gradient: {
        type: 'linear', start: { x: 0, y: -75 }, end: { x: 0, y: 75 },
        stops: [
          { color: '#008ABDA8', position: 0 },
          { color: mistColor, position: .5 },
          { color: '#008ABDA8', position: 1 },
        ],
      } },
    });
    tracks.push(cycle(id, 'x', x, width * .12, 540, i * 2));
    tracks.push(cycle(id, 'y', y, height * .018, 540, i + Math.PI / 2));
  }

  // BoxFit.cover 会裁掉竖屏两侧；把萤光与近景锚点收进手机可见区域。
  const count = dark ? lights.length : 7;
  const lightColor = dark ? '#F5E6A0' : '#FFF4C9';
  for (let i = 0; i < count; i++) {
    const id = `firefly_${i}`;
    const [px, py] = lights[i];
    const seed = i * 2.399;
    groups.push({ id, x: (.22 + px * .56) * width, y: py * height, opacity: .62 });
    shapes.push({
      id: `${id}_glow`, parent: id, type: 'ellipse',
      width: 36, height: 36, opacity: .50,
      fill: { gradient: {
        type: 'radial', start: { x: 0, y: 0 }, end: { x: 18, y: 0 },
        stops: [{ color: lightColor, position: 0 }, { color: '#00F5E6A0', position: 1 }],
      } },
    });
    shapes.push({
      id: `${id}_core`, parent: id, type: 'ellipse',
      width: i % 2 === 0 ? 4.5 : 3, height: i % 2 === 0 ? 4.5 : 3,
      fill: { color: lightColor },
    });
    tracks.push(cycle(id, 'x', (.22 + px * .56) * width, 34, 360, seed));
    tracks.push(cycle(id, 'y', py * height, 22, 540, seed + Math.PI / 2));
    tracks.push(cycle(id, 'opacity', .62, .34, 270, seed));
  }

  for (let i = 0; i < 2; i++) {
    const id = `fern_${i}`;
    groups.push({
      id, x: width * (i === 0 ? .21 : .79), y: height * (i === 0 ? .90 : .96),
      rotation: i === 0 ? -20 : 24, scaleX: i === 0 ? 1 : -.85,
      scaleY: i === 0 ? 1 : .85,
    });
    shapes.push(...fern(`${id}_leaf_`, dark ? '#0B2928' : '#365D3F')
      .map((shape) => ({ ...shape, parent: id })));
    tracks.push(cycle(id, 'rotation', i === 0 ? -20 : 24, 2.0, 1080, i));
  }

  return {
    name: dark ? 'ForestNight' : 'ForestDay', width, height,
    groups, shapes,
    animations: [{ name: 'forest_ambient', fps, duration, loop: 'loop', tracks }],
    stateMachine: {
      name: 'AmbientLoop', inputs: [],
      states: [{ name: 'forest', animation: 'forest_ambient' }],
      transitions: [{ from: 'entry', to: 'forest' }],
    },
  };
}

const spec = { artboards: [artboard(false), artboard(true)] };
const { bytes, warnings } = createRiv(spec);
if (warnings.length) throw new Error(warnings.join('\n'));
await mkdir('assets/skins/forest_sanctuary', { recursive: true });
await writeFile('assets/skins/forest_sanctuary/ambient.riv', bytes);
console.log(`Forest ambient: ${bytes.length} bytes, two transparent ${width}×${height} artboards, ${duration / fps}s / ${fps}fps`);
