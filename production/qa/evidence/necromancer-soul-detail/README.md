# Seele-Effekte im Stil der vorhandenen Pfützen

31.10.2026. Nutzer lehnt die groben weißgrauen Effekte im Testraum ab und
verlangt Detailtiefe der vorhandenen Pfützen. Fokus bleibt Nekromant, Zweig
Seele. Keine neuen Angriffe oder Änderungen an Schaden, Mana, Reichweite,
Abklingzeit, Bossregeln oder Elementreaktionen.

## Umsetzung

- `talent_palette.gd`: eigener Türkis/Violett-Ramp für `soul`; zuvor fehlte
  der Zweig in SPEC_ELEMENT und fiel auf den grauweißen Stahl-Ramp zurück.
  Diener/Fluch erhalten ebenfalls ihre passenden vorhandenen Ramp-Zuordnungen.
- Seelensturm nutzt nun **denselben PoolPaint-Renderer** wie die vorhandenen
  Pfützen: neues Präsentationsmaterial `soul` in `vfx_pools.json`, Stil `void`,
  mit dunklem Kern, bewegten Strömungsbändern, Rand-/Oberflächenschattierung
  und zwei Blasen. Es gibt keinen `void_pull`-Eintrag und keine neuen
  Gameplayreaktionen. Überlappende Seelenflächen teilen ihre Materialfläche.
- Die bestehenden 24 Ghost-Frames bleiben erhalten; nur die frühere flache
  Rasterfeld-Oberfläche wird im Cache aus der Geisterebene entfernt. Unter
  den Geistern liegt der tatsächliche Pfützen-Renderer. Ohne verfügbaren
  PoolPaint bleibt die vorherige vollständige Animationsfläche als Fallback.
- Seelennova und Seelenernte: eigene 24-phasige Wellen mit dunkler Lippe,
  heller Krone, strukturiertem Körper, bewegten Adern und sparsamen Glanzpunkten.
  Kein großflächiges Weiß-/Schraffur-Overlay. Lokale Texturen und bestehender
  Wand-Clip werden wiederverwendet.
- Seelensprung: entsprechende Wellen an Start und Ziel. Seelenblitz/-lanze
  verwenden ihre bestehenden Formen, nun in derselben Seelenfarbsprache.
- Seelenschild: bestehende elastische Kuppel in Seelenfarben statt Eisblau;
  der alte zusätzliche weißviolette Bubble-Cast ist durch eine kleine Welle
  ersetzt. Der Host sendet die bereits bekannte Talentkennung auch am
  Schild-Aura-Eintrag; keine Client-Schadensautorität oder neue Netzwerkgrafiken.
- Gemeinsamer Talent-Renderer für Krypta, Hölle und Frostgruft. Kein neuer
  Imagegen-Aufruf, kein neuer Figurenkatalog; vorhandene Art bleibt erhalten.

## Nachweise

`soul_detail_test`: 43/0. Farbzuordnung aller 14 Seele-Talente, echter
Pool-Materialstil, kein kosmetischer Pull, 24 unterschiedliche schattierte
Wellen, begrenzte Glanzpunkte und getrennte Geister-/Bodenebenen.
`soul_field_test`: 77/0. `talent_combat_test`: 339/0.
`hell_talents_test`: 18/0. Insgesamt 477 Prüfungen.

GPU-Fixtures mit gültigem Nekromant-Seele-Build:
`scripts/capture_mage_fireball.gd -- --soul --soul-detail`, Godot 4.7.2
Compatibility, 1280×720. Je eine Aufnahme von Blitz, Nova, Schild, Sprung,
Lanze, Ernte sowie 24 Phasen des Seelensturms. Zwischen den Einzelaufnahmen
werden Ressourcen/Position/Effekte im Fixture zurückgesetzt. Kein gespielter
Lauf, keine verdienten Fortschritte und keine LAN-/Lastabnahme. Der Fixture
setzt lokalen Hitstop zurück, damit die neue Aufnahme keinen alten Snapshot
enthält. Das Spielverhalten selbst wird dabei nicht geändert.

Logs: `Logs/soul-detail-*.log`. Die Game-Fixtures melden weiterhin den nicht
beschreibbaren user://-Shadercache und beim Beenden 6 ObjectDB-Instanzen /
2 Ressourcen. Kein sauberer Ressourcen-/Soak-Nachweis daraus. Keine
Geschmacksabnahme und keine neue FPS-Aussage. Kein Commit/Push/Merge.
