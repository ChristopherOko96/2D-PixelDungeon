"""The playable browser preview of the Frostgruft on the world kit (Story 2): the crypt's world kit
page (tools/krypta_dungeon/krypta_template.html: key room, boss gate, plates, mana, crates, hidden
stairs) with the Frostgruft's floors, skin, wording and colours.

Usage (repo root):
  py -3 -I tools/frost_dungeon/build_world_preview.py [skin_dir=assets/sprites/frost_hd] <out.html>
The page reads the same pack as the game (frost_world.js on tools/world_kit/world_pack.js), so the
same world number gives the same floor in the preview and in Godot. The Frostgruft's monsters live
only in the game (assets/data/frost_theme.json mobs); the preview fights with the crypt's undead
figures as stand-ins, without mimics. Glaze ice does not hurt here (in the game it slides).
"""
import base64
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
KRYPTA = os.path.join(ROOT, 'tools', 'krypta_dungeon')
args = sys.argv[1:]
skin, out = (args[0], args[1]) if len(args) > 1 else (os.path.join(ROOT, 'assets', 'sprites', 'frost_hd'), args[0])


def b64(path):
    return 'data:image/png;base64,' + base64.b64encode(open(path, 'rb').read()).decode()


def text(*parts):
    return open(os.path.join(*parts), encoding='utf-8').read()


assets, sizes = {}, {}
for name, m in json.load(open(os.path.join(skin, 'manifest.json'), encoding='utf-8')).items():
    if name.startswith(('mob_', 'boss_golem', 'ally_', 'weapon_', 'rock_')) and not name.startswith('mob_snowman'):
        continue   # the game's own figures; the preview does not draw them
    assets[name] = b64(os.path.join(skin, name + '.png'))
    sizes[name] = [m['w'], m['h']]
for n in ['knight_m_%s_anim_f%d' % (k, i) for k in ('idle', 'run') for i in range(4)] + ['dwarf_m_idle_anim_f%d' % i for i in range(4)]:
    assets[n] = b64(os.path.join(ROOT, 'assets', 'sprites', '0x72', n + '.png'))

