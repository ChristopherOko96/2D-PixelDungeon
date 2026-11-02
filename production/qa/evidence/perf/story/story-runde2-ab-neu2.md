# Story-Welten: Rechenzeit (neu2)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 337 | 23.74 | 34.76 | 57.21 | 44.26 | 1.07 | 0.97 | 524 |
| hoelle | 278 | 28.64 | 43.25 | 79.65 | 56.30 | 1.25 | 1.20 | 595 |
| frostgruft | 231 | 34.70 | 47.66 | 144.71 | 89.08 | 1.62 | 2.21 | 799 |

## krypta

- u.feel: 3.46 ms
- tg.gas_sync: 0.87 ms
- u.talents: 0.68 ms
- glow.frame: 0.64 ms
- u.hero+items: 0.64 ms
- te.blink: 0.62 ms
- u.embers+elements: 0.49 ms
- tg.pools_sync: 0.46 ms
- u.rigs: 0.36 ms
- te.impacts: 0.27 ms
- u.blockers+torches: 0.26 ms
- u.zones+world: 0.24 ms
- u.player: 0.24 ms
- u.wreck+camera: 0.14 ms
- tg.traps: 0.14 ms
- da.under: 0.13 ms
- d.actors: 0.12 ms
- u.mobs: 0.11 ms
- d.glow: 0.08 ms
- tg.observe: 0.08 ms
- u.kits+moves: 0.07 ms
- te.explosion: 0.06 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 4.14 ms
- tg.gas_sync: 1.07 ms
- u.talents: 0.75 ms
- glow.frame: 0.70 ms
- u.hero+items: 0.66 ms
- te.blink: 0.62 ms
- u.rigs: 0.62 ms
- tg.pools_sync: 0.57 ms
- u.embers+elements: 0.55 ms
- u.zones+world: 0.38 ms
- te.impacts: 0.33 ms
- d.actors: 0.25 ms
- u.blockers+torches: 0.25 ms
- u.player: 0.25 ms
- u.mobs: 0.21 ms
- u.wreck+camera: 0.15 ms
- tg.traps: 0.15 ms
- da.under: 0.14 ms
- tg.observe: 0.09 ms
- d.glow: 0.09 ms
- u.kits+moves: 0.08 ms
- te.explosion: 0.06 ms
- te.cast: 0.06 ms
- u.shots: 0.03 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## frostgruft

- u.feel: 5.01 ms
- tg.gas_sync: 1.23 ms
- u.talents: 1.18 ms
- u.zones+world: 1.15 ms
- u.embers+elements: 0.86 ms
- te.blink: 0.72 ms
- tg.pools_sync: 0.68 ms
- u.rigs: 0.66 ms
- u.mobs: 0.64 ms
- u.hero+items: 0.64 ms
- glow.frame: 0.48 ms
- te.impacts: 0.46 ms
- d.chunks: 0.35 ms
- u.blockers+torches: 0.26 ms
- u.player: 0.26 ms
- u.wreck+camera: 0.15 ms
- te.explosion: 0.15 ms
- d.actors: 0.15 ms
- da.under: 0.14 ms
- u.kits+moves: 0.14 ms
- tg.observe: 0.12 ms
- d.snow_ao: 0.10 ms
- d.glow: 0.07 ms
- te.crit: 0.06 ms
- te.cast: 0.06 ms
- d.snow_lip: 0.04 ms
- d.snow_front: 0.02 ms
- tg.traps: 0.02 ms
- tg.zones: 0.01 ms
- te.pet_strike: 0.01 ms
- u.shots: 0.01 ms
- sg.gas_sync: 0.01 ms

