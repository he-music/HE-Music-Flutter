#!/usr/bin/env node
// Export Flutter frames first: 'export orbital ambient motion'.
import { execFileSync } from 'node:child_process';
import { access } from 'node:fs/promises';
const root = '.artifacts/orbital-observatory';
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
  '-an', '-c:v', 'libx264', '-crf', '19', '-pix_fmt', 'yuv420p',
  `${root}/orbital-motion-visible-v2.mp4`,
]);
execFileSync('ffmpeg', [
  '-y', '-loglevel', 'error', '-i', `${root}/orbital-motion-visible-v2.mp4`,
  '-filter_complex', 'fps=15,scale=624:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3',
  '-loop', '0', `${root}/orbital-motion-visible-v2.gif`,
]);
execFileSync('ffmpeg', [
  '-y', '-loglevel', 'error', '-i', `${root}/orbital-motion-visible-v2.mp4`,
  '-filter_complex', 'crop=390:844:390:0,fps=20,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3',
  '-loop', '0', `${root}/orbital-night-visible-v2.gif`,
]);
execFileSync('ffprobe', [
  '-v', 'error', '-show_entries', 'stream=codec_name,width,height,r_frame_rate,nb_frames',
  '-show_entries', 'format=duration,size', '-of', 'json', `${root}/orbital-motion-visible-v2.mp4`,
], { stdio: 'inherit' });
console.log(`Real Flutter day/night preview: ${root}/orbital-motion-visible-v2.mp4 (780×844 / 30 fps / 8s); GIF width 624 / 15 fps.`);
