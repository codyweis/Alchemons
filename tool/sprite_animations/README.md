# Creature sprite animations

The scripts that made the 8-frame idles and the hop, sleep and attack ("fire") sheets for
the Horns, Wings, Pips, Lets and Manes, and the attack sheets for the Masks, Kin and Mystics.
Python 3 with Pillow; `manes2_build.py`, `actions_build.py` and `install_fires.py` also need
numpy and scipy.

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
| `actions_build.py <scratch> <MSK\|KIN\|MYS> 1` | the attack alone for Masks, Kin and Mystics, from the rig tables in the file and the idle sheets as they are in the working tree (512 px, so scale 1; needs numpy; nothing else in `<scratch>`). `RIG=1` also writes each one's rig marked on its first frame; `actions/<family>_fire_contact.png` has every species' ten frames in a row |
| `darklet_hop.py` | Darklet's hop, and the head positions its ring follows (`DarkletRing._hopHeadY`) |
| `install_hops.py`, `install_sleeps.py`, `install_fires.py` | put those sheets beside each idle sheet and list their species in `lib/widgets/creature_actions.dart` (`install_fires.py` adds to the species already listed, and gives the soft-shaded Masks, Kin and Mystics a palette fitted to their own colours: numpy and scipy; `FULL=1` keeps them in full colour) |
| `mane_costumes.py` | the Manes' rows in `lib/models/costume_fits.dart` |
| `eye_review.py` | face close-ups of every creature's shut, lidded and sleeping eyes |

The Manes' albino eyes come from `test/albino_eyes_build_test.dart` (its `_tunes` has their
rows); the feet table from `test/creature_feet_gen_test.dart`.
