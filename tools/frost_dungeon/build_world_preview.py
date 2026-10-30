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
    if name.startswith(('mob_', 'boss_golem', 'ally_', 'weapon_', 'rock_')):
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
    ("Grabsiegel</b> in ${", "Siegel</b> in ${"), ("Segen oder drei Untote.`", "Segen oder drei Frostwesen.`"),
    ("'Seelenschalen']", "'Frostflammen']"), ("'Seelenschalen sind über die Etage verteilt und öffnen den Reliquienschrein.'", "'Frostflammen sind über die Etage verteilt und öffnen den Frostflammen-Tresor.'"),
]
LEDE = ('<p class="lede">Story 2 auf dem Welt-Baukasten: zehn Eis-Etagen, die sich bei jedem Lauf neu bauen, hier in der neuen HD-Grafik. '
        'Etagen, Bosse und Gefahren bleiben die der Frostgruft; dazu kommen die festen Regeln der Welten: Schlüsselkammer mit Laden, '
        'Händler und Manabrunnen, das Prunktor von unten, Druckplatten mit Frosttresor, zerbrechliche Fässer, Urnen und Kisten und die '
        'Vergessene Stiege. Mimiks gibt es hier nicht. Die Gegner in dieser Vorschau sind Platzhalter aus der Krypta; im Spiel kämpfst '
        'du gegen die Frost-Gegner. Glatteis tut hier nicht weh, im Spiel rutschst du darauf.</p>')
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
open(out, 'w', encoding='utf-8').write(html)
print(len(assets), 'assets,', round(len(html) / 1e6, 2), 'MB ->', out)
