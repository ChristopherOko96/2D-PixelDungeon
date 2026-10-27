# Lesbare Pixelschrift, Vollbild und GameDev-Review

**Fortschreibung:** Die danach beauftragten technischen Schritte sind inzwischen
umgesetzt: Clientglättung, Versionsabgleich und aktuelle Solo-/Zwei-/Vierer-
Kampagnenprüfungen einschließlich UDP-Störung und sichtbarer Bildzeitmessung.
[Ergebnisse und verbleibende LAN-/Nutzerabnahme](GAMEDEV-UMSETZUNG.de.md).

Stand:26.10.2026. Story018, lokal auf `codex_v2`. Die angeforderten Änderungen
sind umgesetzt; im konkreten Schrift-/Vollbildreview blieb kein blockierender
Befund. Die vollständige spielerische Abnahme ist ein eigener nächster Schritt.

## Schrift und Darstellung

**Pixel Operator8** von Jayvee Enaguas ersetzt Pixelify Sans als aktive Schrift.
Die Originaldatei und vollständige CC0-Lizenz liegen lokal unter `assets/fonts/`.
[Autorveröffentlichung](https://www.dafont.com/pixel-operator.font),
[Herkunft und Prüfsumme](../assets/fonts/PROVENANCE.md).
Deutsche Umlaute,ß,€,Mittelpunkte und Auslassungszeichen wurden mit Godots
tatsächlichem Font geprüft. Es gibt keinen stillen Systemschrift-Ersatz.
16/24/32px sind2×/3×/4× des8px-Rasters. Nearest-Filter und abgeschaltete
Schriftglättung erhalten die Pixelkonturen. Bei beliebigen Bildschirmfaktoren
bleibt die gesamte Fläche nutzbar; absolut gleich breite physische Pixel sind
nur bei passenden ganzzahligen Faktoren möglich.

Die Designbasis bleibt1280×720. Im Spiel füllt der sichtbare Weltausschnitt das
Fenster. Herzen liegen links oben; Raum-/Boss-/Gruppeninformationen bleiben im
ESC-Menü. F11, Alt+Enter und ESC→Anzeige schalten Vollbild um. Kamera,
Mauszielbereich und schwarze Raumblende verwenden die tatsächliche Sichtfläche.
Andere Seitenverhältnisse erweitern diese Fläche, statt die Figuren zu verzerren.
[Godot-Grundlage](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

## Review und Korrekturen

| Befund | Umgesetzte Korrektur |
| --- | --- |
| Neue Schrift breiter als Pixelify | Kompakte Lobbytexte, aktuelle Zehn-Raum-Angabe und besserer Zeilenabstand |
| Lange Perk-Namen mitten im Wort getrennt | Passende16/24px-Größe einheitlich pro Angebot; ganze Wörter |
| Kleine gerahmte Spielfläche | Welt auf voller Sichtfläche, HUD am Rand |
| Gefahr unbedeckter Ränder bei anderen Formaten | Vollflächige Menü-Dimmer/Inputschutz und dynamische Schwarzblende |
| Helle alte Lobbykammer trotz ruhigem Spielstil | Ruhiger Classic-Hintergrund auch ohne geladenen Raum |
| Menübutton liegt jetzt über dem Spielfeld | Interaktive UI sperrt Feuer bis zum Loslassen; Weltklicks bleiben erlaubt |

Gezielte tatsächliche GPU-Aufnahmen:1280×720-Fenster,1600×1000 mit erweiterter
logischer Höhe,1920×1080-Vollbild und ein breites Fenster. F11/Alt+Enter/ESC
gingen durch den vorhandenen Eingabehandler. Fensterrechteck wiederhergestellt;
Vollbild blieb beim Öffnen von ESC bestehen. Vier Ecken und Bildmitte der
schwarzen Raumblende waren schwarz. Übersicht, Anzeige, Kartenangebote und
Lobby wurden auf Textüberläufe angesehen und die gefundenen Stellen korrigiert.

[Vollbilddaten](../production/qa/evidence/readable-fullscreen/display-check.json),
[Vollbildansicht](../production/qa/evidence/readable-fullscreen/03-fullscreen-game.png),
[Anzeige-Menü](../production/qa/evidence/readable-fullscreen/04-fullscreen-display-menu.png),
[Belohnungskarten](../production/qa/evidence/readable-fullscreen/09-fullscreen-rewards.png).

Eine fokussierte lokale GUI-Eingabeprobe bestätigt: Weltklick aktiviert Feuer,
Menüklick nicht; gehaltenes Ziehen aus der UI bleibt gesperrt, nach Loslassen
aktiviert ein frischer Weltklick wieder Feuer.
[Eingabedaten](../production/qa/evidence/readable-fullscreen/pointer-guard.json).
Editor und HUD wurden ebenfalls auf16/24px-Raster und passende Textbereiche
umgestellt; kurze Werkzeugbeschriftungen besitzen ausführliche Tooltips.

Für Bilder war die Simulation angehalten; Belohnungsansichten verwenden einen
gezielten UI-Zustand. Das belegt keinen abgeschlossenen Raum oder Durchlauf.
Import und geänderte Skripte laden ohne Syntaxfehler. Keine breite Spiel-/Unit-/
Netzwerksuite und keine neue Mehrspieler-Leistungsmessung wurden ausgeführt.

Methodik: vorhandener [Studio-UX-Review](../.agents/skills/studio-ux-review/SKILL.md)
mit Game-Designer-/Producer-Briefs und Sichtprüfung. Ein formales UX-Spec-Gate
ist **NOT ASSESSED**: Es gibt keine verbindliche UX-Spezifikation und keinen
festgelegten Accessibility-Tier. Das ist keine Freigabe umfassender Barrierefreiheit.
Das konkrete Implementierungsreview oben ist davon getrennt.

## Damals abgeleitete nächste GameDev-Schritte

1. **Aktuellen Zehn-Raum-Lauf manuell abnehmen.** Du beurteilst Lesbarkeit,
   Vollbild, Bewegung und Raumgefühl. Dabei automatische Karten, E/Türen,
   Schwarzblenden, Rückwege, Boss ausschließlich in Raum10, Treppe und Neustart
   prüfen. Die ruhige Fassung bleibt ohne neue Dekoration bis zu deinem Stilfeedback.
2. **Clientdarstellung und Versionsabgleich umsetzen.** Der Host hat bereits
   lokale Physiktakt-Darstellung; Clients zeigen weiterhin20Hz-Snapshots ohne
   Interpolation (`game.gd:_presentation_state`). Ein verbindlicher Protokoll-/
   Inhaltsabgleich vor Aufnahme fehlt noch (`_peer_connected`); die übertragene
   Generatorversion ersetzt ihn nicht. Das sind die nächsten technischen Stories.
3. **Koop mit diesem Stand belegen.** Zuerst zwei, danach vier Teilnehmer;
   anschließend mindestens zwei echte LAN-Rechner, ein längerer kompletter Lauf
   und Bildzeitmessungen. Die älteren Viererbelege gelten für frühere Karten-/
   Netzwerkstände. Der Entwicklungsplan nennt als noch offene vorgeschlagene
   Ziele100ms RTT/1%Paketverlust und30Minuten LAN; sie sind nicht nachgewiesen.

Quelle: [Entwicklungsplan, Phasen4/5](../production/development-plan.md).
Der [Game Brief](../design/game-brief.md) ist auf zehn Karten, ruhigen32px-Stil
und die aktuelle UI fortgeschrieben. Keine neue Inhalts-/Deko-Phase ist begonnen.
