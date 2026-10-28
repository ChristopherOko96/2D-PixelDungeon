"""Writes assets/data/frost_talents.json (talent trees, currency, prices)."""
import json, sys

def N(id, name, desc, ranks, **fx):
    return {"id": id, "name": name, "desc": desc, "max": ranks, **fx}

STD = {
 "fire": {"name": "Feuermagier", "ready": True, "price": 0, "weapon": "Smaragdstab", "role": "Flächenschaden und Brand.",
  "tiers": [
   [N("f_core", "GLUTKERN", "+5 % Schaden je Punkt.", 4, stat="damage", value=0.05), N("f_spark", "FUNKENFLUG", "4 % schnellere Zauber je Punkt.", 4, stat="rate", value=0.04)],
   [N("f_twin", "ZWILLINGSFEUER", "Feuerball teilt sich (je Punkt ein Ball mehr).", 2, card="twin_fire"), N("f_wild", "GROSSBRAND", "Feuerball +25 % Explosion je Punkt.", 2, card="wildfire")],
   [N("f_chain", "KETTENFEUER", "Kettenblitz +2 Sprünge je Punkt.", 2, card="more_jumps"), N("f_rift", "ARKANRISS", "Blinzeln explodiert am Startpunkt.", 1, card="arcane_rift")],
   [N("f_breath", "LANGER ATEM", "Photoneneis +1 s je Punkt.", 2, card="long_breath"), N("f_heart", "GLUTHERZ", "+1 Herz je Punkt.", 2, stat="hearts", value=2)],
   [N("f_meteor", "METEORSCHAUER", "Taste 5: 6 Meteore fallen 3 s lang auf das Zielgebiet.", 1, master="meteor_rain"),
    N("f_phoenix", "PHÖNIX", "Taste 5: Ein Flammenring kreist 8 s um dich. Einmal je Etage stehst du nach dem Tod mit halben Herzen wieder auf.", 1, master="phoenix")]]},
 "twohand": {"name": "Schwertkämpfer", "ready": True, "price": 0, "weapon": "Schwert", "role": "Weite Hiebe mitten im Getümmel.",
  "tiers": [
   [N("t_heavy", "SCHWERE KLINGE", "+5 % Schaden je Punkt.", 4, stat="damage", value=0.05), N("t_swift", "FLINKE KLINGE", "4 % schnellere Hiebe je Punkt.", 4, stat="rate", value=0.04)],
   [N("t_double", "DOPPELWIRBEL", "Wirbelklinge dreht sich zweimal.", 1, card="double_whirl"), N("t_wide", "WEITER SCHWUNG", "Wirbelklinge +20 % Radius je Punkt.", 2, card="wide_swing")],
   [N("t_fan", "WELLENFÄCHER", "Klingenwelle als Fächer aus 3 Wellen.", 1, card="wave_fan"), N("t_shock", "SCHOCKWELLE", "Ansturm endet mit einem Stoß.", 1, card="shockwave")],
   [N("t_sharp", "SCHARFE KLINGEN", "Rage +10 % Krit je Punkt.", 2, card="sharp_blades"), N("t_iron", "EISERNE HAUT", "+1 Herz je Punkt.", 2, stat="hearts", value=2)],
   [N("t_storm", "KLINGENSTURM", "Taste 5: 4 s lang drehst du dich als Klingensturm, jede Drehung trifft alles um dich.", 1, master="blade_storm"),
    N("t_exec", "HINRICHTUNG", "Taste 5: Ein Hieb fällt Gegner unter 30 % sofort, Bosse nehmen 3x Schaden.", 1, master="execute")]]},
 "sniper": {"name": "Langbogenschütze", "ready": True, "price": 0, "weapon": "Langbogen", "role": "Starke Schüsse aus der Distanz.",
  "tiers": [
   [N("s_steady", "RUHIGE HAND", "+5 % Schaden je Punkt.", 4, stat="damage", value=0.05), N("s_fleet", "LEICHTFUSS", "+3 % Lauftempo je Punkt.", 4, stat="speed", value=0.03)],
   [N("s_wide", "BREITE SALVE", "Salve +2 Pfeile je Punkt.", 2, card="wide_volley"), N("s_quick", "SCHNELLSPANNER", "Ballistapfeil lädt 40 % schneller.", 1, card="quick_draw")],
   [N("s_poison", "GIFTSPITZEN", "Die Salve vergiftet.", 1, card="poison_tips"), N("s_heavy", "WUCHTSPITZE", "Ballistapfeil +25 % Schaden je Punkt.", 2, card="heavy_tip")],
   [N("s_thorns", "EISDORNEN", "Krähenfüße verlangsamen stärker.", 1, card="ice_thorns"), N("s_breaker", "MAUERBRECHER", "Pfeilfaust +40 % Explosion je Punkt.", 2, card="wall_breaker")],
   [N("s_death", "TODESSCHUSS", "Taste 5: 1,2 s zielen, dann ein riesiger Kraftschuss durch alles hindurch (12x Schaden).", 1, master="death_shot"),
    N("s_rain", "PFEILREGEN", "Taste 5: 4 s lang regnen Pfeile auf ein großes Gebiet.", 1, master="arrow_rain")]]},
}
OTHER = {
 "mage": [("frost", "Frostmagier", "Blizzard, Eiswand, Frostnova, Eiselementar beschwören.", "FROSTRIESE oder EWIGER WINTER"),
          ("necro", "Nekromant", "Skelette erwecken, Knochenschild, Leichenexplosion, Seelenernte.", "KNOCHENKOLOSS oder DÄMONENFÜRST")],
 "swordsman": [("tank", "Tankkrieger", "Schwert und Schild: Spott, Schildwall, Bollwerk-Sprung, Unerschütterlich.", "FESTUNG oder VERGELTUNG"),
               ("axe", "Axtkrieger", "Wurfaxt, Blutrausch, Erdstampfer, Raserei.", "BESTIENFORM (Oger) oder BLUTGOTT")],
 "archer": [("shadow", "Schattenläufer", "Tarnung, Messerfächer, Schattenschritt, Giftklinge.", "TODESTANZ oder SCHATTENKLON"),
            ("beast", "Tierbändiger", "Wolf rufen, Falkenstoß, Fallen, Rudelruf.", "URBÄR oder WALDHÜTER")],
}
def S(id, key, unlock, name, short, cd, do, **kw):
    return {"id": id, "key": key, "unlock": unlock, "name": name, "short": short, "cooldown": cd, "do": do, **kw}


