# Sound effects — source and licence note

- Cut on 2026-10-27 by `scripts/prepare_sfx.js` from the user's folder
  `C:\Users\Cylor\Desktop\Sound Pixel Combat` (read only). The table of which
  source feeds which game event is `assets/data/audio_sfx.json`.
- Files named `*_HY_PC.wav` in that folder (impacts, spells, lasers, steps,
  UI clicks) appear to come from a commercial "Pixel Combat" sound pack; the
  sub-folders `Combat and Gore`, `Weapons`, `UI` and `Musical Effects` come from
  a second, general pack.
- **Licence: unknown.** No licence or readme file is in the folder. Many sound
  packs allow use in games but forbid redistributing the raw files, which a
  public repository does. On 2026-10-27 the user decided to push them to the
  public repository anyway. Clarify with the pack's terms (or replace the
  files) before the game is released.

## Update 2026-10-28

Since the CC0 sound library (`assets/audio/library/`, see its `CREDITS.md`),
these recordings are only one of several packs to choose from in the
Klangwerkstatt. Events now using CC0 files by default: hurt, hurt_voice,
hurt_ally, step, step_ally, hit_bone, rattle_bone, hit_flesh, break_bone,
kill_bone, collapse_bone, kill_flesh, idle_bone, idle_flesh, attack_roar,
door, crate_break, chest_open. The rest still play these recordings; replace
them in the Klangwerkstatt before a release if the licence stays unclear.
