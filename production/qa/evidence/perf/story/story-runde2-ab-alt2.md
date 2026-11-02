# Story-Welten: Rechenzeit (alt2)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 317 | 25.25 | 35.37 | 86.06 | 64.57 | 1.05 | 1.21 | 489 |
| hoelle | 269 | 29.70 | 44.43 | 98.77 | 71.07 | 1.24 | 1.46 | 598 |
| frostgruft | 225 | 35.57 | 46.79 | 176.64 | 107.86 | 1.51 | 1.63 | 744 |

## krypta

- u.feel: 3.74 ms
- tg.gas_sync: 0.95 ms
- tg.pools_sync: 0.91 ms
- u.talents: 0.76 ms
- te.blink: 0.68 ms
- u.hero+items: 0.66 ms
- glow.frame: 0.64 ms
- u.embers+elements: 0.51 ms
- u.rigs: 0.42 ms
- u.zones+world: 0.26 ms
- u.blockers+torches: 0.25 ms
- u.player: 0.25 ms
- te.impacts: 0.21 ms
- u.wreck+camera: 0.16 ms
- u.mobs: 0.15 ms
- tg.traps: 0.13 ms
- da.under: 0.13 ms
- d.actors: 0.12 ms
- tg.observe: 0.08 ms
- d.glow: 0.08 ms
- u.kits+moves: 0.08 ms
- te.cast: 0.05 ms
- te.explosion: 0.03 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 4.46 ms
- tg.pools_sync: 1.22 ms
- tg.gas_sync: 1.07 ms
- u.talents: 0.79 ms
- u.rigs: 0.69 ms
- glow.frame: 0.68 ms
- u.hero+items: 0.65 ms
- te.blink: 0.61 ms
- u.embers+elements: 0.53 ms
- u.zones+world: 0.36 ms
- te.impacts: 0.32 ms
- u.mobs: 0.25 ms
- u.blockers+torches: 0.25 ms
- d.actors: 0.24 ms
- u.player: 0.23 ms
- u.wreck+camera: 0.14 ms
- tg.traps: 0.14 ms
- da.under: 0.12 ms
- tg.observe: 0.11 ms
- d.glow: 0.08 ms
- u.kits+moves: 0.07 ms
- te.cast: 0.05 ms
- te.explosion: 0.05 ms
- u.shots: 0.03 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## frostgruft

- u.feel: 5.36 ms
- tg.pools_sync: 1.40 ms
- tg.gas_sync: 1.24 ms
- u.talents: 1.22 ms
- u.zones+world: 1.17 ms
- u.mobs: 0.91 ms
- u.rigs: 0.91 ms
- u.embers+elements: 0.85 ms
- te.blink: 0.68 ms
- u.hero+items: 0.65 ms
- glow.frame: 0.46 ms
- te.impacts: 0.46 ms
- d.chunks: 0.34 ms
- u.player: 0.26 ms
- u.blockers+torches: 0.25 ms
- te.explosion: 0.16 ms
- u.wreck+camera: 0.15 ms
- d.actors: 0.15 ms
- da.under: 0.14 ms
- u.kits+moves: 0.13 ms
- tg.observe: 0.13 ms
- d.snow_ao: 0.10 ms
- d.glow: 0.07 ms
- te.crit: 0.06 ms
- te.cast: 0.06 ms
- d.snow_lip: 0.04 ms
- d.snow_front: 0.02 ms
- tg.traps: 0.02 ms
- te.pet_strike: 0.01 ms
- tg.zones: 0.01 ms
- u.shots: 0.01 ms
- sg.gas_sync: 0.01 ms

