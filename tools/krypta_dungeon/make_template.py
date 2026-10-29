"""Derives the crypt preview page from the Hell-Dungeon preview (tools/hell_dungeon/preview_template.html).

The game logic stays the hell one; this swaps wording, colours and the data hooks (crypt floors,
crypt monsters, packed figures). Every replacement must match, so a changed hell template fails
loudly instead of silently keeping hell text.

Usage (repo root): py -3 -I tools/krypta_dungeon/make_template.py tools/hell_dungeon/preview_template.html tools/krypta_dungeon/krypta_template.html
"""
import sys

SRC, OUT = sys.argv[1], sys.argv[2]

R = [
    # ---------- page frame ----------
    ('<title>Hell-Dungeon Etagen</title>', '<title>Krypta Etagen</title>'),
    ('/* Layout: one dark forge-room page;', '/* Layout: one dark crypt page;'),
    ('--bg: #0d0809;', '--bg: #0a090d;'), ('--panel: #180f11;', '--panel: #14121a;'), ('--panel-2: #22151a;', '--panel-2: #1c1924;'),
    ('--line: #3b2328;', '--line: #332e3e;'), ('--ink: #f1e4d8;', '--ink: #ece6dc;'), ('--muted: #b89c8e;', '--muted: #a8a0b0;'),
    ('--ember: #ff6b2c;', '--ember: #c9a24a;'), ('--ember-soft: #ffb36b;', '--ember-soft: #e6cf96;'),
    ('background: #4a1b12; border-color: var(--ember); color: #ffe2c8;', 'background: #3a3046; border-color: var(--ember); color: #f3e6c4;'),
    ('color: #ffe2c8; background: #3a1a12;', 'color: #f3e6c4; background: #2c2536;'), ('background: #3a1a12;', 'background: #2c2536;'),
    ('background: #050304;', 'background: #040306;'), ('background: #0b0607;', 'background: #08070b;'), ('background: #070405;', 'background: #050408;'),
    ('color: #ffe2c8; }', 'color: #f3e6c4; }'), ('border-color: #6b2a18; background: linear-gradient(180deg, #24120f, var(--panel));', 'border-color: #4a3d5c; background: linear-gradient(180deg, #1e1a28, var(--panel));'),
    ('<span class="eyebrow" id="eyebrow">Hell-Dungeon</span>', '<span class="eyebrow" id="eyebrow">Krypta der Verdammten</span>'),
    ('<h1 id="floor-title">Aschenvorhof, Etage 1</h1>', '<h1 id="floor-title">Vorhalle der Verdammten, Etage 1</h1>'),
    ('Zehn Etagen, je tiefer desto heißer und härter. Der kürzeste Weg zum Boss braucht nie alle Räume. Wer erkundet, findet Tresore, Herzcontainer, Runensteine und Abkürzungen. Neu: acht Monsterarten und zehn Bosse im 0x72-Stil, siehe Bestiarium unten. Die Spielfigur ist noch ein Platzhalter.',
     'Story 1 neu gebaut: zehn Gruft-Etagen mit Weltkarte, Rätseln und Dungeon-Logik des Hell-Dungeons, ausgestattet mit dem neuen Krypta-Asset-Set. Jeder Lauf würfelt eine neue Welt: neue Räume, Wege und Verstecke, aber dieselben Etagen und Bosse. Je tiefer, desto mehr Moder, Fallen und Untote. Der kürzeste Weg zum Boss braucht nie alle Räume; wer erkundet, findet Reliquienschreine, Herzcontainer, Kristalle und Abkürzungen. Gegner und Bosse sind die der bisherigen Krypta. Die Spielfigur ist noch ein Platzhalter.'),
    ('<p>Alle Monster der Hölle im Stil des 0x72-Sets: dieselbe Palette, 1 px dunkler Umriss, Licht von oben links. Ignaroth wächst über vier Etagen vom Salamander zum Obsidiandrachen. Jede Karte spielt ihre Animationen ab;',
     '<p>Die Gegner der bisherigen Krypta: Skelette, Nekromant, Zombies, Mimik und Leerenbomber, dazu Moderkoloss, Frostleiche, Knochenkoloss und der Leerenrufer, ergänzt um sechs Etagenbosse aus denselben Figuren. Jede Karte spielt ihre Animationen ab;'),
    ('<h3 class="best-sub">Ignaroth · ein Drache, vier Phasen</h3>', '<h3 class="best-sub" hidden>Gruftherren</h3>'),
    ('<div class="cards lord" id="best-lord"></div>', '<div class="cards lord" id="best-lord" hidden></div>'),
    ('<dt>Kampfräume</dt><dd>Betreten verriegelt alle Türen, der Sieg öffnet sie. Oft fällt ein Herz oder Runenstein.</dd>',
     '<dt>Kampfräume</dt><dd>Betreten verriegelt alle Türen, der Sieg öffnet sie. Oft fällt ein Herz oder Seelenkristall.</dd>'),
    ('<dt>Farbschlüssel</dt><dd>Glut (Hauptweg), Knochen (Beutekammer), Dämon (Boss). Jeder passt nur in sein Tor.</dd>',
     '<dt>Schlüssel</dt><dd>Bronze (Hauptweg), Silber (Beutekammer), Gold (Bossgruft). Jeder passt nur in sein Tor.</dd>'),
    ('<dt>Feuerschalen</dt><dd>über mehrere Räume verteilt. Brennen alle, öffnet sich das Gitter zum Riesentresor mit Herzcontainer.</dd>',
     '<dt>Seelenschalen</dt><dd>über mehrere Räume verteilt. Brennen alle, öffnet sich das Gitter zum Reliquienschrein mit Herzcontainer.</dd>'),
    ('<dt>Dämonensiegel</dt><dd>ab Etage 4, 3–4 je Etage. Acht Treffer: Zufall zwischen dauerhaftem Segen (Schaden, Feuerrate, Tempo, Reichweite, Herzcontainer) und drei Dämonen.</dd>',
     '<dt>Grabsiegel</dt><dd>ab Etage 4, 3–4 je Etage. Acht Treffer: Zufall zwischen dauerhaftem Segen (Schaden, Feuerrate, Tempo, Reichweite, Herzcontainer) und drei Untoten.</dd>'),
    ('<dt>Monster</dt><dd>jede Etage hat ihren eigenen Mix aus acht Arten. Rote Linien und glühende Kreise warnen vor Angriffen: aus ihnen herauslaufen.</dd>',
     '<dt>Monster</dt><dd>jede Etage hat ihren eigenen Mix aus acht Arten der Krypta. Rote Linien und leuchtende Kreise warnen vor Angriffen: aus ihnen herauslaufen.</dd>'),
    ('<dt>Bosse</dt><dd>sechs eigene Etagenbosse. Auf Etage 3, 6, 9 und 10 kehrt Ignaroth zurück: vom flinken Salamander bis zum Obsidiandrachen. Bei 0 LP verwandelt er sich und flieht, erst auf Etage 10 stirbt er.</dd>',
     '<dt>Bosse</dt><dd>zehn Etagenbosse. Die bekannten Krypta-Bosse warten auf Etage 3 (Moderkoloss), 6 (Frostleiche), 9 (Knochenkoloss) und 10 (Leerenrufer), dazwischen sechs neue aus den Figuren der Krypta.</dd>'),
    ('<dt>In der Luft</dt><dd>ab Phase 3 fliegt Ignaroth auf. Solange er in der Luft ist, treffen ihn keine Schüsse: den Bombenkreisen ausweichen und auf die Landung warten.</dd>',
     '<dt>Moder</dt><dd>grüner Giftschlamm statt Lava: kostet ein Herz pro Schritt. Brücken und Stege führen hinüber, Grabgasschlote stoßen im Takt giftige Wolken aus.</dd>'),
    ('<dt>Tiefer</dt><dd>mehr Lava, Stacheln und Schlote, zähere Gegner und mehr Arten pro Raum.</dd>',
     '<dt>Tiefer</dt><dd>mehr Moder, Stacheln und Schlote, zähere Gegner und mehr Arten pro Raum.</dd>'),
    # ---------- data hooks ----------
    ('<script>__MONSTERS__</script>', '<script>__PIX__</script>\n<script>__FLOORS__</script>\n<script>__MONSTERS__</script>'),
    ('const HC = window.HellCore, C = HC.C;', 'const HC = window.HellCore, KF = window.KryptaFloors, C = HC.C;'),
    # one run number per playthrough decides all ten layouts; N rolls a new world
    ('  W = HC.buildFloor(n, SIZES);', '  W = KF.dress(HC.buildFloor(n, SIZES, KF.forRun(RUN)));'),
    ('let W, COLS, ROWS, grid,', 'let RUN = KF.newRun();\nlet W, COLS, ROWS, grid,'),
    ("sub: 'Etage ' + n + ' · ' + W.circle, t: 0 },", "sub: 'Etage ' + n + ' · ' + W.circle + ' · Welt ' + RUN, t: 0 },"),
    ("  else if (l === 'r') loadFloor(state.floor, false);", "  else if (l === 'r') loadFloor(state.floor, false);\n  else if (l === 'n') newWorld();"),
    ("btn('b-reset').onclick = () => { loadFloor(state.floor, false); cv.focus(); };",
     "btn('b-reset').onclick = () => { loadFloor(state.floor, false); cv.focus(); };\nbtn('b-run').onclick = () => { newWorld(); cv.focus(); };\nfunction newWorld() { RUN = KF.newRun(); loadFloor(1, false); toast('Neue Welt ' + RUN + ': alle zehn Etagen neu gewürfelt.'); }"),
    ('<button id="b-reset" type="button"><kbd>R</kbd> Etage neu</button>', '<button id="b-reset" type="button"><kbd>R</kbd> Etage neu</button>\n      <button id="b-run" type="button"><kbd>N</kbd> Neue Welt würfeln</button>'),
    ('<dt>Kampfräume</dt>', '<dt>Welt</dt><dd>wird bei jedem Lauf neu gewürfelt: zehn Etagen mit neuen Räumen, Wegen, Rätseln und Verstecken. Etagennamen, Bosse und Schwierigkeit bleiben gleich. Die Weltnummer steht im Etagenbanner; <kbd>N</kbd> würfelt neu.</dd>\n          <dt>Kampfräume</dt>'),
    ("b.title = HC.FLOORS[n].title + ' · ' + HC.CIRCLES[HC.FLOORS[n].circle];", "b.title = KF.FLOORS[n].title + ' · ' + KF.CIRCLES[KF.FLOORS[n].circle];"),
    ("A: { name: 'Glutschlüssel', filter: 'none', color: '#ff8a3c',", "A: { name: 'Bronzeschlüssel', filter: 'sepia(1) saturate(1.6) hue-rotate(-18deg) brightness(.82)', color: '#cd8a4a',"),
    ("B: { name: 'Knochenschlüssel', filter: 'grayscale(1) brightness(1.7)', color: '#e8dccb',", "B: { name: 'Silberschlüssel', filter: 'grayscale(1) brightness(1.5)', color: '#d8dde6',"),
    ("C: { name: 'Dämonenschlüssel', filter: 'hue-rotate(235deg) saturate(1.7)', color: '#b07cff',", "C: { name: 'Goldschlüssel', filter: 'none', color: '#f2c94c',"),
    ("function shotColor(m) { return m.id === 'peingeist' || m.id === 'klagender_hueter' || m.id === 'drache4' || m.echo !== undefined ? 'void' : m.id === 'aschenpriester' || m.id === 'seelenhirte' ? 'soul' : 'fire'; }",
     "function shotColor(m) { return m.echo !== undefined ? 'void' : m.def.shot || 'bone'; }"),
    ("c: m.id === 'kesselbrut' || m.id === 'glutwaechter' ? 'lava' : 'fire' });", "c: m.def.pool ? 'lava' : shotColor(m) });"),
    ("c: m.id === 'magmaschleim' ? 'lava' : 'fire' });", "c: m.def.pool ? 'lava' : shotColor(m) });"),
    ("if (m.id === 'magmaschleim' || m.id === 'glutwaechter') zones.push(", "if (m.def.pool) zones.push("),
    ("const kind = state.floor >= 6 ? 'kettenschinder' : 'brandskelett';", "const kind = state.floor >= 6 ? 'skelettwache' : 'skelett';"),
    ("toast('Das Siegel bricht: drei Dämonen springen heraus! Die Gitter fallen.');", "toast('Das Grabsiegel bricht: drei Untote steigen heraus! Die Gitter fallen.');"),
    ("const SHOT_COL = { fire: ['255,200,200', '230,40,30', '120,0,0'],",
     "const SHOT_COL = { bone: ['255,250,235', '214,196,160', '90,70,50'], poison: ['230,255,190', '120,200,60', '20,70,10'], frost: ['240,255,255', '110,210,240', '20,60,120'], gold: ['255,250,210', '250,200,60', '120,70,0'], fire: ['255,200,200', '230,40,30', '120,0,0'],"),
    ("lava: ['255,240,180', '255,140,30', '140,40,0'],", "lava: ['230,255,190', '120,200,60', '20,70,10'],"),
    # ---------- wording in play ----------
    ("(W.final ? 'Die Hölle verlassen' : 'Portal zu Etage ' + (state.floor + 1))", "(W.final ? 'Die Krypta verlassen' : 'Treppe hinab zu Etage ' + (state.floor + 1))"),
    ("'Portal erloschen'", "'Treppe versperrt'"),
    ("label: roomOf(e).fight ? 'Erst die Gegner besiegen' : 'Feuerschale entzünden'", "label: roomOf(e).fight ? 'Erst die Gegner besiegen' : 'Seelenschale entzünden'"),
    ("'Gittertor: alle Feuerschalen der Etage entzünden'", "'Gittertor: alle Seelenschalen der Etage entzünden'"),
    ("'Rätseltor: alle Feuerschalen e", "'Rätseltor: alle Seelenschalen e"),
    ("toast('Die Platten glühen auf. Eine Belohnungstruhe erscheint!');", "toast('Die Grabplatten leuchten auf. Eine Belohnungstruhe erscheint!');"),
    ("toast(G.spread ? 'Alle Feuerschalen brennen. Das Gitter zum Riesentresor hebt sich!' : 'Alle Schalen brennen. Das Tor hebt sich.');", "toast(G.spread ? 'Alle Seelenschalen brennen. Das Gitter zum Reliquienschrein hebt sich!' : 'Alle Schalen brennen. Das Tor hebt sich.');"),
    ("'Feuerschale ' + s.done + ' von ' + s.all + ' auf dieser Etage' : 'Feuerschale ' + s.done", "'Seelenschale ' + s.done + ' von ' + s.all + ' auf dieser Etage' : 'Seelenschale ' + s.done"),
    ("text: 'Höllenfeuer: +1 Schaden'", "text: 'Weihefeuer: +1 Schaden'"), ("text: 'Glutläufer: 10 % schneller laufen'", "text: 'Grabläufer: 10 % schneller laufen'"),
    ("hurt(1, 'in der Lava verbrannt');", "hurt(1, 'im Moder versunken');"), ("hurt(1, 'vom Glutschlot verbrannt');", "hurt(1, 'vom Grabgas vergiftet');"),
    ("W.final ? 'Die Hölle ist bezwungen' : 'Etage '", "W.final ? 'Die Krypta ist befreit' : 'Etage '"),
    ("return 'alle Feuerschalen entzünden (in ' + list + ')';", "return 'alle Seelenschalen entzünden (in ' + list + ')';"),
    ("t.push('Nach dem Boss: Truhe öffnen und durchs Portal' + (W.final ? ' – das Ende der Hölle.' : ' zur nächsten Etage.'));", "t.push('Nach dem Boss: Truhe öffnen und die Treppe hinab' + (W.final ? ' – das Ende der Krypta.' : ' zur nächsten Etage.'));"),
    ("'Erloschene Feuerschale entzünden (E) – eine von '", "'Erloschene Seelenschale entzünden (E) – eine von '"),
    ("' Feuerschalen entzünden (E), nach dem Kampf.'", "' Seelenschalen entzünden (E), nach dem Kampf.'"),
    ("t.push('Dämonensiegel: anschießen (8 Treffer). Zufall: dauerhafter Segen oder drei Dämonen, die den Raum erneut verriegeln.');", "t.push('Grabsiegel: anschießen (8 Treffer). Zufall: dauerhafter Segen oder drei Untote, die den Raum erneut verriegeln.');"),
    ("hz.push('Glutschlote');", "hz.push('Grabgasschlote');"), ("hz.push('Lava');", "hz.push('Moder');"),
    ("Dämonensiegel</b> in ${", "Grabsiegel</b> in ${"), ("je 8 Treffer, Segen oder drei Dämonen.`", "je 8 Treffer, Segen oder drei Untote.`"),
    ("'Riesentresor'], ['#3b2f52', 'Schlüsselraum']", "'Reliquienschrein'], ['#3b2f52', 'Schlüsselraum']"),
    ("[fs.done + '/' + fs.all, 'Feuerschalen']", "[fs.done + '/' + fs.all, 'Seelenschalen']"),
    ("notes.push('Feuerschalen sind über die Etage verteilt und öffnen den Riesentresor.');", "notes.push('Seelenschalen sind über die Etage verteilt und öffnen den Reliquienschrein.');"),
    ("'Hell-Dungeon · ' + W.circle", "'Krypta der Verdammten · ' + W.circle + ' · Welt ' + RUN"),
    # ---------- colours in play: poison mire, grave gas, cold grade ----------
    ("ctx.fillStyle = '#ffd27a'; ctx.fillRect(x * C, y * C, C, C);", "ctx.fillStyle = '#c8ff8a'; ctx.fillRect(x * C, y * C, C, C);"),
    ("lctx.fillStyle = `rgba(6,2,4,${W.theme.dark})`;", "lctx.fillStyle = `rgba(4,4,9,${W.theme.dark})`;"),
    ("if (e.type === 'portal' && e.active) all.push({ x: e.x, y: e.y - 60, r: 330, c: '255,60,40', f: 2 });", "if (e.type === 'portal' && e.active) all.push({ x: e.x, y: e.y - 60, r: 330, c: '110,170,255', f: 2 });"),
    ("if (e.type === 'vent' && e.burst) all.push({ x: e.x, y: e.y - 30, r: 220, c: '255,120,40', f: 1 });", "if (e.type === 'vent' && e.burst) all.push({ x: e.x, y: e.y - 30, r: 220, c: '130,230,100', f: 1 });"),
    ("c: shotColor(m) === 'void' ? '170,80,255' : shotColor(m) === 'soul' ? '120,230,90' : '255,110,40', f: m.seed });", "c: (SHOT_COL[shotColor(m)] || SHOT_COL.bone)[1], f: m.seed });"),
    ("for (const z of zones) if (z.kind === 'puddle' || (z.kind === 'meteor' && z.t >= z.tele)) all.push({ x: z.x, y: z.y, r: z.r * 2, c: '255,120,40', f: 1 });", "for (const z of zones) if (z.kind === 'puddle' || (z.kind === 'meteor' && z.t >= z.tele)) all.push({ x: z.x, y: z.y, r: z.r * 2, c: z.kind === 'puddle' ? '120,220,80' : '140,210,255', f: 1 });"),
    ("glows.push([sx, sy, r * .8, '255,90,30']);", "glows.push([sx, sy, r * .8, '110,210,70']);"),
    ("ctx.fillStyle = p.gold ? '#ffe28a' : p.ash ? '#ff5a2a' : p.big ? '#ff7a2a' : '#ffb347';", "ctx.fillStyle = p.gold ? '#ffe28a' : p.ash ? '#8f8aa3' : p.big ? '#a6ec6e' : '#c9f59c';"),
    ("// deeper floors: red grade and a burning vignette", "// deeper floors: a cold violet grade and a dark vignette"),
    ("ctx.fillStyle = `rgba(140,10,0,${th.grade})`;", "ctx.fillStyle = `rgba(40,20,90,${th.grade})`;"),
    ("vg.addColorStop(0, 'rgba(60,0,0,0)'); vg.addColorStop(1, `rgba(${60 + th.wallGlow * 60},0,0,${th.vignette})`);", "vg.addColorStop(0, 'rgba(10,6,24,0)'); vg.addColorStop(1, `rgba(${10 + th.wallGlow * 20},6,${24 + th.wallGlow * 40},${th.vignette})`);"),
    ("ctx.fillStyle = `rgba(255,120,30,${.42 * a})`; ctx.beginPath(); ctx.ellipse(z.x, z.y, z.r, z.r * .55, 0, 0, 7); ctx.fill(); ctx.fillStyle = `rgba(255,220,120,${.35 * a})`;",
     "ctx.fillStyle = `rgba(90,170,40,${.42 * a})`; ctx.beginPath(); ctx.ellipse(z.x, z.y, z.r, z.r * .55, 0, 0, 7); ctx.fill(); ctx.fillStyle = `rgba(200,250,140,${.35 * a})`;"),
    ("col = z.c === 'lava' ? '255,150,40' : z.c === 'void' ? '180,90,255' : '255,90,30';", "col = (SHOT_COL[z.c] || SHOT_COL.bone)[1];"),
]


def main():
    s = open(SRC, encoding='utf-8').read()
    bad = []
    for a, b in R:
        if a not in s:
            bad.append(a)
        s = s.replace(a, b)
    if bad:
        sys.exit('hell template changed, these no longer match:\n  ' + '\n  '.join(b[:120] for b in bad))
    open(OUT, 'w', encoding='utf-8').write(s)
    print(len(R), 'replacements ->', OUT)


if __name__ == '__main__':
    main()
