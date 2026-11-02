# Story-Welten: Rechenzeit (vorher)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 325 | 24.59 | 37.58 | 74.27 | 81.93 | 1.05 | 0.44 | 578 |
| hoelle | 274 | 29.20 | 42.46 | 92.55 | 68.33 | 1.18 | 0.45 | 629 |
| frostgruft | 249 | 32.07 | 41.23 | 157.91 | 99.86 | 1.40 | 0.54 | 810 |

## krypta

- u.feel: 3.28 ms
- u.talents: 0.84 ms
- tg.gas_sync: 0.81 ms
- tg.pools_sync: 0.78 ms
- u.hero+items: 0.58 ms
- te.blink: 0.56 ms
- glow.frame: 0.55 ms
- u.rigs: 0.40 ms
- u.embers+elements: 0.39 ms
- te.impacts: 0.26 ms
- u.blockers+torches: 0.22 ms
- u.zones+world: 0.20 ms
- u.player: 0.20 ms
- u.mobs: 0.18 ms
- u.wreck+camera: 0.14 ms
- d.actors: 0.13 ms
- tg.traps: 0.11 ms
- da.under: 0.11 ms
- tg.observe: 0.08 ms
- d.glow: 0.07 ms
- u.kits+moves: 0.06 ms
- te.cast: 0.05 ms
- te.explosion: 0.04 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 4.05 ms
- tg.pools_sync: 1.10 ms
- tg.gas_sync: 0.97 ms
- u.talents: 0.65 ms
- u.rigs: 0.64 ms
- glow.frame: 0.62 ms
- u.hero+items: 0.61 ms
- te.blink: 0.57 ms
- u.embers+elements: 0.42 ms
- u.zones+world: 0.33 ms
- te.impacts: 0.29 ms
- d.actors: 0.23 ms
- u.mobs: 0.23 ms
- u.blockers+torches: 0.22 ms
- u.player: 0.22 ms
- u.wreck+camera: 0.14 ms
- tg.traps: 0.13 ms
- da.under: 0.11 ms
- tg.observe: 0.09 ms
- d.glow: 0.08 ms
- u.kits+moves: 0.07 ms
- te.explosion: 0.05 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## frostgruft

- u.feel: 4.37 ms
- u.zones+world: 1.25 ms
- tg.pools_sync: 1.03 ms
- tg.gas_sync: 0.98 ms
- u.talents: 0.88 ms
- u.mobs: 0.84 ms
- u.rigs: 0.72 ms
- u.embers+elements: 0.68 ms
- u.hero+items: 0.58 ms
- te.blink: 0.55 ms
- glow.frame: 0.40 ms
- d.chunks: 0.39 ms
- te.impacts: 0.38 ms
- u.player: 0.22 ms
- u.blockers+torches: 0.21 ms
- d.actors: 0.15 ms
- te.explosion: 0.13 ms
- u.wreck+camera: 0.13 ms
- u.kits+moves: 0.12 ms
- da.under: 0.12 ms
- d.snow_ao: 0.11 ms
- tg.observe: 0.11 ms
- d.glow: 0.06 ms
- te.cast: 0.05 ms
- d.snow_lip: 0.05 ms
- te.crit: 0.03 ms
- d.snow_front: 0.02 ms
- tg.traps: 0.02 ms
- tg.zones: 0.01 ms
- te.pet_strike: 0.01 ms
- u.shots: 0.01 ms
- sg.gas_sync: 0.00 ms

