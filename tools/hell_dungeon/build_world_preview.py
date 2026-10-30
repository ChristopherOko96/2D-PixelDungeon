"""The playable browser preview of the hell on the world kit (Story 3): the crypt's world kit page
(tools/krypta_dungeon/krypta_template.html: key room, boss gate, plates, mana, mimics, crates,
hidden stairs) with the hell's floors, skin, wording, colours and monsters.

Usage (repo root):
  py -3 -I tools/hell_dungeon/build_world_preview.py [skin_dir=assets/sprites/hell] <out.html>
The page reads the same pack as the game (hell_world.js on tools/world_kit/world_pack.js), so the
same world number gives the same floor in the preview and in Godot. The monsters are the hell's
(hell_monsters.js, Ignaroth from drake_hybrid.js); a mimic chest wakes as the crypt's mimic in hell
wood, as in the game (assets/data/hell_balance.json monsters.borrow).
"""
import base64
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
KRYPTA = os.path.join(ROOT, 'tools', 'krypta_dungeon')
args = sys.argv[1:]
skin, out = (args[0], args[1]) if len(args) > 1 else (os.path.join(ROOT, 'assets', 'sprites', 'hell'), args[0])


def b64(path):
    return 'data:image/png;base64,' + base64.b64encode(open(path, 'rb').read()).decode()


def text(*parts):
    return open(os.path.join(*parts), encoding='utf-8').read()


assets, sizes = {}, {}
for name, m in json.load(open(os.path.join(skin, 'manifest.json'), encoding='utf-8')).items():
    assets[name] = b64(os.path.join(skin, name + '.png'))
    sizes[name] = [m['w'], m['h']]
for n in ['knight_m_%s_anim_f%d' % (k, i) for k in ('idle', 'run') for i in range(4)] + ['dwarf_m_idle_anim_f%d' % i for i in range(4)]:
    assets[n] = b64(os.path.join(ROOT, 'assets', 'sprites', '0x72', n + '.png'))

