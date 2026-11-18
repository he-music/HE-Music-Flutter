#!/usr/bin/env node
// npm install --prefix .artifacts/rive-tools rive-mcp-server@0.3.0 --ignore-scripts
// node scripts/generate_tidal_ambient.mjs
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { reefFishArtwork } from './tidal_fish_art.mjs';
const directory = resolve(process.env.RIVE_GENERATOR_DIR ?? '.artifacts/rive-tools/node_modules/rive-mcp-server');
const { createRiv } = await import(pathToFileURL(resolve(directory, 'dist/rivWriter.js')));
const { importSvg } = await import(pathToFileURL(resolve(directory, 'dist/svgImport.js')));
const width = 900, height = 1600, fps = 30, duration = 720;
function cycle(target, property, base, amplitude, period, phase = 0) {
  const keyframes = [];
  for (let frame = 0; frame <= duration; frame += period < 90 ? 3 : 15) {
    keyframes.push({ frame, value: base + amplitude * Math.sin(frame / period * Math.PI * 2 + phase) });
  }
  return { target, property, keyframes };
}
function artboard(dark) {
  const groups = [], shapes = [], tracks = [];
  function svg(id, body) {
    shapes.push(...importSvg(`<svg xmlns="http://www.w3.org/2000/svg" width="900" height="1600" viewBox="0 0 900 1600">${body}</svg>`, { idPrefix: `${id}_` }).shapes.map((shape) => ({ ...shape, parent: id })));
  }
  function swimmingFish({ species, scale, depth, phase, extent, beat, opacity = .96 }, index) {
    const id = `reef_fish_${index}`, facing = `${id}_facing`, swimmer = `${id}_swimmer`;
    const peduncle = `${id}_peduncle`, tail = `${id}_tail`, dorsal = `${id}_dorsal`;
    const body = `${id}_body`, pectoral = `${id}_pectoral`;
    const art = reefFishArtwork(species, dark);
    groups.push(
      { id, scaleX: scale, scaleY: scale, opacity },
      { id: facing, parent: id },
      { id: swimmer, parent: facing },
      { id: peduncle, parent: swimmer, x: -49 },
      { id: tail, parent: peduncle, x: -23 },
      { id: dorsal, parent: swimmer },
      { id: body, parent: swimmer },
      { id: pectoral, parent: swimmer, x: 17, y: 6 },
    );
    svg(peduncle, art.peduncle);
    svg(tail, art.tail);
    svg(dorsal, art.dorsal);
    svg(body, art.body);
    svg(pectoral, art.pectoral);
    const travel = { x: [], y: [], yaw: [], pitch: [] };
    for (let frame = 0; frame <= duration; frame += 3) {
      const angle = frame / duration * Math.PI * 2 + phase;
      travel.x.push({ frame, value: width / 2 + extent * Math.sin(angle) });
      travel.y.push({ frame, value: height * depth + 35 * Math.sin(angle * 2 + .7) });
      // Facing follows travel velocity. Foreshortening shows a turn at the edge,
      // instead of a fish sliding backwards or flipping at full width.
      travel.yaw.push({ frame, value: Math.tanh(5 * Math.cos(angle)) });
      travel.pitch.push({ frame, value: 4 * Math.cos(angle * 2 + .7) });
    }
    tracks.push(
      { target: id, property: 'x', keyframes: travel.x },
      { target: id, property: 'y', keyframes: travel.y },
      { target: facing, property: 'scaleX', keyframes: travel.yaw },
      { target: facing, property: 'rotation', keyframes: travel.pitch },
      cycle(swimmer, 'rotation', 0, 1.6, beat, phase),
      cycle(peduncle, 'rotation', 0, 5, beat, phase + .7),
      cycle(tail, 'rotation', 0, 13, beat, phase + 1.2),
      cycle(tail, 'scaleX', .82, .18, beat, phase + 1.9),
      cycle(dorsal, 'scaleY', .97, .03, beat * 2, phase + .5),
      cycle(pectoral, 'rotation', -9, 21, 36, phase + 1),
      cycle(pectoral, 'scaleY', .76, .22, 36, phase + 1.6),
    );
  }
  const fish = [
    { species: 'clownfish', scale: dark ? .86 : .96, depth: .635, phase: -.20, extent: 275, beat: 24 },
    { species: 'blue_tang', scale: dark ? .82 : .80, depth: .735, phase: 4.05, extent: 310, beat: 30 },
    ...(!dark ? [
      { species: 'anthias', scale: .40, depth: .255, phase: 1.95, extent: 295, beat: 24, opacity: .88 },
      { species: 'anthias', scale: .32, depth: .275, phase: 2.20, extent: 300, beat: 30, opacity: .84 },
    ] : []),
  ];
  fish.forEach(swimmingFish);
  // Day bubbles rise with buoyancy, with colored outlines visible on bright water.
  if (!dark) {
    for (let i = 0; i < 11; i++) {
      const id = `bubble_${i}`, r = 5 + i % 4 * 2;
      groups.push({ id });
      svg(id, `<circle cx="0" cy="0" r="${r}" fill="#F5FFF5" fill-opacity=".18" stroke="#387F8A" stroke-width="1.8"/><path d="M${-r * .55} 0 Q${-r * .55} ${-r * .6} 0 ${-r * .62}" fill="none" stroke="#FFFBE5" stroke-width="2"/>`);
      const properties = ['x', 'y', 'opacity'];
      const keys = Object.fromEntries(properties.map((key) => [key, []]));
      const period = i % 3 === 0 ? 720 : 360;
      for (let frame = 0; frame <= duration; frame += 6) {
        const progress = ((frame + i * 67) % period) / period;
        const values = {
          x: width * (.19 + (i * .173 % .64)) + Math.sin(progress * Math.PI * 4 + i) * 20,
          y: height * (1.02 - progress * .96),
          // A zero-opacity interval covers both keyframes around every reset.
          opacity: .76 * Math.max(0, Math.min(1, (progress - .05) / .10, (.94 - progress) / .12)),
        };
        for (const property of properties) keys[property].push({ frame, value: values[property] });
      }
      tracks.push(...properties.map((property) => ({ target: id, property, keyframes: keys[property] })));
    }
  } else {
    // Sparse luminous plankton follows the current, using fixed irregular seeds.
    for (let i = 0; i < 15; i++) {
      const id = `plankton_${i}`, phase = i * 2.399;
      const x = width * (.15 + i * .137 % .70), y = height * (.17 + i * .193 % .69);
      groups.push({ id, x, y });
      const color = i % 4 === 0 ? '#C9BCEB' : '#8DEADB';
      shapes.push({
        id: `${id}_halo`, parent: id, type: 'ellipse', width: 26, height: 26,
        fill: { gradient: { type: 'radial', start: { x: 0, y: 0 }, end: { x: 13, y: 0 },
          stops: [{ color, position: 0 }, { color: '#008DEADB', position: 1 }] } }, opacity: .5,
      });
      shapes.push({ id: `${id}_core`, parent: id, type: 'ellipse', width: 3.5, height: 3.5, fill: { color } });
      tracks.push(cycle(id, 'x', x, 25, 720, phase));
      tracks.push(cycle(id, 'y', y, 30, 360, phase + 1));
      tracks.push(cycle(id, 'opacity', .56, .30, 240, phase));
    }
    // Bell pulses and trailing tentacles move at distinct phases, without resets.
    for (let i = 0; i < 2; i++) {
      const id = `jellyfish_${i}`, x = width * (i === 0 ? .23 : .77), y = height * (i === 0 ? .56 : .67);
      groups.push({ id, x, y, opacity: .65, scaleX: i === 0 ? 1 : .75, scaleY: i === 0 ? 1 : .75 });
      svg(id, '<path d="M-27 0 C-25-43 25-43 27 0 Q13 10 0 3 Q-13 10-27 0Z" fill="#99E9E0" fill-opacity=".32" stroke="#B4F2E8" stroke-width="1.6"/><path d="M-26 0 Q0-14 26 0 M-10-9 Q-10-25 0-29 M9-9 Q9-25 0-29" fill="none" stroke="#C8F8EF" stroke-opacity=".6" stroke-width="1.2"/>');
      const tail = `${id}_tentacles`;
      groups.push({ id: tail, parent: id, y: 4 });
      svg(tail, '<path d="M-15 0 Q-25 18-14 28 T-12 53 M-4 0 Q7 15-3 30 T0 65 M10 0 Q1 21 14 34 T12 56" fill="none" stroke="#A6EAE2" stroke-width="1.5" stroke-opacity=".8"/>');
      tracks.push(cycle(id, 'x', x, 17, 720, i * 2));
      tracks.push(cycle(id, 'y', y, 34, 360, i * 2));
      tracks.push(cycle(id, 'scaleX', i === 0 ? 1 : .75, .08, 120, i));
      tracks.push(cycle(tail, 'rotation', 0, 9, 240, i + 1));
    }
  }
  // Foreground sea ribbons bend around their rooted origin; wallpaper stays still.
  for (let i = 0; i < 2; i++) {
    const id = `sea_ribbon_${i}`;
    groups.push({ id, x: width * (i === 0 ? .17 : .83), y: height * .93 });
    svg(id, `<path d="M0 0 Q-45-75-6-180 Q-22-83 10 0Z M8 0 Q55-78 23-140 Q32-61 18 0Z" fill="${dark ? '#297084' : '#418D89'}" fill-opacity=".68"/>`);
    tracks.push(cycle(id, 'rotation', i === 0 ? -7 : 8, dark ? 3 : 5, 360, i * 2));
  }
  return {
    name: dark ? 'TidalNight' : 'TidalDay', width, height, groups, shapes,
    animations: [{ name: 'tidal_current', fps, duration, loop: 'loop', tracks }],
    stateMachine: { name: 'AmbientLoop', inputs: [], states: [{ name: 'current', animation: 'tidal_current' }], transitions: [{ from: 'entry', to: 'current' }] },
  };
}
const spec = { artboards: [artboard(false), artboard(true)] };
for (const board of spec.artboards) {
  const tracks = board.animations[0].tracks;
  for (const track of tracks) {
    if (Math.abs(track.keyframes[0].value - track.keyframes.at(-1).value) > 1e-6) {
      throw new Error(`Loop seam: ${board.name}/${track.target}/${track.property}`);
    }
  }
  for (const track of tracks.filter((track) => track.target.startsWith('bubble_') && track.property === 'y')) {
    const opacity = tracks.find((candidate) => candidate.target === track.target && candidate.property === 'opacity').keyframes;
    for (let i = 1; i < track.keyframes.length; i++) {
      if (Math.abs(track.keyframes[i].value - track.keyframes[i - 1].value) > height / 2
          && (opacity[i].value !== 0 || opacity[i - 1].value !== 0)) {
        throw new Error(`Visible reset: ${track.target} at frame ${track.keyframes[i].frame}`);
      }
    }
  }
}
const { bytes, warnings } = createRiv(spec);
if (warnings.length) throw new Error(warnings.join('\n'));
await mkdir('assets/skins/tidal_sanctuary', { recursive: true });
await writeFile('assets/skins/tidal_sanctuary/ambient.riv', bytes);
console.log(`Tidal ambient: ${bytes.length} bytes; two ${width}×${height} transparent artboards, ${duration / fps}s / ${fps}fps.`);