SWAPS = [
    ('<title>Krypta Etagen</title>', '<title>Frostgruft Etagen</title>'),
    ('/* Layout: one dark crypt page;', '/* Layout: one dark frost page;'),
    ('--bg: #0a090d;', '--bg: #070b14;'), ('--panel: #14121a;', '--panel: #0e1626;'), ('--panel-2: #1c1924;', '--panel-2: #142036;'),
    ('--line: #332e3e;', '--line: #2a3a5a;'), ('--ink: #ece6dc;', '--ink: #e6f2ff;'), ('--muted: #a8a0b0;', '--muted: #93a8cc;'),
    ('--ember: #c9a24a;', '--ember: #7ff6ff;'), ('--ember-soft: #e6cf96;', '--ember-soft: #b8e2fa;'),
    ('<span class="eyebrow" id="eyebrow">Krypta der Verdammten</span>', '<span class="eyebrow" id="eyebrow">Die Frostgruft</span>'),
    ('<h1 id="floor-title">Vorhalle der Verdammten, Etage 1</h1>', '<h1 id="floor-title">Frostpforte, Etage 1</h1>'),
    ("'Krypta der Verdammten · '", "'Die Frostgruft · '"),
    ('window.KryptaFloors', 'window.FrostWorld'),
    ("C: { name: 'Goldschlüssel', filter: 'none', color: '#f2c94c', hint: 'liegt in der Schlüsselkammer, zwischen Altar und Brunnen.' }",
     "C: { name: 'Kristallschlüssel', filter: 'grayscale(1) brightness(1.6)', color: '#f2f8ff', hint: 'liegt in der Schlüsselkammer, in der Mitte des großen Teppichs.' }"),
    ("B: { name: 'Silberschlüssel', filter: 'grayscale(1) brightness(1.5)', color: '#d8dde6'", "B: { name: 'Eisschlüssel', filter: 'hue-rotate(180deg)', color: '#4fb4ff'"),
    ("A: { name: 'Bronzeschlüssel', filter: 'sepia(1) saturate(1.6) hue-rotate(-18deg) brightness(.82)', color: '#cd8a4a'", "A: { name: 'Goldschlüssel', filter: 'none', color: '#e8c25a'"),
    ("W.final ? 'Die Krypta verlassen' : 'Treppe hinab zu Etage ' + (state.floor + 1)) : 'Treppe versperrt'", "W.final ? 'Die Frostgruft verlassen' : 'Treppe zu Etage ' + (state.floor + 1)) : 'Treppe versperrt'"),
    ("'Seelenschale entzünden'", "'Frostflamme entzünden'"),
    ('alle Seelenschalen', 'alle Frostflammen'), ('Alle Seelenschalen brennen', 'Alle Frostflammen brennen'),
    ("'Seelenschale ' + s.done", "'Frostflamme ' + s.done"), ("'Die Grabplatten leuchten auf.", "'Die Eisplatten leuchten auf."),
    ("'Aus der Kiste kriechen Untote! Die Gitter fallen.'", "'Aus der Kiste kriechen Frostwesen! Die Gitter fallen.'"),
    ("'Das Grabsiegel bricht: drei Untote steigen heraus! Die Gitter fallen.'", "'Das Siegel bricht: drei Frostwesen springen heraus! Die Gitter fallen.'"),
    ("  if (here === 2) hurt(1, 'im Moder versunken');\n", ''),
    ("ctx.fillStyle = '#c8ff8a'; ctx.fillRect(x * C, y * C, C, C);", "ctx.fillStyle = '#e6f8ff'; ctx.fillRect(x * C, y * C, C, C);"),
    ("p.big ? '#a6ec6e' : '#c9f59c'", "p.big ? '#d2f1ff' : '#ffffff'"),
    ("W.final ? 'Die Krypta ist befreit'", "W.final ? 'Die Frostgruft ist bezwungen'"),
    ("' – das Ende der Krypta.'", "' – das Ende der Frostgruft.'"),
    ("'Kiste: zerschießen. Runensteine, Herz oder Untote.'", "'Kiste: zerschießen. Eissplitter, Herz oder Frostwesen.'"),
    ("'Erloschene Seelenschale entzünden (E)", "'Erloschene Frostflamme entzünden (E)"), ("Seelenschalen entzünden (E)", "Frostflammen entzünden (E)"),
    ("'Grabsiegel: anschießen (8 Treffer). Zufall: dauerhafter Segen oder drei Untote", "'Siegel: anschießen (8 Treffer). Zufall: dauerhafter Segen oder drei Frostwesen"),
    ("hz.push('Moder')", "hz.push('Glatteis')"),
    ("function update(dt) {\n  state.t += dt;", "function update(dt) {\n  state.t += dt;\n  if (window.frostWake) window.frostWake({ props, player, ROOMS, roomAt, idx, C, spawnMob, burst, state, toast, updatePage });"),
    ("const HM = window.HellMonsters, SPR = {};", "const HM = window.HellMonsters, SPR = window.FROST_SPR = {};"),
    ("  const list = [];\n  for (const p of props) if (p.name && vis(",
     "  if (window.frostDrifts) window.frostDrifts.ground(%s);\n  const list = [];\n  for (const p of props) if (p.name && vis(" % "{ W, grid, roomAt, C, decals, ents, props, IMG, ctx, vis }"),
    ("  list.sort((a, b) => a.y - b.y).forEach(o => o.f());",
     "  if (window.frostDrifts) window.frostDrifts.feet(%s, list);\n  list.sort((a, b) => a.y - b.y).forEach(o => o.f());" % "{ W, grid, roomAt, C, decals, ents, props, IMG, ctx, vis }"),
    ("Grabsiegel</b> in ${", "Siegel</b> in ${"), ("Segen oder drei Untote.`", "Segen oder drei Frostwesen.`"),
    ("'Seelenschalen']", "'Frostflammen']"), ("'Seelenschalen sind über die Etage verteilt und öffnen den Reliquienschrein.'", "'Frostflammen sind über die Etage verteilt und öffnen den Frostflammen-Tresor.'"),
]
LEDE = ('<p class="lede">Story 2 auf dem Welt-Baukasten: zehn Eis-Etagen, die sich bei jedem Lauf neu bauen, hier in der neuen HD-Grafik. '
        'Etagen, Bosse und Gefahren bleiben die der Frostgruft; dazu kommen die festen Regeln der Welten: Schlüsselkammer mit Laden, '
        'Händler und Manabrunnen, das Prunktor von unten, Druckplatten mit Frosttresor, zerbrechliche Fässer, Urnen und Kisten und die '
        'Vergessene Stiege. Der Boden ist Schnee, um Feuer getaut; große Glatteisflächen, Eisgeysire, Schneemänner und Gletscher. Die Gegner in dieser Vorschau sind Platzhalter aus der Krypta; im Spiel kämpfst '
        'du gegen die Frost-Gegner, und jeder Schneemann erwacht in deiner Nähe zum Schneemonster. Nur im Spiel: Frostnebel, Fußspuren, Druckmulden und langes Rutschen auf dem Eis.</p>')
