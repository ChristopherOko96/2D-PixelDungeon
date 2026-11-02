# Story-Welten: Rechenzeit (nachher)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 335 | 23.88 | 34.24 | 67.91 | 54.36 | 1.03 | 0.44 | 579 |
| hoelle | 296 | 26.96 | 38.65 | 84.42 | 60.49 | 1.19 | 0.46 | 627 |
| frostgruft | 247 | 32.45 | 44.10 | 152.12 | 100.87 | 1.41 | 0.53 | 810 |

## krypta

- u.feel: 3.32 ms
- u.talents: 0.87 ms
- tg.gas_sync: 0.80 ms
- tg.pools_sync: 0.74 ms
- te.blink: 0.59 ms
- u.hero+items: 0.59 ms
- glow.frame: 0.56 ms
- u.embers+elements: 0.39 ms
- u.rigs: 0.38 ms
- te.impacts: 0.26 ms
- u.blockers+torches: 0.22 ms
- u.zones+world: 0.21 ms
- u.player: 0.21 ms
- u.mobs: 0.17 ms
- u.wreck+camera: 0.15 ms
- d.actors: 0.13 ms
- da.under: 0.11 ms
- tg.traps: 0.11 ms
- tg.observe: 0.08 ms
- d.glow: 0.07 ms
- u.kits+moves: 0.07 ms
- te.cast: 0.05 ms
- te.explosion: 0.04 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 3.85 ms
- tg.pools_sync: 0.91 ms
- tg.gas_sync: 0.88 ms
- u.talents: 0.63 ms
- glow.frame: 0.62 ms
- u.rigs: 0.62 ms
- u.hero+items: 0.59 ms
- te.blink: 0.56 ms
- u.embers+elements: 0.42 ms
- u.zones+world: 0.31 ms
- te.impacts: 0.28 ms
- u.mobs: 0.23 ms
- d.actors: 0.23 ms
- u.player: 0.22 ms
- u.blockers+torches: 0.21 ms
- u.wreck+camera: 0.13 ms
- tg.traps: 0.12 ms
- da.under: 0.11 ms
- tg.observe: 0.08 ms
- d.glow: 0.08 ms
- u.kits+moves: 0.07 ms
- te.explosion: 0.05 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## frostgruft

- u.feel: 4.56 ms
- u.zones+world: 1.27 ms
- tg.pools_sync: 1.11 ms
- tg.gas_sync: 1.02 ms
- u.talents: 0.95 ms
- u.mobs: 0.86 ms
- u.rigs: 0.72 ms
- u.embers+elements: 0.69 ms
- u.hero+items: 0.59 ms
- te.blink: 0.57 ms
- d.chunks: 0.42 ms
- glow.frame: 0.41 ms
- te.impacts: 0.40 ms
- u.player: 0.22 ms
- u.blockers+torches: 0.22 ms
- d.actors: 0.15 ms
- te.explosion: 0.14 ms
- u.kits+moves: 0.13 ms
- u.wreck+camera: 0.13 ms
- d.snow_ao: 0.12 ms
- da.under: 0.12 ms
- tg.observe: 0.11 ms
- d.glow: 0.06 ms
- d.snow_lip: 0.05 ms
- te.cast: 0.05 ms
- te.crit: 0.03 ms
- d.snow_front: 0.03 ms
- tg.traps: 0.02 ms
- tg.zones: 0.01 ms
- u.shots: 0.01 ms
- te.pet_strike: 0.01 ms
- sg.gas_sync: 0.01 ms

