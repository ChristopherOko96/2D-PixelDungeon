# Story-Welten: Rechenzeit (runde2-vorher1)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 367 | 21.77 | 33.84 | 73.19 | 54.40 | 0.93 | 0.50 | 548 |
| hoelle | 278 | 28.68 | 43.11 | 98.38 | 69.58 | 1.20 | 2.01 | 599 |
| frostgruft | 225 | 35.58 | 50.17 | 201.88 | 102.13 | 1.52 | 2.20 | 812 |

## krypta

- u.feel: 3.29 ms
- u.talents: 0.82 ms
- tg.gas_sync: 0.76 ms
- tg.pools_sync: 0.72 ms
- te.blink: 0.60 ms
- u.hero+items: 0.54 ms
- glow.frame: 0.54 ms
- u.embers+elements: 0.40 ms
- u.rigs: 0.38 ms
- te.impacts: 0.26 ms
- u.blockers+torches: 0.22 ms
- u.zones+world: 0.21 ms
- u.player: 0.20 ms
- u.mobs: 0.16 ms
- u.wreck+camera: 0.14 ms
- tg.traps: 0.11 ms
- da.under: 0.11 ms
- d.actors: 0.10 ms
- tg.observe: 0.07 ms
- u.kits+moves: 0.07 ms
- d.glow: 0.06 ms
- te.explosion: 0.05 ms
- te.cast: 0.04 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 4.36 ms
- tg.pools_sync: 1.10 ms
- tg.gas_sync: 1.02 ms
- u.talents: 0.75 ms
- u.rigs: 0.69 ms
- glow.frame: 0.67 ms
- u.hero+items: 0.64 ms
- te.blink: 0.61 ms
- u.embers+elements: 0.51 ms
- u.zones+world: 0.36 ms
- te.impacts: 0.29 ms
- u.mobs: 0.27 ms
- u.player: 0.24 ms
- u.blockers+torches: 0.24 ms
- d.actors: 0.23 ms
- u.wreck+camera: 0.15 ms
- tg.traps: 0.14 ms
- da.under: 0.12 ms
- tg.observe: 0.10 ms
- d.glow: 0.08 ms
- u.kits+moves: 0.07 ms
- te.explosion: 0.06 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.01 ms

## frostgruft

- u.feel: 5.09 ms
- u.zones+world: 1.70 ms
- tg.pools_sync: 1.37 ms
- tg.gas_sync: 1.17 ms
- u.talents: 1.05 ms
- u.mobs: 0.92 ms
- u.embers+elements: 0.80 ms
- u.rigs: 0.79 ms
- te.blink: 0.63 ms
- u.hero+items: 0.62 ms
- d.chunks: 0.54 ms
- glow.frame: 0.45 ms
- te.impacts: 0.43 ms
- u.blockers+torches: 0.25 ms
- u.player: 0.25 ms
- te.explosion: 0.16 ms
- d.snow_ao: 0.15 ms
- d.actors: 0.15 ms
- tg.observe: 0.15 ms
- u.wreck+camera: 0.14 ms
- da.under: 0.14 ms
- u.kits+moves: 0.14 ms
- d.snow_lip: 0.07 ms
- te.crit: 0.06 ms
- d.glow: 0.06 ms
- te.cast: 0.06 ms
- d.snow_front: 0.03 ms
- tg.zones: 0.01 ms
- u.shots: 0.01 ms
- tg.traps: 0.01 ms
- te.pet_strike: 0.01 ms
- sg.gas_sync: 0.01 ms

