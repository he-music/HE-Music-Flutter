#!/usr/bin/env node
// First export real Flutter frames: --plain-name 'export tidal ambient motion'.
import { execFileSync } from 'node:child_process';
import { access } from 'node:fs/promises';
const root = '.artifacts/tidal-sanctuary';
for (const directory of ['motion-day', 'motion']) {
  for (let frame = 0; frame < 240; frame++) {
    await access(`${root}/${directory}/frame-${frame}.png`);
  }
}
execFileSync('ffmpeg', [
  '-y', '-loglevel', 'error',
  '-framerate', '30', '-i', `${root}/motion-day/frame-%d.png`,
  '-framerate', '30', '-i', `${root}/motion/frame-%d.png`,
  '-filter_complex', '[0:v][1:v]hstack=inputs=2[v]', '-map', '[v]',
  '-an', '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p',
  `${root}/tidal-motion.mp4`,
]);
execFileSync('ffmpeg', [
  '-y', '-loglevel', 'error', '-i', `${root}/tidal-motion.mp4`,
  '-filter_complex', 'fps=15,scale=624:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3',
  '-loop', '0', `${root}/tidal-motion.gif`,
]);
execFileSync('ffprobe', [
  '-v', 'error', '-show_entries', 'stream=codec_name,width,height,r_frame_rate,nb_frames',
  '-show_entries', 'format=duration,size', '-of', 'json', `${root}/tidal-motion.mp4`,
], { stdio: 'inherit' });
console.log(`Real Flutter preview: ${root}/tidal-motion.mp4 (780×844 / 30 fps / 8s); GIF width 624 / 15 fps.`);
