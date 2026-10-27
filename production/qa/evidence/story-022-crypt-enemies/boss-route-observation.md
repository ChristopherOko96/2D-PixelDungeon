# Boss-Routenregression: aufgezeichnete Tool-Beobachtung

Der erste abschließende Lauf von `tests/exploration_rules_test.gd` meldete:

```text
EXPLORATION_RULE_FAIL: boss resumes attack anticipation while stun cooldown remains active
EXPLORATION_RULE_FAIL: boss fires after the visible anticipation interval
EXPLORATION_RULES checked=85 failures=2
```

Dies ist der beobachtete Ausschnitt des Toolergebnisses; die damalige komplette
Arbeitslogdatei wurde vom finalen grünen Lauf überschrieben. Die Fixture
übernimmt einen normalen Gegner und setzt dessen `boss`-Markierung. Die neue
Rollen-AI fing diesen noch unter seinem alten `kind` ab. Der Bossstatus hat nun
ausdrücklich Vorrang in Rollen-AI und Schildbehandlung. Die Fixture blieb
unverändert; der Abschlusslauf meldet85Prüfungen,0Fehler in `exploration.log`.
