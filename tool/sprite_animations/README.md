# Creature sprite animations

The scripts that made the 8-frame idles and the hop, sleep and attack ("fire") sheets for
the Horns, Wings, Pips, Lets and Manes, the Manes', Horns', Wings' and Pips' wag, and the
attack sheets for the Masks, Kin and Mystics.
Python 3 with Pillow; `manes2_build.py`, `actions_build.py` and `install_fires.py` also need
numpy and scipy (`trailer/source/venv/bin/python` has them).

Every script takes a scratch folder as its first argument (`<scratch>`): it reads the other
scripts from there and writes its trial sheets and GIFs into it. Copy this folder's `*.py`
there, plus `data/pips_offs.json` as `<scratch>/pips/offs.json`, `data/lets_offs.json` as
`<scratch>/lets/offs.json` and `data/mane_hat_override.txt`. Run them from the repo root.
The Horn, Wing, Pip and Let builders read the original 4-frame sheets from git history
(the commit before the idles were installed), so point `head_img`/`git show` at that commit.

| Script | What it makes |
| --- | --- |
| `horns_build.py`, `wings_build.py`, `pips_build.py`, `lets_build.py` | 8-frame idles from each species' four drawn frames (the rig tables are in each file) |
| `manes_build.py` | the Mane rig table and stills (`mane_stills/`); `manes2_build.py` builds the Mane idles: moving manes, glow, drawn steam |
| `install_idles.py`, `install_manes.py` | put idles, sprite data, costume fits and albino eyes into the game |
| `actions_build.py <scratch> <HOR\|PIP\|WNG\|LET\|MAN> [scale]` | hop, attack and sleep trial sheets (`KEEP=1` keeps per-creature sheets and albino eye layers; `ONLY=ids`) |
| `actions_build.py <scratch> <MSK\|KIN\|MYS> 1` | the attack alone for Masks, Kin and Mystics, from the rig tables in the file and the idle sheets and sprite data as they are in the working tree (512 px, so scale 1; the Mystics drawn anew are 1200 px, so scale 0.5; needs numpy; nothing else in `<scratch>`). `RIG=1` also writes each one's rig marked on its first frame; `actions/<family>_fire_contact.png` has every species' ten frames in a row |
| `ANIMS=wag KEEP=1 actions_build.py <scratch> MAN\|HOR\|WNG\|PIP` | the Manes', Horns', Wings' and Pips' wag, a happy fidget (16 frames, about a second, eyes shut happy): the tail wags and the hips sway, the feet planted. Each tail is drawn round by hand in `WAG_RIGS` (its root, its outline, how far it bends); it is cut out and turned behind the body, and the glow it leaves is filled in. Hard-edged art (the Horns) is cut cleanly, with no glow fill. One whose tail is a nub or a stub joined along a long seam (Air, Mud, Lava, Light Manes; Earthhorn; Earthwing; Earth, Air, Steam, Mud, Dust Pips) shimmies. A Wing whose wing sweeps over its tail in some flap frames leaves those frames out of its wag (`frames`) or has an outline for each frame (`polys`). `WAG_RIG=1` (or `only`) writes each tail's outline over its first frame; `WAG_EYES=open` keeps the eyes open |
| `install_wags.py <scratch>` | put the Manes', Horns', Wings' and Pips' wag sheets and their albino eye layers beside each idle sheet, list their species in `creature_actions.dart`, and add each one's head track (the fourth list) to `costume_action_tracks.dart` |
| `mystics_build.py <scratch> overlay\|build [ids]` | 8-frame idles (1200 px, 2 rows of 4) for the Mystics drawn anew as stills (`mystic_stills/`: MYS01-09 so far), with the Manes' material and glow machinery (it needs `manes2_build.py` in `<scratch>`) and a body rig of its own: breath over planted feet or a flyer's hover, the head turned about its neck, the tail swung from its root. Each one's parts and what glows are in its `M` row: Simurgh's wings flap and lick, Leviathan's fins sway and a sheen crosses it, Terradon's stone arms and crown rock, Roc's cloud wings flap and swell, Boilrog's smoke wavers, Magmara's lava pulses and its jaw drips, Raikuma's bolt jitters, Bogdrya's craters bubble mud (drawn, not moved), Frowyrm glints. `overlay` marks the parts, head and tail. Simurgh and Roc beat their wings (`WINGS`, `WINGS_IDLE`): each wing is cut out on an outline that follows the gaps in the art and swung almost whole from its shoulder (`anchor`, a short `ramp`: only the joint itself stays put, its tip trailing by `lag`), and drawn a little flatter at the bottom of the stroke (`flat`). Where a wing is drawn touching the head with no gap, `cut_dark` ends it at the head's outline, so the wing pulls away from the head on the downstroke and the head keeps its edge. (Bending it from everything it touches made it look grown out of the head and fold in the middle.), laid behind the body; every frame is traced back point by point (`inv_warp`), so large moves hold together. Simurgh's tail (`TAILS`: all the drawing joined to the streamer once the body and wings are taken away) swings a beat behind and carries a wave from root to tip |
| `mystics_build.py <scratch> attack [ids]` | their attack (`ATK`), which replaces actions_build's gather-and-snap for these nine: a wind-up, one strike held a beat, the settle, at the game's 10 attack timings, with what glows on it flaring. Side-on ones lean back and drive the head forward (`lunge`), Simurgh and Roc beat down hard (`wings`), Terradon rises over its planted fists and pounds the ground (`slam`). At the strike each throws its element in grains, drawn puffs or (Raikuma) lightning arcs. Writes `<scratch>/actions/<id>_fire_spritesheet.png` (600 px frames) for `install_fires.py`, and `mystics/attack_<ids>_contact.png` |
| `install_mystics.py <scratch> [ids]` | put those idles, their 512 px stills and their sprite data into the game. Then build and install their attack (above, then `install_fires.py`) and regenerate the feet table (`test/creature_feet_gen_test.dart`). The dungeon guardians' sheets are listed by hand in `planet_dungeon_game.dart` (`_guardianSheets`) |
| `darklet_hop.py` | Darklet's hop, and the head positions its ring follows (`DarkletRing._hopHeadY`) |
| `install_hops.py`, `install_sleeps.py`, `install_fires.py` | put those sheets beside each idle sheet and list their species in `lib/widgets/creature_actions.dart` (`install_fires.py` adds to the species already listed, and gives the soft-shaded Masks, Kin and Mystics a palette fitted to their own colours: numpy and scipy; `FULL=1` keeps them in full colour) |
| `mane_costumes.py` | the Manes' rows in `lib/models/costume_fits.dart` |
| `eye_review.py` | face close-ups of every creature's shut, lidded and sleeping eyes |

The Manes' albino eyes come from `test/albino_eyes_build_test.dart` (its `_tunes` has their
rows); the feet table from `test/creature_feet_gen_test.dart`.