HELP = {
    'Schlüssel': 'Gold (Hauptweg), Eis (Beutekammer), Kristall (Bosstor). Jeder passt nur in sein Tor.',
    'Seelenschalen': None, 'Grabsiegel': None, 'Moder': None, 'Mimik': None,
    'Bosstor': 'immer von unten: Prunktor mit zwei Bannern in der Etagenfarbe, zwei Fackeln und Teppich. Öffnet nur mit dem Kristallschlüssel.',
    'Schlüsselkammer': 'kleiner Raum, der Kristallschlüssel liegt in der Mitte des großen Teppichs. Oben links der Laden mit dem Händler, oben rechts der Manabrunnen zwischen zwei Wasserspeiern. Man betritt sie immer rechts unten. Hier geht nichts kaputt.',
    'Zerbrechliches': 'Urnen, Fässer und Kisten zerschießen: manchmal Eissplitter oder ein Herz, aus Kisten auch Frostwesen.',
    'Monster': 'in der Vorschau Platzhalter aus der Krypta; im Spiel die Frost-Gegner jeder Etage.',
    'Bosse': 'zehn Etagenbosse wie bisher, bis zu Hrimgar, dem Gletscherkoloss.',
    'Tiefer': 'mehr Glatteis, Stacheln und Frostschlote, zähere Gegner und mehr Arten pro Raum.',
}
EXTRA_HELP = ('<dt>Frostflammen</dt><dd>über mehrere Räume verteilt. Brennen alle, öffnet sich das Gitter zum Frostflammen-Tresor mit Herzcontainer.</dd>\n'
              '          <dt>Glatteis</dt><dd>im Spiel rutschig: wer darauf läuft, gleitet weiter. Brücken führen hinüber.</dd>\n')
BESTIARY = ('<p>Die Frost-Gegner leben nur im Spiel. Diese Vorschau zeigt die Krypta-Figuren als Platzhalter, '
            'damit Räume, Rätsel und Wege spielbar sind.</p>')