def M(id, name, desc, do, **kw):
    return {"id": id, "name": name, "desc": desc, "max": 1, "master": id, "do": do, **kw}


def MOD(id, name, desc, ranks, target, add=None, mul=None):
    n = {"id": id, "name": name, "desc": desc, "max": ranks, "mod": target}
    if add is not None: n["add"] = add
    if mul is not None: n["mul"] = mul
    return n


# The six further subclasses: own attack, four skills on 1-4 (unlock by level), a tree of five tiers.
SUBS = {
 "frost": {"name": "Frostmagier", "sprite": "wizzard_f", "tint": [0.7, 0.9, 1.4], "role": "Kontrolle: verlangsamen, einfrieren, Wege versperren.",
  "attack": {"do": "shot", "name": "EISSPLITTER", "kind": "ice", "damage": 1.4, "cooldown": 0.32, "speed": 820, "life": 0.9, "slow": 0.3, "slow_time": 1.2},
  "skills": [S("fr_wall", "1", 1, "EISWAND", "WAND", 9, "wall", length=320, time=6.0),
             S("fr_blizzard", "2", 3, "BLIZZARD", "BLIZZARD", 11, "zone", radius=220, time=5.0, every=0.3, damage=0.45, slow=0.5, freeze_after=0),
             S("fr_nova", "3", 6, "FROSTNOVA", "NOVA", 8, "nova", radius=230, damage=1.6, freeze=1.2, shards=0),
             S("fr_elemental", "4", 10, "EISELEMENTAR", "ELEMENTAR", 22, "summon", sprite="ally_ice_elemental", frames=1, count=1, cap=2, time=15, damage=1.2, every=0.8, reach=420, speed=150, scale=1.3, ranged=True)],
  "tiers": [[MOD("fr_cold", "KÄLTE", "Eissplitter verlangsamen 6 % stärker je Punkt.", 4, "attack.slow", add=0.06), N("fr_focus", "EISFOKUS", "+5 % Schaden je Punkt.", 4, stat="damage", value=0.05)],
            [MOD("fr_thick", "DICKE WAND", "Eiswand hält 40 % länger je Punkt.", 2, "fr_wall.time", mul=0.4), MOD("fr_storm", "SCHNEEGESTÖBER", "Blizzard +20 % Fläche je Punkt.", 2, "fr_blizzard.radius", mul=0.2)],
            [MOD("fr_deep", "TIEFKÜHLUNG", "Wer 2,5 s im Blizzard steht, friert 1 s ein.", 1, "fr_blizzard.freeze_after", add=2.5), MOD("fr_bond", "ELEMENTARBUND", "Eiselementar hält 5 s länger je Punkt.", 2, "fr_elemental.time", add=5)],
            [MOD("fr_shards", "SPLITTERNOVA", "Frostnova schleudert 8 Eissplitter.", 1, "fr_nova.shards", add=8), MOD("fr_twins", "ZWEI ELEMENTARE", "Du rufst zwei Eiselementare.", 1, "fr_elemental.count", add=1)],
            [M("fr_giant", "FROSTRIESE", "Taste 5: Ein Frostriese kämpft 15 s für dich und stampft Eisringe.", "summon", sprite="ally_frost_giant", frames=4, count=1, time=15, damage=3.0, every=1.1, reach=140, speed=170, scale=1.0, radius=150, freeze=0.6),
             M("fr_winter", "EWIGER WINTER", "Taste 5: 6 s lang friert jeder Gegner im Raum nach 2 s Kälte ein.", "zone", radius=1400, time=6.0, every=0.4, damage=0.3, slow=0.6, freeze_after=2.0, on_hero=True)]]},
 "necro": {"name": "Nekromant", "sprite": "wizzard_m", "tint": [0.75, 0.6, 1.1], "role": "Beschwörer: Untote kämpfen für dich, du hältst Abstand.",
  "attack": {"do": "shot", "name": "SEELENBLITZ", "kind": "soul", "damage": 1.5, "cooldown": 0.34, "speed": 700, "life": 1.0, "heal_every": 10},
  "skills": [S("ne_raise", "1", 1, "SKELETTE ERWECKEN", "SKELETTE", 10, "summon", sprite="ally_skeleton", frames=4, count=2, cap=4, time=20, damage=0.9, every=0.7, reach=80, speed=210, scale=1.3),
             S("ne_shield", "2", 3, "KNOCHENSCHILD", "SCHILD", 14, "buff", buff="absorb", hits=2, time=10.0),
             S("ne_corpse", "3", 6, "LEICHENEXPLOSION", "LEICHE", 7, "corpse", radius=160, damage=3.0, chain=0),
             S("ne_harvest", "4", 10, "SEELENERNTE", "ERNTE", 18, "harvest", radius=320, damage=2.0, heal_per=4)],
  "tiers": [[MOD("ne_marrow", "KNOCHENMARK", "Skelette +15 % Schaden je Punkt.", 4, "ne_raise.damage", mul=0.15), N("ne_thirst", "SEELENDURST", "+5 % Schaden je Punkt.", 4, stat="damage", value=0.05)],
            [MOD("ne_horde", "GRÖSSERE HORDE", "+1 Skelett je Ruf und +1 Höchstzahl je Punkt.", 2, "ne_raise.count", add=1), MOD("ne_hard", "HARTE KNOCHEN", "Knochenschild fängt +1 Treffer je Punkt.", 2, "ne_shield.hits", add=1)],
            [MOD("ne_chain", "KETTENEXPLOSION", "Leichenexplosion springt auf zwei weitere Leichen.", 1, "ne_corpse.chain", add=2), MOD("ne_long", "TREUE KNOCHEN", "Skelette bleiben 6 s länger je Punkt.", 2, "ne_raise.time", add=6)],
            [MOD("ne_burst", "UNTOTER WILLE", "Leichenexplosion +40 % Schaden.", 1, "ne_corpse.damage", mul=0.4), MOD("ne_reap", "SEELENBAND", "Seelenernte heilt schon ab 3 Seelen.", 1, "ne_harvest.heal_per", add=-1)],
            [M("ne_colossus", "KNOCHENKOLOSS", "Taste 5: Ein riesiger Zombie kämpft 20 s, zieht Gegner auf sich und schlägt Flächen.", "summon", sprite="ally_big_zombie", frames=4, count=1, time=20, damage=3.0, every=1.0, reach=120, speed=160, scale=1.8, radius=140, taunt=True),
             M("ne_demon", "DÄMONENFÜRST", "Taste 5: Ein großer Dämon speit 12 s lang Feuer.", "summon", sprite="ally_big_demon", frames=4, count=1, time=12, damage=2.2, every=0.5, reach=380, speed=170, scale=1.8, ranged=True)]]},
 "tank": {"name": "Tankkrieger", "sprite": "knight_f", "tint": None, "role": "Schild und Schwert: Treffer abfangen, Gegner binden.",
  "attack": {"do": "melee", "name": "SCHILDSTOSS", "damage": 1.8, "cooldown": 0.42, "reach": 140, "arc": 1.7, "push": 900, "stun": 0.3},
  "skills": [S("ta_taunt", "1", 1, "SPOTT", "SPOTT", 10, "taunt", radius=320, pull=120, vuln=0.25, time=5.0),
             S("ta_wall", "2", 3, "SCHILDWALL", "WALL", 9, "buff", buff="block_front", time=4.0, reflect=0),
             S("ta_leap", "3", 6, "BOLLWERK-SPRUNG", "SPRUNG", 8, "leap", distance=380, radius=180, damage=1.6, stun=0.6),
             S("ta_iron", "4", 10, "UNERSCHÜTTERLICH", "EISERN", 18, "buff", buff="reduce", value=0.5, time=6.0)],
  "tiers": [[N("ta_skin", "EISENHAUT", "+1 halbes Herz je Punkt.", 4, stat="hearts", value=1), MOD("ta_bash", "SCHWERER SCHILD", "Schildstoß +15 % Schaden je Punkt.", 4, "attack.damage", mul=0.15)],
            [MOD("ta_wide", "LAUTER RUF", "Spott +20 % Reichweite je Punkt.", 2, "ta_taunt.radius", mul=0.2), MOD("ta_long", "STANDHAFT", "Schildwall +1 s je Punkt.", 2, "ta_wall.time", add=1)],
            [MOD("ta_reflect", "RÜCKSTOSS", "Der Schildwall wirft Geschosse zurück.", 1, "ta_wall.reflect", add=1), MOD("ta_quake", "ERDBEBEN", "Bollwerk-Sprung betäubt 0,4 s länger.", 1, "ta_leap.stun", add=0.4)],
            [MOD("ta_bastion", "LETZTE BASTION", "Unerschütterlich hält 2 s länger je Punkt.", 2, "ta_iron.time", add=2), N("ta_bulk", "SCHWERES EISEN", "+5 % Schaden je Punkt.", 2, stat="damage", value=0.05)],
            [M("ta_fortress", "FESTUNG", "Taste 5: 5 s unverwundbar; Gegner prallen von dir ab.", "buff", buff="fortress", time=5.0),
             M("ta_vengeance", "VERGELTUNG", "Taste 5: 4 s lang werden Treffer gespeichert und dann verdreifacht als Druckwelle zurückgegeben.", "buff", buff="vengeance", time=4.0, radius=260, damage=3.0)]]},
 "axe": {"name": "Axtkrieger", "sprite": "dwarf_m", "tint": None, "weapon": "weapon_axe", "role": "Berserker: Blutung, Raserei und am Ende die Verwandlung.",
  "attack": {"do": "melee", "name": "AXTHIEB", "damage": 3.0, "cooldown": 0.5, "reach": 165, "arc": 1.9, "push": 500, "bleed": 0.6, "bleed_time": 2.0},
  "skills": [S("ax_throw", "1", 1, "WURFAXT", "WURFAXT", 5, "shot", kind="axe", damage=2.2, speed=900, life=0.8, pierce=True, back=0, count=1, spread=0.25),
             S("ax_rush", "2", 3, "BLUTRAUSCH", "RAUSCH", 14, "buff", buff="bloodrush", time=6.0, rate=0.25, heal_chance=0.35),
             S("ax_stomp", "3", 6, "ERDSTAMPFER", "STAMPF", 8, "nova", radius=200, damage=2.2, stun=0.5),
             S("ax_frenzy", "4", 10, "RASEREI", "RASEREI", 20, "buff", buff="frenzy", time=6.0, rate=0.4, damage=0.3)],
  "tiers": [[MOD("ax_deep", "TIEFE WUNDEN", "Blutung +20 % je Punkt.", 4, "attack.bleed", mul=0.2), N("ax_hide", "DICKE HAUT", "+1 halbes Herz je Punkt.", 4, stat="hearts", value=1)],
            [MOD("ax_boomerang", "BUMERANG-AXT", "Die Wurfaxt kehrt zurück und trifft erneut.", 1, "ax_throw.back", add=1), MOD("ax_harvest", "BLUTIGE ERNTE", "Blutrausch heilt öfter.", 2, "ax_rush.heal_chance", add=0.15)],
            [MOD("ax_quake", "BEBENDE ERDE", "Erdstampfer +20 % Fläche je Punkt.", 2, "ax_stomp.radius", mul=0.2), N("ax_wrath", "ZORN", "+5 % Schaden je Punkt.", 2, stat="damage", value=0.05)],
            [MOD("ax_endless", "ENDLOSER RAUSCH", "Raserei hält 2 s länger.", 1, "ax_frenzy.time", add=2), MOD("ax_twin", "ZWEI ÄXTE", "Wurfaxt wirft zwei Äxte.", 1, "ax_throw.count", add=1)],
            [M("ax_beast", "BESTIENFORM", "Taste 5: 10 s in Ogergestalt: doppelte Größe, +50 % Schaden, weitere Hiebe.", "buff", buff="transform", time=10.0, sprite="ogre", damage=0.5, reach=0.4),
             M("ax_bloodgod", "BLUTGOTT", "Taste 5: 6 s lang heilt jeder Treffer manchmal, und Blutung springt auf Nachbarn über.", "buff", buff="bloodgod", time=6.0, heal_chance=0.15, spread=160)]]},
 "shadow": {"name": "Schattenläufer", "sprite": "elf_m", "tint": [0.7, 0.7, 0.95], "weapon": "weapon_knife", "role": "Tarnung und Messer: unsichtbar heranschleichen, von hinten zustechen.",
  "attack": {"do": "melee", "name": "DOLCHSTICH", "damage": 1.5, "cooldown": 0.18, "reach": 120, "arc": 1.3, "push": 200, "backstab": 2.0},
  "skills": [S("sh_cloak", "1", 1, "TARNUNG", "TARNUNG", 12, "stealth", time=3.0, ambush=3.0),
             S("sh_fan", "2", 3, "MESSERFÄCHER", "FÄCHER", 6, "shot", kind="knife", damage=1.1, speed=950, life=0.6, count=5, spread=0.8),
             S("sh_step", "3", 6, "SCHATTENSCHRITT", "SCHRITT", 7, "step", range=600, hits=2, every=0.14, damage=1.6),
             S("sh_poison", "4", 10, "GIFTKLINGE", "GIFT", 16, "buff", buff="poison", time=6.0, dps=0.9, poison_time=3.0)],
  "tiers": [[MOD("sh_sharp", "SCHARFE DOLCHE", "Dolchstich +15 % Schaden je Punkt.", 4, "attack.damage", mul=0.15), N("sh_soft", "LEISE SOHLEN", "+3 % Lauftempo je Punkt.", 4, stat="speed", value=0.03)],
            [MOD("sh_long", "LANGE TARNUNG", "Tarnung hält 1 s länger je Punkt.", 2, "sh_cloak.time", add=1), MOD("sh_more", "MEHR MESSER", "+2 Messer im Fächer je Punkt.", 2, "sh_fan.count", add=2)],
            [MOD("sh_ambush", "HINTERHALT", "Erster Stich aus der Tarnung +1x Schaden.", 1, "sh_cloak.ambush", add=1), MOD("sh_venom", "STARKES GIFT", "Gift +30 % je Punkt.", 2, "sh_poison.dps", mul=0.3)],
            [MOD("sh_echo", "SCHATTENECHO", "Schattenschritt trifft +1 Gegner.", 1, "sh_step.hits", add=1), N("sh_keen", "TÖDLICHE PRÄZISION", "+5 % Schaden je Punkt.", 2, stat="damage", value=0.05)],
            [M("sh_dance", "TODESTANZ", "Taste 5: Du springst 3 s lang unsichtbar von Gegner zu Gegner und stichst jeden.", "step", range=700, hits=8, every=0.25, damage=2.0, stealth=3.0),
             M("sh_clones", "SCHATTENKLON", "Taste 5: Zwei Schattenklone kämpfen 10 s mit deinen Dolchen.", "summon", sprite="hero", frames=4, count=2, time=10, damage=1.4, every=0.35, reach=80, speed=330, scale=1.0, tint=[0.25, 0.2, 0.45])]]},
 "beast": {"name": "Tierbändiger", "sprite": "lizard_f", "tint": None, "role": "Begleiter: Wolf, Falke und Bär kämpfen mit dir.",
  "attack": {"do": "shot", "name": "PFEIL", "kind": "arrow", "damage": 1.0, "cooldown": 0.26, "speed": 1000, "life": 0.8},
  "skills": [S("be_wolf", "1", 1, "WOLF RUFEN", "WOLF", 10, "summon", sprite="ally_wolf", frames=4, count=1, cap=3, time=20, damage=1.1, every=0.5, reach=70, speed=330, scale=1.5),
             S("be_hawk", "2", 3, "FALKENSTOSS", "FALKE", 6, "shot", kind="hawk", damage=2.4, speed=760, life=1.4, pierce=True, home=True, count=1, spread=0.3),
             S("be_trap", "3", 6, "FALLE STELLEN", "FALLE", 9, "trap", radius=90, damage=2.5, root=1.5, time=20.0),
             S("be_pack", "4", 10, "RUDELRUF", "RUDEL", 16, "rally", time=6.0, damage=0.5, speed=0.4)],
  "tiers": [[MOD("be_bite", "STARKE BISSE", "Wölfe +15 % Schaden je Punkt.", 4, "be_wolf.damage", mul=0.15), N("be_eye", "SCHARFES AUGE", "+5 % Schaden je Punkt.", 4, stat="damage", value=0.05)],
            [MOD("be_two", "ZWEITER WOLF", "Wolf rufen bringt einen Wolf mehr.", 1, "be_wolf.count", add=1), MOD("be_claws", "SCHARFE KRALLEN", "Falkenstoß +20 % Schaden je Punkt.", 2, "be_hawk.damage", mul=0.2)],
            [MOD("be_iron", "FANGEISEN", "Fallen halten 1 s länger.", 1, "be_trap.root", add=1), MOD("be_loyal", "TREUE", "Wölfe bleiben 6 s länger je Punkt.", 2, "be_wolf.time", add=6)],
            [MOD("be_howl", "WILDES HEULEN", "Rudelruf hält 2 s länger.", 1, "be_pack.time", add=2), MOD("be_flock", "SCHWARM", "Falkenstoß schickt zwei Falken.", 1, "be_hawk.count", add=1)],
            [M("be_bear", "URBÄR", "Taste 5: Ein großer Bär kämpft 20 s, schlägt Flächen und zieht Gegner auf sich.", "summon", sprite="ally_bear", frames=4, count=1, time=20, damage=2.8, every=0.9, reach=110, speed=240, scale=2.6, radius=130, taunt=True),
             M("be_ent", "WALDHÜTER", "Taste 5: Ein lebender Baum wurzelt 15 s, fesselt Gegner in der Nähe und heilt dich.", "summon", sprite="ally_ent", frames=4, count=1, time=15, damage=1.0, every=1.0, reach=260, speed=0, scale=2.4, radius=260, root=1.0, heal=1)]]},
}
STDOF = {"mage": "fire", "swordsman": "twohand", "archer": "sniper"}
classes = {}
for cls, std in STDOF.items():
    subs = {std: STD[std]}
    for sid, name, kit, master in OTHER[cls]:
        sub = dict(SUBS[sid])
        sub.update({"ready": True, "price": 40})
        subs[sid] = sub
    classes[cls] = {"standard": std, "order": [std] + [o[0] for o in OTHER[cls]], "subs": subs}

