# Story-Welten: Rechenzeit (runde2-nachher2)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 340 | 23.51 | 31.56 | 63.61 | 46.28 | 1.07 | 1.25 | 522 |
| hoelle | 276 | 28.79 | 41.87 | 71.49 | 52.57 | 1.28 | 1.27 | 597 |
| frostgruft | 230 | 34.77 | 46.81 | 152.39 | 106.22 | 1.65 | 1.91 | 796 |

## krypta

- u.feel: 3.31 ms
- tg.gas_sync: 0.89 ms
- u.talents: 0.68 ms
- u.hero+items: 0.64 ms
- te.blink: 0.64 ms
- glow.frame: 0.62 ms
- u.embers+elements: 0.49 ms
- tg.pools_sync: 0.47 ms
- u.rigs: 0.36 ms
- u.zones+world: 0.26 ms
- u.blockers+torches: 0.26 ms
- u.player: 0.24 ms
- te.impacts: 0.20 ms
- da.under: 0.19 ms
- u.wreck+camera: 0.15 ms
- tg.traps: 0.13 ms
- d.actors: 0.12 ms
- u.mobs: 0.12 ms
- d.glow: 0.08 ms
- tg.observe: 0.08 ms
- u.kits+moves: 0.07 ms
- te.cast: 0.05 ms
- te.explosion: 0.03 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## hoelle

- u.feel: 4.17 ms
- tg.gas_sync: 1.07 ms
- u.talents: 0.75 ms
- glow.frame: 0.70 ms
- u.hero+items: 0.66 ms
- te.blink: 0.63 ms
- u.rigs: 0.61 ms
- tg.pools_sync: 0.56 ms
- u.embers+elements: 0.54 ms
- u.zones+world: 0.37 ms
- te.impacts: 0.31 ms
- u.blockers+torches: 0.26 ms
- d.actors: 0.25 ms
- u.player: 0.24 ms
- u.mobs: 0.19 ms
- u.wreck+camera: 0.15 ms
- tg.traps: 0.15 ms
- da.under: 0.13 ms
- tg.observe: 0.10 ms
- d.glow: 0.09 ms
- u.kits+moves: 0.08 ms
- te.explosion: 0.06 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## frostgruft

- u.feel: 4.56 ms
- u.zones+world: 1.58 ms
- tg.gas_sync: 1.20 ms
- u.talents: 1.06 ms
- u.embers+elements: 0.87 ms
- tg.pools_sync: 0.70 ms
- u.mobs: 0.70 ms
- te.blink: 0.67 ms
- u.hero+items: 0.66 ms
- u.rigs: 0.66 ms
- d.chunks: 0.52 ms
- te.impacts: 0.48 ms
- glow.frame: 0.48 ms
- u.player: 0.26 ms
- u.blockers+torches: 0.25 ms
- te.explosion: 0.17 ms
- d.snow_ao: 0.15 ms
- d.actors: 0.15 ms
- u.wreck+camera: 0.15 ms
- da.under: 0.14 ms
- u.kits+moves: 0.14 ms
- tg.observe: 0.14 ms
- d.glow: 0.07 ms
- d.snow_lip: 0.06 ms
- te.crit: 0.06 ms
- te.cast: 0.06 ms
- d.snow_front: 0.03 ms
- tg.traps: 0.02 ms
- tg.zones: 0.01 ms
- te.pet_strike: 0.01 ms
- u.shots: 0.01 ms
- sg.gas_sync: 0.01 ms