# crypt page -> hell page: wording, colours, monsters (every pair must be found)
SWAPS = [
    ('<title>Krypta Etagen</title>', '<title>Hell-Dungeon Etagen</title>'),
    ('/* Layout: one dark crypt page;', '/* Layout: one dark hell page;'),
    ('--bg: #0a090d;', '--bg: #0b0708;'), ('--panel: #14121a;', '--panel: #160d0e;'), ('--panel-2: #1c1924;', '--panel-2: #201213;'),
    ('--line: #332e3e;', '--line: #3d2626;'), ('--ink: #ece6dc;', '--ink: #f1e4d8;'), ('--muted: #a8a0b0;', '--muted: #b39c94;'),
    ('--ember: #c9a24a;', '--ember: #ff6b2c;'), ('--ember-soft: #e6cf96;', '--ember-soft: #ffb36b;'),
    ('<span class="eyebrow" id="eyebrow">Krypta der Verdammten</span>', '<span class="eyebrow" id="eyebrow">Der Hell-Dungeon</span>'),
    ('<h1 id="floor-title">Vorhalle der Verdammten, Etage 1</h1>', '<h1 id="floor-title">Aschenvorhof, Etage 1</h1>'),
    ("'Krypta der Verdammten · '", "'Der Hell-Dungeon · '"),
    ('window.KryptaFloors', 'window.HellWorld'),
    ("C: { name: 'Goldschlüssel', filter: 'none', color: '#f2c94c', hint: 'liegt in der Schlüsselkammer, zwischen Altar und Brunnen.' }",
     "C: { name: 'Dämonenschlüssel', filter: 'none', color: '#b07cff', hint: 'liegt in der Schlüsselkammer, in der Mitte des großen Teppichs.' }"),
    ("B: { name: 'Silberschlüssel', filter: 'grayscale(1) brightness(1.5)', color: '#d8dde6'", "B: { name: 'Knochenschlüssel', filter: 'grayscale(1) brightness(1.5)', color: '#e8dccb'"),
    ("A: { name: 'Bronzeschlüssel', filter: 'sepia(1) saturate(1.6) hue-rotate(-18deg) brightness(.82)', color: '#cd8a4a'", "A: { name: 'Glutschlüssel', filter: 'none', color: '#ff8a3c'"),
    ("W.final ? 'Die Krypta verlassen' : 'Treppe hinab zu Etage ' + (state.floor + 1)) : 'Treppe versperrt'", "W.final ? 'Die Hölle verlassen' : 'Portal zu Etage ' + (state.floor + 1)) : 'Portal erloschen'"),
    ("'Seelenschale entzünden'", "'Feuerschale entzünden'"),
    ('alle Seelenschalen', 'alle Feuerschalen'), ('Alle Seelenschalen brennen', 'Alle Feuerschalen brennen'),
    ("'Seelenschale ' + s.done", "'Feuerschale ' + s.done"), ("'Die Grabplatten leuchten auf.", "'Die Runenplatten leuchten auf."),
    ("'Aus der Kiste kriechen Untote! Die Gitter fallen.'", "'Aus der Kiste springen Dämonen! Die Gitter fallen.'"),
    ("const kind = state.floor >= 6 ? 'skelettwache' : 'skelett';", "const kind = 'glutimp';"),
    ("'Das Grabsiegel bricht: drei Untote steigen heraus! Die Gitter fallen.'", "'Das Siegel bricht: drei Dämonen springen heraus! Die Gitter fallen.'"),
    ("hurt(1, 'im Moder versunken')", "hurt(1, 'in die Lava gestürzt')"),
    ("ctx.fillStyle = '#c8ff8a'; ctx.fillRect(x * C, y * C, C, C);", "ctx.fillStyle = '#ffd27a'; ctx.fillRect(x * C, y * C, C, C);"),
    ("p.big ? '#a6ec6e' : '#c9f59c'", "p.big ? '#ff7a2a' : '#ffb347'"),
    ("W.final ? 'Die Krypta ist befreit'", "W.final ? 'Die Hölle ist bezwungen'"),
    ("'Nach dem Boss: Truhe öffnen und die Treppe hinab' + (W.final ? ' – das Ende der Krypta.' : ' zur nächsten Etage.')", "'Nach dem Boss: Truhe öffnen und durch das Portal' + (W.final ? ' – das Ende der Hölle.' : ' zur nächsten Etage.')"),
    ("'Kiste: zerschießen. Runensteine, Herz oder Untote.'", "'Kiste: zerschießen. Runensteine, Herz oder Dämonen.'"),
    ("'Erloschene Seelenschale entzünden (E)", "'Erloschene Feuerschale entzünden (E)"), ("Seelenschalen entzünden (E)", "Feuerschalen entzünden (E)"),
    ("'Grabsiegel: anschießen (8 Treffer). Zufall: dauerhafter Segen oder drei Untote", "'Dämonensiegel: anschießen (8 Treffer). Zufall: dauerhafter Segen oder drei Dämonen"),
    ("hz.push('Moder')", "hz.push('Lava')"),
    ("Grabsiegel</b> in ${", "Dämonensiegel</b> in ${"), ("Segen oder drei Untote.`", "Segen oder drei Dämonen.`"),
    ("'Seelenschalen']", "'Feuerschalen']"), ("'Seelenschalen sind über die Etage verteilt und öffnen den Reliquienschrein.'", "'Feuerschalen sind über die Etage verteilt und öffnen den Feuerschalen-Tresor.'"),
]
LEDE = ('<p class="lede">Story 3 auf dem Welt-Baukasten: zehn Höllen-Etagen, die sich bei jedem Lauf neu bauen. '
        'Aussehen, Licht, Lava und Gegner bleiben die des Hell-Dungeons; dazu kommen die festen Regeln der Krypta: '
        'Schlüsselkammer mit Laden, Händler und Manabrunnen, das Prunktor von unten, Druckplatten mit Riesentresor, '
        'zerbrechliche Fässer, Urnen und Kisten, Mimik-Truhen und die Vergessene Stiege. Kampfräume sind mittelgroß, '
        'nur wenige groß; Schlüsselkammer, Tresore, Beutekammer, Geheimräume, Stiege und Portalkammer sind klein. '
        'Die Spielfigur ist ein Platzhalter.</p>')
