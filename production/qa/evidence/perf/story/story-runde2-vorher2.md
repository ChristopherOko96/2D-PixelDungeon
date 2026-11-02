# Story-Welten: Rechenzeit (runde2-vorher2)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 404 | 19.76 | 30.57 | 95.99 | 51.96 | 0.85 | 0.42 | 487 |
| hoelle | 315 | 25.37 | 38.89 | 98.93 | 70.72 | 1.05 | 0.46 | 601 |
| frostgruft | 270 | 29.66 | 39.01 | 161.04 | 99.55 | 1.27 | 0.53 | 737 |

## krypta

- u.feel: 3.01 ms
- tg.gas_sync: 0.65 ms
- tg.pools_sync: 0.62 ms
- u.talents: 0.59 ms
- u.hero+items: 0.55 ms
- te.blink: 0.54 ms
- glow.frame: 0.52 ms
- u.embers+elements: 0.37 ms
- u.rigs: 0.35 ms
- da.under: 0.22 ms
- u.blockers+torches: 0.21 ms
- u.zones+world: 0.20 ms
- u.player: 0.20 ms
- te.impacts: 0.16 ms
- u.wreck+camera: 0.13 ms
- u.mobs: 0.12 ms
- tg.traps: 0.10 ms
- d.actors: 0.09 ms
- u.kits+moves: 0.06 ms
- d.glow: 0.06 ms
- tg.observe: 0.06 ms
- te.cast: 0.04 ms
- te.explosion: 0.03 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 3.77 ms
- tg.pools_sync: 1.05 ms
- tg.gas_sync: 0.79 ms
- u.rigs: 0.70 ms
- u.talents: 0.64 ms
- glow.frame: 0.59 ms
- u.hero+items: 0.57 ms
- te.blink: 0.53 ms
- u.embers+elements: 0.42 ms
- u.zones+world: 0.31 ms
- te.impacts: 0.27 ms
- u.mobs: 0.23 ms
- d.actors: 0.21 ms
- u.blockers+torches: 0.21 ms
- u.player: 0.20 ms
- u.wreck+camera: 0.13 ms
- tg.traps: 0.12 ms
- da.under: 0.12 ms
- tg.observe: 0.08 ms
- d.glow: 0.07 ms
- u.kits+moves: 0.06 ms
- te.explosion: 0.05 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms
- te.pet_strike: 0.00 ms

## frostgruft

- u.feel: 4.49 ms
- u.talents: 1.07 ms
- tg.pools_sync: 1.04 ms
- tg.gas_sync: 0.94 ms
- u.zones+world: 0.91 ms
- u.rigs: 0.77 ms
- u.mobs: 0.75 ms
- u.embers+elements: 0.66 ms
- te.blink: 0.57 ms
- u.hero+items: 0.55 ms
- te.impacts: 0.41 ms
- glow.frame: 0.39 ms
- d.chunks: 0.26 ms
- u.blockers+torches: 0.22 ms
- u.player: 0.21 ms
- te.explosion: 0.14 ms
- da.under: 0.13 ms
- u.wreck+camera: 0.12 ms
- d.actors: 0.12 ms
- u.kits+moves: 0.12 ms
- tg.observe: 0.11 ms
- d.snow_ao: 0.08 ms
- te.crit: 0.05 ms
- d.glow: 0.05 ms
- te.cast: 0.05 ms
- d.snow_lip: 0.03 ms
- d.snow_front: 0.02 ms
- tg.traps: 0.02 ms
- tg.zones: 0.01 ms
- u.shots: 0.01 ms
- te.pet_strike: 0.01 ms
- sg.gas_sync: 0.01 ms

