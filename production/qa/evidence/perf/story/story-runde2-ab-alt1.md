# Story-Welten: Rechenzeit (alt1)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 308 | 25.98 | 37.95 | 85.65 | 62.64 | 1.16 | 0.55 | 557 |
| hoelle | 272 | 29.34 | 43.11 | 95.43 | 68.11 | 1.23 | 0.52 | 597 |
| frostgruft | 225 | 35.47 | 47.37 | 175.55 | 113.40 | 1.59 | 0.51 | 853 |

## krypta

- u.feel: 3.85 ms
- tg.gas_sync: 1.02 ms
- tg.pools_sync: 0.94 ms
- u.talents: 0.77 ms
- te.blink: 0.71 ms
- u.hero+items: 0.68 ms
- glow.frame: 0.66 ms
- u.embers+elements: 0.51 ms
- u.rigs: 0.43 ms
- u.zones+world: 0.28 ms
- u.blockers+torches: 0.26 ms
- u.player: 0.24 ms
- te.impacts: 0.22 ms
- da.under: 0.19 ms
- u.wreck+camera: 0.16 ms
- u.mobs: 0.15 ms
- d.actors: 0.13 ms
- tg.traps: 0.12 ms
- d.glow: 0.09 ms
- tg.observe: 0.08 ms
- u.kits+moves: 0.08 ms
- te.cast: 0.05 ms
- te.explosion: 0.03 ms
- u.shots: 0.03 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 4.44 ms
- tg.pools_sync: 1.15 ms
- tg.gas_sync: 1.07 ms
- u.talents: 0.77 ms
- u.rigs: 0.71 ms
- glow.frame: 0.68 ms
- te.blink: 0.64 ms
- u.hero+items: 0.64 ms
- u.embers+elements: 0.52 ms
- u.zones+world: 0.38 ms
- te.impacts: 0.30 ms
- u.mobs: 0.25 ms
- u.blockers+torches: 0.24 ms
- u.player: 0.24 ms
- d.actors: 0.24 ms
- u.wreck+camera: 0.15 ms
- tg.traps: 0.14 ms
- da.under: 0.12 ms
- tg.observe: 0.10 ms
- d.glow: 0.09 ms
- u.kits+moves: 0.07 ms
- te.explosion: 0.05 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## frostgruft

- u.feel: 5.36 ms
- tg.pools_sync: 1.39 ms
- tg.gas_sync: 1.25 ms
- u.talents: 1.23 ms
- u.zones+world: 1.19 ms
- u.rigs: 0.93 ms
- u.mobs: 0.90 ms
- u.embers+elements: 0.82 ms
- u.hero+items: 0.66 ms
- te.blink: 0.64 ms
- te.impacts: 0.47 ms
- glow.frame: 0.46 ms
- d.chunks: 0.38 ms
- u.blockers+torches: 0.25 ms
- u.player: 0.25 ms
- te.explosion: 0.15 ms
- u.wreck+camera: 0.14 ms
- d.actors: 0.14 ms
- tg.observe: 0.14 ms
- u.kits+moves: 0.14 ms
- da.under: 0.13 ms
- d.snow_ao: 0.10 ms
- d.glow: 0.06 ms
- te.crit: 0.06 ms
- te.cast: 0.05 ms
- d.snow_lip: 0.04 ms
- d.snow_front: 0.02 ms
- tg.traps: 0.02 ms
- tg.zones: 0.01 ms
- te.pet_strike: 0.01 ms
- u.shots: 0.01 ms
- sg.gas_sync: 0.01 ms

