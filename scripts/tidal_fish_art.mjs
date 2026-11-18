// Original articulated reef-fish artwork. Coordinates face right, with the
// caudal peduncle at (-53, 0); each returned part has its own Rive joint.
export function reefFishArtwork(species, dark) {
  const clown = species === 'clownfish';
  const anthias = species === 'anthias';
  const palette = clown
    ? (dark ? ['#F4C58A', '#DE874C', '#A24E3A'] : ['#FFDC87', '#FA923B', '#C6542E'])
    : anthias
      ? (dark ? ['#E3BDA1', '#C4867B', '#845A72'] : ['#FFD9AC', '#EFAC79', '#CC7C78'])
      : (dark ? ['#96CAE1', '#448BCA', '#234C96'] : ['#9FDCF0', '#3F93E0', '#234EAF']);
  const fin = clown
    ? (dark ? '#CD865B' : '#FBB055')
    : anthias ? '#E6AF89' : (dark ? '#DCCF8A' : '#F9D567');
  const ink = clown ? '#633D3B' : anthias ? '#985C67' : '#163B72';
  const pearl = dark ? '#D9E7DC' : '#FFF9E8';
  const highlight = dark ? '#BDE4E8' : '#FFF6CB';
  const body = `<defs>
    <linearGradient id="body" gradientUnits="userSpaceOnUse" x1="0" y1="-34" x2="10" y2="34">
      <stop stop-color="${palette[0]}"/><stop offset=".38" stop-color="${palette[1]}"/><stop offset="1" stop-color="${palette[2]}"/>
    </linearGradient>
    <radialGradient id="cheek" gradientUnits="userSpaceOnUse" cx="25" cy="-8" r="42">
      <stop stop-color="${highlight}" stop-opacity=".35"/><stop offset="1" stop-color="${highlight}" stop-opacity="0"/>
    </radialGradient>
    </defs>
    <path d="M-58 0 C-45-28-7-39 27-26 C45-20 57-8 62 0 C56 11 41 24 19 28 C-10 35-44 24-58 0Z" fill="url(#body)" stroke="${ink}" stroke-width="1.4"/>
    <path d="M-45 4 Q-12 27 43 8 Q35 26 12 28 Q-25 31-45 4Z" fill="${pearl}" fill-opacity="${clown ? '.25' : '.19'}"/>
    <path d="M-44-13 Q-10-38 24-24 Q7-23-7-21 Q-26-20-44-13Z" fill="${highlight}" fill-opacity=".38"/>
    ${clown ? `
      <path d="M-49-13 L-39-23 Q-43-2-35 23 L-47 14 Q-53 4-49-13Z" fill="${pearl}" stroke="${ink}" stroke-width="2"/>
      <path d="M-25-29 L-14-32 Q-24-7-13 29 L-26 26 Q-36 1-25-29Z" fill="${pearl}" stroke="${ink}" stroke-width="2"/>
      <path d="M15-30 L26-26 Q18-7 29 24 L17 29 Q5 10 15-30Z" fill="${pearl}" stroke="${ink}" stroke-width="2"/>
    ` : anthias ? `
      <path d="M-47-5 Q-5-18 48-2 Q20 7-16 4Z" fill="#EEC9CF" fill-opacity=".45"/>
      <path d="M-31 12 Q-4 19 22 13" fill="none" stroke="${pearl}" stroke-width="1.4" stroke-opacity=".5"/>
    ` : `
      <path d="M-51-4 Q-26-31 8-24 Q26-22 31-13 Q28-3 5-4 Q-8-3-4 9 Q-1 18 17 20 Q-8 32-28 19 Q-44 12-51-4Z" fill="${ink}"/>
      <path d="M-32-7 Q-21-17-3-17 Q9-15 7-9 Q-13-10-18 4 Q-27 3-32-7Z" fill="${palette[1]}"/>
      <path d="M-49 0 L-61-5 L-61 6Z" fill="${fin}"/>
    `}
    <path d="M26-19 Q16-1 29 16" fill="none" stroke="${ink}" stroke-opacity=".5" stroke-width="1.6"/>
    <path d="M30-18 Q22-6 28 2" fill="none" stroke="${pearl}" stroke-opacity=".5" stroke-width="1"/>
    <path d="M53-3 Q58-1 62 0 L56 3" fill="none" stroke="${ink}" stroke-width="1.4" stroke-linecap="round"/>
    <ellipse cx="39" cy="-8" rx="5.2" ry="5.6" fill="${pearl}"/>
    <circle cx="40" cy="-8" r="3.6" fill="#18313D"/>
    <circle cx="41" cy="-9.7" r="1.1" fill="#FFFFFF"/>
    <path d="M-41-9 Q-7-30 23-19" fill="none" stroke="${highlight}" stroke-width="1.2" stroke-opacity=".42"/>
    <path d="M-5 22 Q2 24 10 22" fill="none" stroke="${highlight}" stroke-width="1.2" stroke-opacity=".36"/>
    <ellipse cx="22" cy="-6" rx="28" ry="22" fill="url(#cheek)"/>`;
  const dorsal = `<path d="M-48-11 Q-36-44-19-43 Q-7-47 10-34 L31-22 Q-9-39-48-11Z" fill="${fin}" fill-opacity=".88" stroke="${ink}" stroke-width="1.2"/>
    <path d="M-46 9 Q-24 45 1 37 L21 25 Q-14 34-46 9Z" fill="${fin}" fill-opacity=".78" stroke="${ink}" stroke-width="1.1"/>
    <path d="M-36-21 L-30-38 M-23-27 L-19-41 M-10-29 L-7-40 M3-28 L4-35 M-29 21 L-19 34 M-14 26 L-7 36" fill="none" stroke="${pearl}" stroke-opacity=".4" stroke-width="1.1"/>
    <path d="M-33-37 Q-15-47 1-38" fill="none" stroke="${pearl}" stroke-opacity=".6" stroke-width="1.4"/>`;
  const tail = `<defs><linearGradient id="tail" gradientUnits="userSpaceOnUse" x1="-40" y1="-22" x2="2" y2="20">
      <stop stop-color="${pearl}"/><stop offset=".30" stop-color="${fin}"/><stop offset="1" stop-color="${palette[2]}"/>
    </linearGradient></defs>
    <path d="M4-5 Q-15-10-39-26 Q-47-10-44 0 Q-47 11-39 26 Q-15 9 4 5Z" fill="url(#tail)" stroke="${ink}" stroke-width="1.6"/>
    <path d="M-38-23 Q-43 0-38 23" fill="none" stroke="${clown ? ink : pearl}" stroke-width="${clown ? 3 : 1.8}" stroke-opacity=".85"/>
    <path d="M-2-3 L-34-18 M-2-1 L-38-7 M-2 1 L-38 6 M-2 3 L-34 18" fill="none" stroke="${pearl}" stroke-width="1.1" stroke-opacity=".5"/>`;
  const peduncle = `<path d="M-5-9 Q-15-7-25-5 L-25 5 Q-15 7-5 9Z" fill="${palette[1]}" stroke="${ink}" stroke-width="1.2"/>
    ${clown ? `<path d="M-15-7 L-21-6 L-21 6 L-15 7Z" fill="${pearl}" stroke="${ink}" stroke-width="1.3"/>` : ''}`;
  const pectoral = `<path d="M3-4 Q-9-7-28 7 Q-35 18-24 22 Q-5 18 5 1Z" fill="${fin}" fill-opacity=".7" stroke="${pearl}" stroke-opacity=".65" stroke-width="1.1"/>
    <path d="M0 0 L-25 9 M0 1 L-24 17 M0-1 L-20 5" fill="none" stroke="${pearl}" stroke-opacity=".45" stroke-width=".9"/>`;
  return { body, dorsal, peduncle, tail, pectoral };
}
