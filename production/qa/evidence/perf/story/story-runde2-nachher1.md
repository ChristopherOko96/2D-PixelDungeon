# Story-Welten: Rechenzeit (runde2-nachher1)

Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle 0.30 s, 8 Gegner, 8 s Messzeit nach 1 s, V-Sync aus. ms je Frame.

| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |
|---|---|---|---|---|---|---|---|---|
| krypta | 319 | 25.04 | 36.94 | 51.47 | 44.77 | 1.09 | 1.68 | 496 |
| hoelle | 281 | 28.33 | 40.30 | 71.79 | 50.35 | 1.21 | 1.49 | 596 |
| frostgruft | 225 | 35.53 | 45.03 | 167.35 | 114.80 | 1.56 | 1.50 | 755 |

## krypta

- u.feel: 3.61 ms
- tg.gas_sync: 0.97 ms
- u.talents: 0.72 ms
- u.hero+items: 0.67 ms
- glow.frame: 0.66 ms
- te.blink: 0.66 ms
- u.embers+elements: 0.51 ms
- tg.pools_sync: 0.49 ms
- u.rigs: 0.37 ms
- te.impacts: 0.28 ms
- u.zones+world: 0.27 ms
- u.blockers+torches: 0.26 ms
- u.player: 0.25 ms
- u.wreck+camera: 0.14 ms
- da.under: 0.14 ms
- tg.traps: 0.13 ms
- d.actors: 0.13 ms
- u.mobs: 0.12 ms
- tg.observe: 0.09 ms
- d.glow: 0.08 ms
- u.kits+moves: 0.08 ms
- te.explosion: 0.06 ms
- te.cast: 0.06 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.01 ms

## hoelle

- u.feel: 4.13 ms
- tg.gas_sync: 1.05 ms
- u.talents: 0.71 ms
- glow.frame: 0.71 ms
- u.hero+items: 0.64 ms
- te.blink: 0.63 ms
- u.rigs: 0.59 ms
- tg.pools_sync: 0.55 ms
- u.embers+elements: 0.54 ms
- u.zones+world: 0.37 ms
- te.impacts: 0.31 ms
- u.blockers+torches: 0.25 ms
- d.actors: 0.25 ms
- u.player: 0.23 ms
- u.mobs: 0.19 ms
- u.wreck+camera: 0.15 ms
- tg.traps: 0.14 ms
- da.under: 0.13 ms
- tg.observe: 0.09 ms
- d.glow: 0.09 ms
- u.kits+moves: 0.08 ms
- te.explosion: 0.07 ms
- te.cast: 0.05 ms
- u.shots: 0.02 ms
- tg.zones: 0.01 ms
- sg.gas_sync: 0.00 ms

## frostgruft

- u.feel: 4.82 ms
- u.zones+world: 1.75 ms
- tg.gas_sync: 1.22 ms
- u.talents: 1.12 ms
- u.embers+elements: 0.88 ms
- tg.pools_sync: 0.71 ms
- te.blink: 0.71 ms
- u.mobs: 0.70 ms
- u.hero+items: 0.68 ms
- u.rigs: 0.62 ms
- d.chunks: 0.59 ms
- glow.frame: 0.48 ms
- te.impacts: 0.46 ms
- u.blockers+torches: 0.27 ms
- u.player: 0.26 ms
- d.snow_ao: 0.16 ms
- te.explosion: 0.16 ms
- u.wreck+camera: 0.15 ms
- u.kits+moves: 0.15 ms
- d.actors: 0.15 ms
- da.under: 0.15 ms
- tg.observe: 0.14 ms
- d.glow: 0.07 ms
- d.snow_lip: 0.07 ms
- te.cast: 0.06 ms
- te.crit: 0.04 ms
- d.snow_front: 0.04 ms
- tg.traps: 0.02 ms
- tg.zones: 0.01 ms
- te.pet_strike: 0.01 ms
- u.shots: 0.01 ms
- sg.gas_sync: 0.01 ms

