# Story-Welten: Rechenzeit (neu1)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 351 | 22.79 | 32.93 | 51.85 | 43.78 | 1.02 | 0.99 | 522 |
| hoelle | 298 | 26.81 | 38.19 | 65.22 | 50.22 | 1.18 | 1.28 | 596 |
| frostgruft | 250 | 32.04 | 43.90 | 136.44 | 83.34 | 1.42 | 1.16 | 743 |

## krypta

- u.feel: 3.22 ms
- tg.gas_sync: 0.83 ms
- u.talents: 0.66 ms
- te.blink: 0.65 ms
- u.hero+items: 0.62 ms
- glow.frame: 0.61 ms
- u.embers+elements: 0.47 ms
- tg.pools_sync: 0.44 ms
- u.rigs: 0.35 ms
- u.blockers+torches: 0.24 ms
- u.zones+world: 0.24 ms
- u.player: 0.23 ms
- te.impacts: 0.20 ms
- u.wreck+camera: 0.15 ms
- da.under: 0.14 ms
- tg.traps: 0.12 ms
- d.actors: 0.12 ms
- u.mobs: 0.12 ms
- d.glow: 0.07 ms
- tg.observe: 0.07 ms
- u.kits+moves: 0.07 ms
- te.cast: 0.05 ms
- te.explosion: 0.03 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 3.88 ms
- tg.gas_sync: 0.98 ms
- u.talents: 0.69 ms
- glow.frame: 0.67 ms
- u.hero+items: 0.62 ms
- te.blink: 0.59 ms
- u.rigs: 0.57 ms
- u.embers+elements: 0.51 ms
- tg.pools_sync: 0.51 ms
- u.zones+world: 0.36 ms
- te.impacts: 0.31 ms
- u.blockers+torches: 0.24 ms
- d.actors: 0.24 ms
- u.player: 0.23 ms
- u.mobs: 0.18 ms
- u.wreck+camera: 0.14 ms
- tg.traps: 0.13 ms
- da.under: 0.13 ms
- tg.observe: 0.09 ms
- d.glow: 0.08 ms
- u.kits+moves: 0.07 ms
- te.explosion: 0.07 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.01 ms

## frostgruft

- u.feel: 4.62 ms
- u.talents: 1.12 ms
- tg.gas_sync: 1.12 ms
- u.zones+world: 1.04 ms
- u.embers+elements: 0.77 ms
- te.blink: 0.66 ms
- u.rigs: 0.64 ms
- u.hero+items: 0.62 ms
- u.mobs: 0.61 ms
- tg.pools_sync: 0.59 ms
- glow.frame: 0.46 ms
- te.impacts: 0.45 ms
- d.chunks: 0.30 ms
- u.blockers+torches: 0.25 ms
- u.player: 0.24 ms
- te.explosion: 0.15 ms
- d.actors: 0.14 ms
- u.wreck+camera: 0.14 ms
- da.under: 0.14 ms
- u.kits+moves: 0.13 ms
- tg.observe: 0.12 ms
- d.snow_ao: 0.09 ms
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

