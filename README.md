# alchemons

## Wilderness Runtime Flow

This describes what happens from **clicking Wilderness**, selecting a **party**, and entering a scene, all the way to **random encounters** appearing.

### TL;DR
- Pick your party (up to 3) → tap **Wilderness**.
- `ScenePage` builds `SceneGame` + `EncounterService`.
- `SceneGame` runs a timer; when it fires, it calls `EncounterService.roll()`.
- A weighted encounter is picked (rarity, luck, pity) and `SceneGame.spawnEncounter(...)` is called.
- UI gets notified via `onEncounter` (e.g., Snackbar/overlay).

---

### Key Files

- `lib/screens/party_picker_page.dart`  
  Build/edit the party (SelectedPartyNotifier) → returns `List<PartyMember>`.

- `lib/screens/scene_page.dart`  
  Hosts the Flame `SceneGame`. Creates and wires the `EncounterService` using the player’s party and the scene’s encounter pools.

- `lib/games/scene_game.dart`  
  Parallax scene, camera/zoom, trophy slots, and **encounter loop** (timer + spawn hook).

- `lib/services/encounter_service.dart`  
  Rolls encounters using weighted selection, party **luck** bias, and **pity** for Rare+.

- `lib/models/encounters/encounter_pool.dart`  
  Data model: `EncounterPool`, `EncounterEntry`, `EncounterRarity` (+ helpers).

- `lib/models/encounters/valley_pools.dart`  
  Scene-specific content: scene-wide pool + optional per-slot overrides (day/night gating, weight tweaks).

- `lib/utils/weighted_picker.dart`  
  Generic roulette-wheel picker.

---

## Runtime Flow (End-to-End)

**Enter scene → `ScenePage` builds:**
- `SceneGame(scene: widget.scene)`
- `EncounterService(scene, party, tableBuilder: valleyEncounterPools)`

**Wire up → `ScenePage` calls:**
- `_game.attachEncounters(_encounters)`
- `_game.onEncounter = (roll) { /* UI feedback */ }`

**Load & layout → `SceneGame.onLoad()`:**
- Loads background layers & trophy sprites.
- Builds parallax layers and trophy components.
- Sets camera / zoom defaults and schedules the first encounter roll.

**Game loop → `SceneGame.update(dt)`:**
- Runs camera/zoom smoothing.
- Ticks an internal timer; when time’s up:
  - Calls `encounters.roll()` (optionally `roll(slotId)` to bias near a slot).
  - Emits `onEncounter(roll)` to the UI.
  - Calls `spawnEncounter(roll.speciesId, rarity: roll.rarity)`.

**Rolling logic → `EncounterService.roll()`:**
- Gets the right `EncounterPool` (per-slot override or scene-wide) from `valleyEncounterPools`.
- Builds weights from `rarity.baseWeight * weightMul`, applies **partyLuck** bias and **pity** for Rare+.
- Uses `WeightedPicker` to pick an `EncounterEntry` → returns `EncounterRoll`.

**UI reaction:**
- `ScenePage` currently shows a SnackBar: *“A wild X appeared!”*  

```mermaid
sequenceDiagram
  participant U as Player
  participant P as PartyPickerPage
  participant S as ScenePage
  participant G as SceneGame
  participant E as EncounterService
  participant C as Content (valley_pools)

  U->>P: Select party & confirm
  P-->>S: Navigate with scene + party
  S->>G: create SceneGame(scene)
  S->>E: create EncounterService(scene, party, valleyEncounterPools)
  S->>G: attachEncounters(E)
  G->>G: onLoad() → build layers, slots, camera, schedule roll
  loop every 5–9s
    G->>E: roll()
    E->>C: load EncounterPool (scene-wide/per-slot)
    E->>E: compute weights (rarity × mul × luck × pity)
    E->>E: pick entry (WeightedPicker)
    E-->>G: EncounterRoll(speciesId, rarity)
    G->>G: spawnEncounter(speciesId, rarity)
    G-->>S: onEncounter(roll)
    S-->>U: show feedback (snackbar/overlay)
  end