data = {
 "_note": "Talents of the Frostgruft (src/hell/meta_store.gd, main menu TALENTE). currency: name and how many crystals a floor gives at the stairs: floor_base + floor * per_floor (rounded down), plus guardian / mini / final for its guardian and side_goal per finished side goal; banked at once, kept after death. need: ranks spent in the tree before tier 1-5 opens; cost: crystals per rank in tier 1-5. Per class one active subclass (standard is free, the others cost price once); switching gives the old tree's crystals back. Nodes: max ranks; stat (damage / rate / speed shares, hearts in half hearts) or card (adds levels of a level-up card, theme.cards) , mod (\"skill_id.param\" or \"attack.param\": add per rank and / or mul = share per rank) or master (the key 5 skill, one of the two in tier 5; with do it is a building block of src/hell/sub_kit.gd). The further subclasses carry their kit: sprite (0x72 hero), tint, weapon, attack (do shot / melee) and skills on keys 1-4 (do: shot, wall, zone, nova, summon, buff, corpse, harvest, taunt, leap, stealth, step, trap, rally) with their values (seconds, world pixels; the attack damage is the weapon damage itself, skill damage a multiple of it).",
 "schema_version": 1,
 "currency": {"name": "Seelenkristalle", "short": "SK", "floor_base": 1, "per_floor": 0.5, "guardian": 1, "mini": 3, "final": 6, "side_goal": 1},
 "need": [0, 3, 6, 9, 13],
 "cost": [2, 3, 4, 6, 15],
 "master_cooldown": 45,
 "classes": classes,
}
json.dump(data, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for k, s in list(STD.items()) + list(SUBS.items()):
    ranks = sum(n["max"] for t in s["tiers"][:4] for n in t)
    cost = sum(n["max"] * data["cost"][i] for i, t in enumerate(s["tiers"][:4]) for n in t) + data["cost"][4]
    print(k, "Ränge vor Meister", ranks, "voller Baum", cost)
run = sum(1 + int(f * 0.5) for f in range(1, 11)) + 6 * 1 + 3 * 3 + 6
print("ganzer Lauf ohne Nebenziele", run)