HELP = {
    'Schlüssel': 'Glut (Hauptweg), Knochen (Beutekammer), Dämon (Bosstor). Jeder passt nur in sein Tor.',
    'Seelenschalen': None, 'Grabsiegel': None, 'Moder': None,
    'Bosstor': 'immer von unten: Prunktor mit zwei Bannern in der Etagenfarbe, zwei Fackeln und Teppich. Öffnet nur mit dem Dämonenschlüssel. Etage 10 brennt blau.',
    'Schlüsselkammer': 'kleiner Raum, der Dämonenschlüssel liegt in der Mitte des großen Teppichs. Oben links der Laden mit dem Händler zwischen zwei Regalen, oben rechts der Manabrunnen zwischen zwei Wasserspeiern. Man betritt sie immer rechts unten. Hier geht nichts kaputt.',
    'Zerbrechliches': 'Urnen, Fässer und Kisten zerschießen: manchmal Runensteine oder ein Herz, aus Kisten auch Dämonen.',
    'Monster': 'jede Etage hat ihren eigenen Mix aus den Höllen-Gegnern. Rote Linien und leuchtende Kreise warnen vor Angriffen: aus ihnen herauslaufen.',
    'Bosse': 'zehn Etagenbosse wie bisher; Ignaroth wartet auf Etage 3, 6, 9 und 10.',
    'Tiefer': 'mehr Lava, Stacheln und Glutschlote, zähere Gegner und mehr Arten pro Raum.',
}
EXTRA_HELP = ('<dt>Feuerschalen</dt><dd>über mehrere Räume verteilt. Brennen alle, öffnet sich das Gitter zum Feuerschalen-Tresor mit Herzcontainer.</dd>\n'
              '          <dt>Dämonensiegel</dt><dd>ab Etage 4, 3–4 je Etage. Acht Treffer: Zufall zwischen dauerhaftem Segen und drei Dämonen.</dd>\n'
              '          <dt>Lava</dt><dd>kostet ein Herz pro Schritt. Brücken führen hinüber, Glutschlote stoßen im Takt Feuer aus.</dd>\n')
BESTIARY = ('<p>Die Gegner des Hell-Dungeons: Glutschädel, Brandskelett, Höllenhund, Magmaschleim, Glutimp, Aschenpriester, '
            'Peingeist und Kettenschinder, dazu die zehn Etagenbosse bis Ignaroth. „Im Raum testen“ ruft das Monster neben dich ins Spielfeld.</p>')
# the crypt's mimic, in hell wood (the game draws assets/sprites/hell/monsters/mimik.png the same way)
MIMIC = r"""
(function () {
  const H = window.HellMonsters, K = window.KryptaMonsters;
  H.DEFS.mimik = K.DEFS.mimik;
  const render = H.render, frames = H.frameCount;
  const wood = t => [42 + t * 80, 22 + t * 44, 26 + t * 32];
  H.render = function (id, a, f) {
    if (id !== 'mimik') return render(id, a, f);
    const r = K.render(id, a, f), d = r.data;
    for (let i = 0; i < d.length; i += 4) {
      if (!d[i + 3]) continue;
      const R = d[i], G = d[i + 1], B = d[i + 2], mx = Math.max(R, G, B), mn = Math.min(R, G, B), v = mx / 255, s = mx ? (mx - mn) / mx : 0;
      const gold = R > 200 && G > 150 && B < 120, white = s < .2 && v > .8, pink = R > 180 && B > 110 && G < 150;
      if (v < .2 || gold || white || pink) continue;
      const c = wood((.299 * R + .587 * G + .114 * B) / 255);
      d[i] = c[0]; d[i + 1] = c[1]; d[i + 2] = c[2];
    }
    return r;
  };
  H.frameCount = (def, a) => def === K.DEFS.mimik ? K.frameCount(def, a) : frames(def, a);
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
# the crypt's monster module, kept apart as window.KryptaMonsters for the mimic
krypta_monsters = text(KRYPTA, 'krypta_monsters.js').replace('root.HellMonsters = factory(root.KRYPTA_PIX)', 'root.KryptaMonsters = factory(root.KRYPTA_PIX)')
assert 'root.KryptaMonsters' in krypta_monsters
monsters = krypta_monsters + '\n' + text(HERE, 'hell_monsters.js') + '\n' + text(HERE, 'drake_hybrid.js') + '\n' + MIMIC
for key, val in (('__ASSETS__', json.dumps(assets)), ('__SIZES__', json.dumps(sizes)), ('__CORE__', text(ROOT, 'tools', 'world_kit', 'world_core.js')),
                 ('__PIX__', text(KRYPTA, 'krypta_pix.js')), ('__FLOORS__', text(ROOT, 'tools', 'world_kit', 'world_pack.js') + '\n' + text(HERE, 'hell_world.js')),
                 ('__MONSTERS__', monsters)):
    assert key in html, key
    html = html.replace(key, val)
open(out, 'w', encoding='utf-8').write(html)
print(len(assets), 'assets,', round(len(html) / 1e6, 2), 'MB ->', out)
