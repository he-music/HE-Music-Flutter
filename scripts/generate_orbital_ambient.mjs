#!/usr/bin/env node
// npm install --prefix .artifacts/rive-tools rive-mcp-server@0.3.0 --ignore-scripts --no-audit --no-fund
// node scripts/generate_orbital_ambient.mjs
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const directory = resolve(process.env.RIVE_GENERATOR_DIR ?? '.artifacts/rive-tools/node_modules/rive-mcp-server');
const { createRiv } = await import(pathToFileURL(resolve(directory, 'dist/rivWriter.js')));
// Match the ACTUAL crop dimensions, not the image provider's requested size.
const width = 627, height = 1254, fps = 30, duration = 720;
const auroraLayers = await Promise.all([0, 1, 2].map((i) =>
  readFile(`.artifacts/orbital-observatory/source/aurora-layer-${i}.png`)));
const cloudBytes = await readFile('.artifacts/orbital-observatory/source/cloud-layer.png');
const limb = (x) => {
  const t = x / width;
  return height * (.259 + .025 * t + .075 * t * t);
};
function cycle(target, property, base, amplitude, period, phase = 0) {
  const keyframes = [];
  for (let frame = 0; frame <= duration; frame += 15) {
    keyframes.push({ frame, value: base + amplitude * Math.sin(frame / period * Math.PI * 2 + phase) });
  }
  return { target, property, keyframes };
}
function night() {
  // Soft photographic layers use affine transforms, avoiding large mesh warps
  // that expose triangle edges in the project's Flutter renderer.
  const groups = [], images = [], tracks = [];
  for (let layer = 0; layer < 3; layer++) {
    const offset = layer * 180;
    const stripWidth = layer === 2 ? 267 : 270;
    const center = offset + stripWidth / 2;
    const baseY = limb(center);
    const id = `aurora_flow_${layer}`;
    groups.push({ id, x: center, y: baseY, opacity: .9 });
    images.push({
      id: `${id}_texture`, parent: id, bytes: auroraLayers[layer],
      x: 0, y: 290 - baseY,
    });
    const keys = { x: [], y: [], rotation: [], scaleY: [], opacity: [] };
    for (let frame = 0; frame <= duration; frame += 6) {
      const angle = frame / 240 * Math.PI * 2 + layer * .85;
      const dx = (30 + layer * 4) * Math.sin(angle);
      const values = {
        x: center + dx,
        y: limb(center + dx),
        rotation: Math.atan(2 * height * .075 / (width * width) * dx) * 180 / Math.PI,
        scaleY: 1.02 + .18 * Math.sin(angle + .8),
        opacity: .82 + .17 * Math.sin(angle - .5),
      };
      for (const property of Object.keys(keys)) keys[property].push({ frame, value: values[property] });
    }
    for (const property of Object.keys(keys)) tracks.push({ target: id, property, keyframes: keys[property] });
  }
  return { ...board('OrbitalNight', groups, [], tracks), images };
}
function day() {
  const groups = [], shapes = [], tracks = [];
  // Thin atmospheric light accompanies a photographic foreground cloud veil.
  // The detailed planet and main cloud field remain fixed for stable reading.
  for (let i = 0; i < 5; i++) {
    const x = width * (i + .25) / 5;
    const id = `atmosphere_${i}`;
    const halfWidth = 85;
    const points = [];
    for (let step = 0; step <= 8; step++) {
      const dx = -halfWidth + step * halfWidth / 4;
      points.push({ x: dx, y: limb(x + dx) - limb(x) - 6 });
    }
    for (let step = 8; step >= 0; step--) {
      const dx = -halfWidth + step * halfWidth / 4;
      points.push({ x: dx, y: limb(x + dx) - limb(x) + 2 });
    }
    groups.push({ id, x, y: limb(x), opacity: .20 });
    shapes.push({
      id: `${id}_light`, parent: id, type: 'polygon', closed: true, points,
      fill: { gradient: {
        type: 'linear', start: { x: -halfWidth, y: 0 }, end: { x: halfWidth, y: 0 },
        stops: [
          { color: '#00B4E9FF', position: 0 },
          { color: '#90B4E9FF', position: .5 },
          { color: '#00B4E9FF', position: 1 },
        ],
      } },
    });
    tracks.push(cycle(id, 'x', x, 7, 720, i * .9));
    tracks.push(cycle(id, 'opacity', .20, .10, 720, i * .9));
  }
  const cloudId = 'foreground_cloud_veil';
  const cloudKeys = { x: [], y: [], opacity: [] };
  for (let frame = 0; frame <= duration; frame += 6) {
    const progress = ((frame + 90) % 360) / 360;
    const opacity = .76 * Math.max(0, Math.min(1, (progress - .08) / .18, (.92 - progress) / .18));
    cloudKeys.x.push({ frame, value: width / 2 - 72 + progress * 144 });
    cloudKeys.y.push({ frame, value: 750 + 10 * Math.sin(progress * Math.PI * 2) });
    cloudKeys.opacity.push({ frame, value: opacity });
  }
  for (const property of Object.keys(cloudKeys)) {
    tracks.push({ target: cloudId, property, keyframes: cloudKeys[property] });
  }
  return {
    ...board('OrbitalDay', groups, shapes, tracks),
    images: [{ id: cloudId, bytes: cloudBytes, x: width / 2, y: 750, opacity: .76 }],
  };
}
function board(name, groups, shapes, tracks) {
  return {
    name, width, height, groups, shapes,
    animations: [{ name: 'orbital_atmosphere', fps, duration, loop: 'loop', tracks }],
    stateMachine: {
      name: 'AmbientLoop', inputs: [],
      states: [{ name: 'atmosphere', animation: 'orbital_atmosphere' }],
      transitions: [{ from: 'entry', to: 'atmosphere' }],
    },
  };
}
const spec = { artboards: [day(), night()] };
for (const artboard of spec.artboards) {
  for (const track of artboard.animations[0].tracks) {
    if (Math.abs(track.keyframes[0].value - track.keyframes.at(-1).value) > 1e-6) {
      throw new Error(`Visible loop seam: ${artboard.name}/${track.target}/${track.property}`);
    }
  }
}
const { bytes, warnings } = createRiv(spec);
if (warnings.length) throw new Error(warnings.join('\n'));
await mkdir('assets/skins/orbital_observatory', { recursive: true });
await writeFile('assets/skins/orbital_observatory/ambient.riv', bytes);
await mkdir('.artifacts/orbital-observatory/source', { recursive: true });
await writeFile('.artifacts/orbital-observatory/source/ambient-spec.json', JSON.stringify(spec));
console.log(`Orbital ambient: ${bytes.length} bytes; two transparent ${width}×${height} artboards, ${duration / fps}s / ${fps} fps; layered aurora flow and foreground cloud drift, fixed stars.`);