# the game's light snowstorm (src/vfx/snowstorm.gd) over the play field, as an overlay canvas
SNOWSTORM = """
<script>
(function () {
  const game = document.getElementById('game');
  const box = game.parentElement, over = document.createElement('canvas');
  over.width = game.width; over.height = game.height;
  over.style.cssText = 'position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none';
  if (getComputedStyle(box).position === 'static') box.style.position = 'relative';
  box.appendChild(over);
  const ctx = over.getContext('2d'), flakes = [];
  for (let i = 0; i < 240; i++) flakes.push({ x: Math.random() * over.width, y: Math.random() * over.height, d: Math.random(), s: Math.random() * 6.3, r: .6 + Math.random() * 1.2 });
  let t = 0, last = performance.now(), gustAt = 6, gust = -1;
  function frame(now) {
    const dt = Math.min(.05, (now - last) / 1000); last = now; t += dt;
    if (gust >= 0) { gust += dt; if (gust > 2.6) { gust = -1; gustAt = t + 5 + Math.random() * 6; } } else if (t > gustAt) gust = 0;
    const wind = -70 - (gust >= 0 ? 260 * Math.sin(Math.PI * gust / 2.6) : 0);
    ctx.clearRect(0, 0, over.width, over.height);
    for (const f of flakes) {
      const fall = 55 + 95 * f.d;
      f.x += (wind * (.5 + f.d * .7) + Math.sin(t * f.r + f.s) * 18) * dt; f.y += fall * dt;
      if (f.y > over.height + 8) { f.y = -6; f.x = Math.random() * over.width; }
      if (f.x < -12) f.x += over.width + 20; else if (f.x > over.width + 12) f.x -= over.width + 20;
      const size = Math.max(2, Math.round((2 + 2 * f.d) / 2) * 2);
      ctx.fillStyle = 'rgba(238,247,255,' + (.35 + .45 * f.d) + ')';
      ctx.fillRect(Math.round(f.x / 2) * 2, Math.round(f.y / 2) * 2, size, size);
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
</script>
"""
# the snowman mimic, as in the game: a snowman wakes as the snow monster (its frames are the game's
# own mob_snowman_f0..7) when the hero comes within 120 px; the room locks
SNOWMAN = """
<script>
(function () {
  const frames = [];
  let loaded = 0;
  for (let i = 0; i < 8; i++) {
    const im = new Image();
    im.onload = () => { if (++loaded === 8) ready(); };
    im.src = ASSETS['mob_snowman_f' + i];
    frames.push(im);
  }
  function ready() {
    const list = frames.map(im => { const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; c.getContext('2d').drawImage(im, 0, 0); return c; });
    window.FROST_SPR.snowman = { idle: list, run: list, attack: list, death: list };
    window.HellMonsters.DEFS.snowman = { name: 'Schneemann', w: list[0].width, h: list[0].height, scale: .62, kind: 'mob', role: 'Mimik', shot: 'frost',
      desc: 'Steht als Schneemann herum und erwacht, wenn du nahe kommst. Hüpft, stürmt und springt dich an.',
      anims: { idle: { frames: 8 }, run: { frames: 8 }, attack: { frames: 8 }, death: { frames: 8 } },
      stats: { hp: 9, speed: 125, r: 30, ai: 'chase', attacks: [
        { id: 'sturm', name: 'Sturmangriff', kind: 'dash', every: 2.8, range: 340, speed: 780, desc: 'Stürmt auf dich zu.' },
        { id: 'satz', name: 'Sprungangriff', kind: 'slam', every: 3.6, range: 480, radius: 130, leap: true, desc: 'Springt dich an.' }] } };
  }
  window.frostWake = function (G) {
    const { props, player, ROOMS, roomAt, idx, C, spawnMob, burst, state, toast, updatePage } = G;
    if (!window.HellMonsters.DEFS.snowman || !props || !player) return;
    for (let i = 0; i < props.length; i++) {
      const p = props[i];
      if (p.name !== 'snowman' || Math.hypot(player.x - p.x, player.y - p.y) > 120) continue;
      props.splice(i, 1);
      const r = ROOMS[roomAt[idx(Math.floor(p.x / C), Math.floor((p.y - 8) / C))]];
      if (!r) return;
      r.fight = true; r.cleared = false;
      const m = spawnMob(r, p.x, p.y, 'snowman'); m.spawn = 0;
      burst(p.x, p.y - 40, 30, true); state.shake = .4;
      toast('Der Schneemann erwacht! Die Gitter fallen.'); updatePage();
      return;
    }
  };
})();
</script>
"""
# the game's snow cushions (src/hero/frost_snow.gd): rows of drift sprites at the foot of every
# wall, round framed floor decals, plates and thaw patches, and at the foot of everything standing
# on the snow, drawn right after it
DRIFTS = """
<script>
(function () {
  const FRAMED = ['rune_big', 'rune_plate', 'rune_small', 'fire_plate', 'demon_plate', 'grate', 'pit'];
  const STEP = 30, feet = {};
  let laid = null, laidFor = null;
  const hash = (x, y) => { let v = (Math.floor(x * 7) * 374761393 + Math.floor(y * 3) * 668265263) | 0; v = Math.imul(v ^ (v >>> 13), 1274126177); return ((v ^ (v >>> 16)) & 0xFFFF) / 65535; };
  function foot(G, name) {
    if (feet[name]) return feet[name];
    const im = G.IMG[name]; if (!im || !im.width) return [-20, 20];
    const c = document.createElement('canvas'); c.width = im.width; c.height = im.height;
    const x2 = c.getContext('2d'); x2.drawImage(im, 0, 0);
    const h = im.height, w = im.width, from = Math.max(0, h - Math.max(4, Math.floor(h / 5)));
    const d = x2.getImageData(0, from, w, h - from).data; let lo = w, hi = -1;
    for (let y = 0; y < h - from; y++) for (let x = 0; x < w; x++) if (d[(y * w + x) * 4 + 3] > 100) { lo = Math.min(lo, x); hi = Math.max(hi, x); }
    return (feet[name] = hi >= lo ? [lo - w / 2, hi + 1 - w / 2] : [-20, 20]);
  }
  function row(out, a, b, sc) {
    const n = Math.max(1, Math.round(Math.hypot(b[0] - a[0], b[1] - a[1]) / (STEP * sc)));
    for (let k = 0; k <= n; k++) { const x = a[0] + (b[0] - a[0]) * k / n, y = a[1] + (b[1] - a[1]) * k / n, h = hash(x, y);
      out.push([x + (h - .5) * 8, y + (h - .5) * 4, Math.floor(h * 997) % 6, sc * (.8 + .35 * ((h * 7) % 1)), h > .5]); }
  }
  function square(out, cx, cy, hx, hy, sc) {
    row(out, [cx - hx, cy + hy + 4], [cx + hx, cy + hy + 4], sc); row(out, [cx - hx, cy - hy + 6], [cx + hx, cy - hy + 6], sc * .8);
    row(out, [cx - hx - 4, cy - hy + 24], [cx - hx - 4, cy + hy], sc * .7); row(out, [cx + hx + 4, cy - hy + 24], [cx + hx + 4, cy + hy], sc * .7);
  }
  function lay(G) {
    const out = [], { grid, roomAt, C, W } = G, cols = W.COLS, rows = W.ROWS;
    const wall = (x, y) => x < 0 || y < 0 || x >= cols || y >= rows || grid[y * cols + x] === 0;
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      const i = y * cols + x; if (grid[i] !== 1 || roomAt[i] < 0) continue;
      if (wall(x, y - 1)) row(out, [x * C, y * C + 12], [(x + 1) * C, y * C + 12], 1);
      if (wall(x - 1, y)) row(out, [x * C + 10, y * C + 40], [x * C + 10, (y + 1) * C], .75);
      if (wall(x + 1, y)) row(out, [(x + 1) * C - 10, y * C + 40], [(x + 1) * C - 10, (y + 1) * C], .75);
    }
    for (const d of G.decals) if (FRAMED.includes(d.name)) { const im = G.IMG[d.name], w = d.w || (im ? im.width : C), h = d.h || (im ? im.height : C); square(out, d.x, d.y, w / 2, h / 2, .8); }
    for (const e of G.ents) if (e.type === 'plate') square(out, e.x, e.y, 40, 40, .7);
    for (const d of G.decals) if (d.name.startsWith('thaw_')) { const r = (d.w || 220) * .37, n = Math.max(8, Math.floor(2 * Math.PI * r / STEP));
      for (let k = 0; k < n; k++) { const a = 2 * Math.PI * k / n, x = d.x + Math.cos(a) * r, y = d.y + Math.sin(a) * r * .78, h = hash(x, y); out.push([x, y, Math.floor(h * 997) % 6, .8 + .3 * h, h > .5]); } }
    return out;
  }
  function drift(G, x, y, k, sc, flip) {
    const im = G.IMG['drift_' + k]; if (!im) return;
    const w = im.width * sc, h = im.height * sc, c = G.ctx;
    if (flip) { c.save(); c.translate(x, 0); c.scale(-1, 1); c.drawImage(im, -w / 2, y - h, w, h); c.restore(); } else c.drawImage(im, x - w / 2, y - h, w, h);
  }
  window.frostDrifts = {
    ground(G) {
      if (laidFor !== G.W) { laid = lay(G); laidFor = G.W; }
      for (const d of laid) if (G.vis(d[0] - 40, d[1] - 30, d[0] + 40, d[1] + 10)) drift(G, d[0], d[1], d[2], d[3], d[4]);
    },
    feet(G, list) {
      const add = (o, name) => {
        if (!G.IMG[name] || !G.vis(o.x - 120, o.y - 60, o.x + 120, o.y + 20)) return;
        const cx = Math.floor(o.x / G.C), cy = Math.floor((o.y - 6) / G.C); if (G.grid[cy * G.W.COLS + cx] !== 1 && G.grid[cy * G.W.COLS + cx] !== 2) return;
        let f = foot(G, name); if (o.flip) f = [-f[1], -f[0]];
        const small = name === 'heart', sc = small ? .55 : Math.max(.7, Math.min(1.1, (f[1] - f[0]) / 90));
        const ax = o.x + f[0] * (small ? .5 : 1) - 4, bx = o.x + f[1] * (small ? .5 : 1) + 4, n = Math.max(1, Math.round((bx - ax) / (STEP * sc)));
        list.push({ y: o.y + .01, f: () => { for (let k = 0; k <= n; k++) { const x = ax + (bx - ax) * k / n, h = hash(x, o.y); drift(G, x, o.y + 5 + (h - .5) * 3, Math.floor(h * 997) % 6, sc * (.85 + .3 * h), h > .5); } } });
      };
      for (const p of G.props) if (p.name) add(p, p.name);
      for (const e of G.ents) {
        if (e.taken || e.gone) continue;
        const name = e.type === 'crate' && !e.broken ? e.look : { chest: 'chest_closed', vault: 'chest_vault', brazier: 'brazier_bowl', well: 'fountain', stairs: 'stairs_down', key: 'heart', heart: 'heart', gem: 'heart' }[e.type];
        if (name) add(e, name);
      }
    },
  };
})();
</script>
"""
NO_MIMIC = """
(function () {
  const H = window.HellMonsters;
  for (const k in H.FLOORS) H.FLOORS[k].mobs = H.FLOORS[k].mobs.filter(id => id !== 'mimik');
})();
"""

