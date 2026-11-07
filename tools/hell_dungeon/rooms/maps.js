// The hell's fight rooms and small rooms. They start from the Frostgruft's hand-drawn maps
// (tools/frost_dungeon/rooms/maps.js: same sizes, same door rules) with the hell's own names; the letters
// mean the same, but room.js of the hell draws them with the hell set: '~' is lava, 'o' a chasm, 'v' a fire
// vent, 'x' spikes, g/h lava rocks and spires, N a skull obelisk, W/b demon braziers. The Frostgruft's ice
// lakes stay in the frost. Extra hell rooms follow below.
'use strict';
const FROST = require('../../frost_dungeon/rooms/maps.js').ROOMS;

// frost id -> [hell id, hell title]
const NAMES = {
  reifhalle_b2: ['aschenhalle_b2', 'Aschenhalle (breit)'],
  spaltenkammer_b2: ['schlundkammer_b2', 'Schlundkammer (breit)'],
  schneewacht_b2: ['teufelswacht_b2', 'Teufelswacht (breit)'],
  kristallsaal_b2: ['knochensaal_b2', 'Knochensaal (breit)'],
  eisrinne_h2: ['lavarinne_h2', 'Lavarinne (hoch)'],
  gletschertor_h2: ['glutor_h2', 'Gluttor (hoch)'],
  firnkapelle_h2: ['aschenkapelle_h2', 'Aschenkapelle (hoch)'],
  frostkerker_h2: ['brandkerker_h2', 'Brandkerker (hoch)'],
  gefrorene_galerie_b3: ['verkohlte_galerie_b3', 'Verkohlte Galerie (lang)'],
  schollensee_b3: ['glutsee_b3', 'Glutsee (lang)'],
  kluftbruecken_b3: ['schlundbruecken_b3', 'Schlundbrücken (lang)'],
  eisschacht_h3: ['lavaschacht_h3', 'Lavaschacht (Turm)'],
  wachturm_h3: ['hoellenwacht_h3', 'Höllenwachturm (Turm)'],
  spaltenturm_h3: ['schlundturm_h3', 'Schlundturm (Turm)'],
  winterhof_la: ['brandhof_la', 'Brandhof (Winkel)'],
  gletscherecke_la: ['schlackeecke_la', 'Schlackeecke (Winkel)'],
  kristallwinkel_la: ['knochenwinkel_la', 'Knochenwinkel (Winkel)'],
  eiskaserne_lc: ['teufelskaserne_lc', 'Teufelskaserne (Winkel)'],
  firngarten_lc: ['aschengarten_lc', 'Aschengarten (Winkel)'],
  kluftwinkel_lc: ['schlundwinkel_lc', 'Schlundwinkel (Winkel)'],
  eingang_firn: ['eingang_asche', 'Abstieg: Aschenhalle'],
  eingang_rund: ['eingang_rund', 'Abstieg: Glutrund'],
  eingang_schnee: ['eingang_kreuz', 'Abstieg: Brandkreuz'],
  portal_eistempel: ['portal_tempel', 'Treppe: Feuertempel'],
  portal_eissee: ['portal_glutsee', 'Treppe: Glutsee'],
  portal_rund: ['portal_rund', 'Treppe: Höllenrund'],
  beute_halle: ['beute_halle', 'Beute: Glutkammer'],
  beute_gletscher: ['beute_nische', 'Beute: Schlackenische'],
  beute_steg: ['beute_steg', 'Beute: Lavasteg'],
  tresor_saeulen: ['tresor_saeulen', 'Tresor: Feuersäulen'],
  tresor_kluft: ['tresor_schlund', 'Tresor: Schlund'],
  tresor_kreuz: ['tresor_kreuz', 'Tresor: Teufelskreuz'],
  geheim_eisgruft: ['geheim_gruft', 'Verborgen: Aschengruft'],
  geheim_eisvorhang: ['geheim_vorhang', 'Verborgen: Hinter dem Feuervorhang'],
  geheim_schneewehe: ['geheim_schlacke', 'Verborgen: Unter der Schlacke'],
  stiege_rund: ['stiege_rund', 'Stiege: Glutrund'],
  stiege_saeulen: ['stiege_saeulen', 'Stiege: Feuersäulen'],
};

const ROOMS = [];
for (const m of FROST) {
  if (m.ice_lake || !NAMES[m.id]) continue;
  const [id, title] = NAMES[m.id];
  // the frost's snow share is the hell's ash and blood on the floor; its snow decals are blood and coal here
  const DECAL = { snow_a: 'blood_a', snow_b: 'coal', snow_c: 'blood_c', snow_d: 'blood_d' };
  const decals = (m.decals || []).map(d => [DECAL[d[0]] || d[0]].concat(d.slice(1)));
  ROOMS.push(Object.assign({}, m, { id, title, snow: m.snow || 0.04, decals }));
}

// ---------- the hell's own fight rooms ----------
ROOMS.push(
  { id: 'schlotgang_b2', title: 'Schlotgang (breit)', role: 'combat', shape: 'b2', at: [5, 1], walltheme: 'chains', snow: 0.05, map: [
    '.....................',
    '.W....c.......c....W.',
    '.....................',
    '...v...v.....v...v...',
    '.....................',
    '...v...v.....v...v...',
    '.....................',
    '.N..c...........c..N.',
    '.....................',
  ] },
  { id: 'dornenhof_h2', title: 'Dornenhof (hoch)', role: 'combat', shape: 'h2', at: [1, 4], walltheme: 'bones', snow: 0.05, map: [
    '............',
    '.W..c...c.W.',
    '............',
    '...xx..xx...',
    '............',
    '.S........s.',
    '............',
    '....~~~~....',
    '....~~~~....',
    '............',
    '.s........S.',
    '............',
    '...xx..xx...',
    '............',
    '.W..c...c.W.',
    '............',
    '............',
    '............',
  ] },
);

module.exports = { ROOMS, NAMES };