html = text(KRYPTA, 'krypta_template.html')
for a, b in SWAPS:
    assert a in html, a
    html = html.replace(a, b)
start = html.index('<p class="lede">')
html = html[:start] + LEDE + html[html.index('</p>', start) + 4:]
start = html.index('<h2 id="best-title">Bestiarium</h2>')
p0 = html.index('<p>', start)
html = html[:p0] + BESTIARY + html[html.index('</p>', p0) + 4:]
for term, new in HELP.items():
    key = '<dt>%s</dt><dd>' % term
    assert key in html, term
    a = html.index(key)
    b = html.index('</dd>', a) + 5
    html = html[:a] + ('' if new is None else key + new + '</dd>') + html[b:]
html = html.replace('<dt>Bosstor</dt>', EXTRA_HELP + '          <dt>Bosstor</dt>', 1)
for key, val in (('__ASSETS__', json.dumps(assets)), ('__SIZES__', json.dumps(sizes)), ('__CORE__', text(ROOT, 'tools', 'world_kit', 'world_core.js')),
                 ('__PIX__', text(KRYPTA, 'krypta_pix.js')), ('__FLOORS__', text(ROOT, 'tools', 'world_kit', 'world_pack.js') + '\n' + text(HERE, 'frost_world.js')),
                 ('__MONSTERS__', text(KRYPTA, 'krypta_monsters.js') + '\n' + NO_MIMIC)):
    assert key in html, key
    html = html.replace(key, val)
html = html.replace('</body>', SNOWSTORM + SNOWMAN + DRIFTS + '</body>') if '</body>' in html else html + SNOWSTORM + SNOWMAN + DRIFTS
# the old hell preview's heavy black shadow ovals become faint cold contact shadows on the snow
html = html.replace("ctx.fillStyle = 'rgba(0,0,0,.4)'; ctx.beginPath(); ctx.ellipse", "ctx.fillStyle = 'rgba(0,0,0,0)'; ctx.beginPath(); ctx.ellipse")
html = html.replace("ctx.fillStyle = 'rgba(0,0,0,.45)'; ctx.beginPath(); ctx.ellipse", "ctx.fillStyle = 'rgba(0,0,0,0)'; ctx.beginPath(); ctx.ellipse")
open(out, 'w', encoding='utf-8').write(html)
print(len(assets), 'assets,', round(len(html) / 1e6, 2), 'MB ->', out)
