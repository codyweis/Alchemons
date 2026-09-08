# Progression, story, and thematic audit

Audited September 7, 2026 against the current source. This is an audit and proposed revision plan; it does not change gameplay, saves, or authored dialogue.

**Follow-up:** The creator clarified the canon and authorized an implementation on September 8. See [confirmed canon and implementation decisions](campaign_story_canon.md). The findings below are a historical audit, not a statement that every listed defect remains in the current build.

**Assessment:** Alchemons has a coherent thematic foundation—living forms, inherited patterns, memory, concealment, and the cost of creation. Its planetary puzzles express that foundation especially well. The campaign's transitions and ending contracts are less consistent than its individual scenes. Several concrete implementation issues also interfere with the intended story.

Editorial assumption: preserve the existing dark, mysterious tone. The interpretation below is a proposed organizing principle, not a claim about the author's intended personal meaning.

## Scope and evidence

- Traced the first-launch route, starter extraction, wilderness tutorials, memory visit, ship discovery, cosmic prologue, home-base tutorial, Survival discovery, planetary gates, guardian rewards, altar requirements, and Blood Ring ending.
- Read all **137 creature descriptions**, the constellation story text, main story cards, principal tutorial/altar/ending dialogue, and contest hint lore alongside its scoring rules.
- Checked all **17 registered dungeon layouts** through the existing layout suite, and the Blood dungeon's dedicated behavior/solvability suite. **382 tests passed.** Command: `flutter test test/planet_dungeon_layout_test.dart test/planet_dungeon_blood_orrery_test.dart`.
- Reviewed representative progression/help text in factions, the encyclopedia, pure-lineage tutorials, upgrades, harvesting, hatching, and Survival outbreaks.
- This is source-level and editorial verification, not a complete fresh-save playthrough, phone presentation review, acquisition-time simulation, or exhaustive verification of every shop price, translation, and incidental UI string. A passing dungeon test does not prove the entire campaign can be completed without interruption.
- The earlier [story inventory](story_mode_content_inventory.md) is outdated. Its exporter, [export_story_inventory.dart](../tool/export_story_inventory.dart), hardcodes story sections rather than extracting their live reachability. It still describes a removed gauntlet and a retired planet-entry scene. Do not use it as the current campaign specification.

## The actual journey

| Stage | Current trigger / requirement | Narrative purpose and flow issue |
|---|---|---|
| Prelude | New profile without a faction; eight quote cards, then laboratory initialization | Establishes collection, creation, and unease. Personal questions arrive before a speaker or situation is established. |
| First specimen | Faction choice, starter vial, short tutorial extraction | Gives the player something to care for. The first-extraction story currently talks about two becoming one although the starter has no player-selected parents. |
| Wilderness | Faction-linked scene and its opposite; fusion followed by capture tutorial | Teaches two acquisition methods. The laboratory/wild vocabulary needs a consistent distinction. |
| Memory visit | Three eligible extractions after harvest tutorial completion; home event | Good bridge from routine experimentation to a personal mystery. It can occur before or after ship discovery because the triggers are independent. |
| Ship | Visit all four core scenes; ship appears in Valley and is claimed | Good exploration milestone. Needs a visible reason to revisit Valley and a line that connects discovery to the player's investigation. |
| First Crossing | First normal cosmic visit; separate from the memory tutorial | Harvester, elemental portal, prismatic Let. Strong visual echo of the beginning; its unnamed “he” is not established by the surrounding scene. |
| Cosmic foothold | Home-base tutorial followed by a tracked Survival signal | Clear practical teaching. The transition from memory/illusion to base upgrades is abrupt. |
| Planetary campaign | Permanent elemental gate offerings; required descent roster; three stars per planet | Strong loop: breed a capability, enter, learn a physical rule, overcome the guardian, earn a relic. |
| Mystic creation | Elemental relic plus one of every non-Mystic species of that element | The clearest expression of creation having a cost. This is a substantial collection requirement, not merely a boss reward. |
| Blood planet | All 16 other guardians defeated | The terminal planetary gate. Constellation completion no longer gates this stage. |
| Blood Mystic | Blood relic, Blood species commitments, and all 16 prior altar summons recorded | A second endgame requirement after guardian completion. Witness flags record ritual completion, not that all Mystics have hatched or remain owned. |
| Blood Ring | Blood Mystic in the first active companion slot plus another reserve ship-party creature | Ending cinematic and Bloodborn vial reward. Presentation and actual sacrifice behavior currently disagree. |
| Optional/continuing loops | Survival, raids, contests, breeding optimization, constellation completion, base growth, pureblood rites | These can support the campaign without being mandatory plot milestones. Give each a clear relationship to its central question. |

The current catalog has seven non-Mystic families per element, plus an extra Bloodmask species. Completing each altar once therefore requires **112 commitments for the first 16 Mystics, plus eight for Blood: 120 total**. This is derived from the live `byType(...).where(id != mystic.id)` altar roster, not an estimate of attempts or breeding time. It does not include replacement party members or intermediate breeding stock. See [altar roster and witnesses](../lib/screens/mystic_altar/boss_altar_detail_screen.dart:192).

## Priority 1: progression and story delivery defects

### 1. Bloodborn reward uses the old Potential scale

**Confirmed source defect.** [Bloodborn payload](../lib/screens/cosmic/cosmic_screen.dart:3887) writes `5.0` for all four Potentials. [CreatureStatPotentials serialization](../lib/models/egg/egg_payload.dart:154) explicitly writes scale version 2, whose ratings are 1–100. It therefore represents **5/100**, not the former maximum of 5/5. The hatch path reads those Potentials into level-one stat calculation.

This undercuts the climax's mechanical payoff. If the intended reward remains maximum Potential, migrate the authored reward to 100 in all four stats and add a payload-to-hatch regression. Decide separately how to repair already-created Bloodborn rewards; do not silently rewrite ordinary low-Potential specimens.

### 2. The Blood Ring stages a sacrifice but preserves the offered creature

**Confirmed mismatch; intended design unresolved.** The ending has a sacrifice animation and `sacrificedInstanceId` terminology, but [_grantBloodbornRewardEgg](../lib/screens/cosmic/cosmic_screen.dart:3859) reads the original and creates a new vial without removing it. The [picker](../lib/screens/cosmic/cosmic_screen.dart:3596) only asks for a favorite companion. It does not explain a permanent loss, transformation, or retained original.

Recommended contract: keep the original and explicitly call this an **imprint** that gives the surviving pattern another body. This matches current behavior and the altar's distinction between continuation and resurrection. If an actual sacrifice is intended, it needs a clear consequence preview and an atomic consume/reward operation; adding deletion alone would change player expectations dramatically.

The completion path also ignores the reward function's `false` result before saving `ritualCompleted`. Grant and completion need one recoverable operation so interrupted or failed rewards cannot leave a completed ending without its payout. See [_runBloodRingEnding](../lib/screens/cosmic/cosmic_screen.dart:4031).

### 3. Mystic offerings can be cleared before the reward is secured

**Confirmed ordering risk; failure injection not exercised.** [_handleSummon](../lib/screens/mystic_altar/boss_altar_detail_screen.dart:499) clears committed placement snapshots before resolving the output species, finding/purchasing a chamber, and placing the vial. A later failure can lose already-paid progress. The placement step itself writes the altar record and deletes the creature in separate awaited operations.

Use a transaction or resumable ritual record covering the commitments and reward. Keep the current permanent-commitment concept, but make its timing explicit: the specimen is removed when committed, not when the final SUMMON button is pressed. The current commitment dialog does warn that placement is permanent; the problem is timing and failure recovery, not a complete absence of warning.

### 4. The old beauty/reality callback is unreachable for fresh profiles

**Confirmed orphaned trigger.** [Self Deception](../lib/screens/scenes/scene_page.dart:330) waits for `cosmic_planet_pathway_intro_seen_v1`. Searching the live `lib` tree finds its reader but no writer. The old desolation popup also has no live caller setting its opt-in flag. Older saves may carry the retired flag, so they can see a different sequence from new players.

Replace this dependency with an actual current milestone: the first completed planetary descent or guardian clear. Re-author the callback around something the player just experienced. Do not simply restore the old assertion that this universe lacks trees: the new planetary world includes a Verdant Crypt and deliberate plant-based environments.

### 5. Interrupted memory tutorials have no evident resume path

**Source-level recovery gap.** [markHomePortalLaunched](../lib/services/cosmic_memory_tutorial_service.dart:84) clears pending and sets launched before navigation. Both extraction counting and existing-profile recovery return early when launched is set. If the app closes before [markCompleted](../lib/services/cosmic_memory_tutorial_service.dart:89), the next launch has neither a pending home event nor permission to queue another.

Treat launched-but-incomplete as resumable. Also acknowledge story beats after display: `consumeStoryPending` clears the flag before the home screen rechecks whether it is still active. These interruptions should be covered by save/relaunch tests.

## Priority 2: narrative clarity and consistency

### 6. The opening promises a personal story the campaign barely develops

The prelude's family, waiting, sleep, and despair imagery suggests a specific emotional history. Later scenes mostly ask abstract questions about reality. The imagery is powerful, but players receive little new evidence about what was lost, why creation matters to the speaker, or what the final decision changes.

Keep the mystery of the world's ultimate nature. Establish a smaller concrete motive early: **the alchemist is trying to preserve something memory cannot hold**. Pay it forward at first extraction, first relic, first Mystic, and the Blood Ring. Each beat should add an observation, not just another philosophical question.

### 7. Quote provenance and factual framing need an explicit policy

The first two cards match Aldous Huxley's *Heaven and Hell*. The alchemy passage and closing dream material match Halsey's *Arsonist*. These are externally authored material, not established in-world dialogue. Sources: [Huxley text](https://huxleyarchive.org/Non-fiction/BOOKS/Heaven%20and%20Hell.pdf), [Arsonist source comparison](https://www.stayfreeradioip.com/post/halsey-arsonist-meaning-and-review), [official recording](https://www.youtube.com/watch?v=jhvTUC482a4). The official recording page was identified in search; its full page could not be fetched during this audit.

Maintain a quote register with source, attribution, intended speaker/context, and project permission status. Those permissions cannot be established from this repository audit. For a more distinctive game voice, the proposed rewrites below are original rather than edited lyric quotations.

The fixed seven-year DNA statement is unsuitable as an unqualified scientific fact. Research describes fetal/maternal cell exchange and persistence over decades; that does not establish the card's blanket claim. Preserve its emotional purpose with fictional memory imagery instead. See [Fred Hutch's explanation of microchimerism](https://www.fredhutch.org/en/news/center-news/2014/05/baby-cells-mingle-with-moms-during-pregnancy.html).

The ship quote is grammatically incomplete as currently excerpted: its opening participial phrase lacks the main subject. Its provenance should be recorded rather than attributing it directly to an ancient speaker without verification. The prologue's “He defined hope…” likewise needs either an identified source/person or an original line that makes sense independently.

### 8. First extraction is not first fusion

[FirstBreeding is triggered by the first extraction callback](../lib/screens/breed/breed_screen.dart:179), normally the starter vial. Its current two-to-one wording implies parents the player has not combined. Use first awakening/embodiment text here. Save the two-patterns theme for the first actual successful fusion, and describe inherited patterns rather than suggesting that both parents disappeared.

### 9. The final collection requirement needs earlier foreshadowing

The guardian gate and 16-witness altar gate are distinct. Explain both when the first relic is obtained, not only after the player reaches Blood. Show persistent progress toward guardian clears and completed Mystic rituals, with the next missing requirement linked to its screen. State that prior summons are **recorded witnesses** if ownership and hatching are intentionally unnecessary.

Do not restore the retired constellation requirement merely because old story text mentions it. Constellations currently form a parallel achievement path. Their memory/heartbeat poems can echo the campaign without imposing another completion gate.

### 10. Several names describe the same thing differently

- The altar header prefers catalog names such as Sanguorath, while [_confirmSummon](../lib/screens/mystic_altar/boss_altar_detail_screen.dart:691) uses legacy `boss.name`, such as Crimson King. Resolve one display name throughout; retain stable internal IDs for save compatibility.
- `MSK17` and `MSK18` are both called Bloodmask, with different rarities and descriptions. Both are separate altar requirements. Give the rarer form a distinguishing display epithet or make the rarity distinction prominent in the altar slot and encyclopedia.
- Verdant is the Air faction and maps to the Sky tutorial, while Plant imagery also uses “verdant.” This can work as deliberate world terminology, but pair faction and element visibly (for example, “Verdant — Air affinity”) when first teaching it.
- Use one player-facing name per phase: **fusion** combines patterns; **vial** holds the result; **cultivation/incubation** is the waiting stage; **extraction** releases the specimen; **commitment** permanently offers a specimen; **summoning** gives a Mystic pattern a body.

### 11. Help text must follow the current stat model

[Pure-lineage tutorial](../lib/widgets/pure_breeding_intro_dialog.dart:88) promises base bonuses to three stats upon extraction. The current [_deriveLevelOneStats](../lib/services/egg_hatching_service.dart:248) uses species base, level, Potential, and nature; that calculation contains no purity bonus. Reconcile the tutorial with the intended model before promising an advantage. Contest-specific purity bonuses are a different mechanic.

The contest hints sampled against [_computePlayerContestScore](../lib/screens/cosmic/cosmic_screen.dart:2604) broadly match its authored element, family, appearance, and lineage modifiers. Mixed lineage helping intelligence and pure matching lineages helping specific traits can coexist; explain their conditional nature. Present beauty-trial preferences as those judges' taste, not the game's universal declaration of what is beautiful. That supports the main story's question about beauty and perception.

### 12. Pacing and small copy defects weaken key moments

- [Every intro quote gets seven seconds](../lib/screens/story/story_intro_screen.dart:54), regardless of length. The long collector card needs substantially more reading time than the short questions. Prefer manual advance or length-aware timing with a pause option.
- The [ending's opening sentence](../lib/screens/cosmic/blood_ring_ending_screen.dart:151) begins with “Whether” but never supplies a main clause. Finish the thought and connect it to the player's actual action.
- [Blood gate refusal](../lib/screens/cosmic/cosmic_screen.dart:7131) concatenates “yet” directly with the remaining count. Add punctuation/spacing and preserve the useful count.
- Questions in the altar/home dialogue end as statements or run together. Standardize punctuation while preserving deliberate fragments in poems.
- Survival's ten outbreak names and direct counterplay instructions are a good model: evocative title followed by a concrete action. Use that pattern in other complex tutorials.

## Proposed thematic structure

**Central question:** If you can preserve a pattern, have you preserved the life it belonged to?

This connects existing systems without inventing a new villain or forcing a literal answer about dreams:

| Chapter | What the player does | What the story adds |
|---|---|---|
| I — A form awakens | Extract starter; learn care and fusion | Living form can emerge from an inherited pattern. The alchemist has a reason to notice. |
| II — Something remembers | Explore wilderness; experience the memory visit; recover ship | Familiar places and actions suggest a history the narrator cannot verify. The order of memory and ship beats remains flexible. |
| III — Worlds under seal | Establish a foothold; learn planetary rules; confront guardians | The worlds are constructed around preservation, containment, and selective revelation. Relics make this tangible. |
| IV — Instructions survive | Commit specimens; summon Mystics; gather recorded witnesses | Continuing a form has a cost and does not prove identity or resurrection. |
| V — The pattern you carry | Open Blood; meet Sanguorath; perform the Ring rite | The player accepts responsibility for what they create without being handed a universal explanation. |

Place one short new narrative observation at the first relic, first Mystic, and Blood unlock. If later milestones need text, key them to progress counts so nonlinear planetary order cannot contradict the script. Add a journal for **seen** passages and current objectives; Profile correctly says REPLAY INTRO today, so it should not be criticized as falsely promising a full campaign replay.

Suggested original lines, ready for editorial selection—not inserted into the game:

- Starter extraction: “The vial opens. Something inside it remembers how to live.”
- First actual fusion: “Two patterns leave a third. I recognize both, and neither.”
- Ship discovery: “Beyond the valley, something answers the same signal. I need to know why.”
- Return from the first dungeon: “The valley has not changed. I have learned to doubt what it hides.”
- First relic: “The guardian is silent. Its instruction remains.”
- First Mystic: “The pattern has a body again. That does not tell me who has returned.”
- First relic objective: “Each planetary guardian keeps a relic. Bring it to the Mystic Altar to learn what its pattern requires.”
- Blood unlock: “Sixteen guardians have fallen. Hemavorn opens. The altar still asks for their witnesses.”
- Ring, if the original is retained: “The ring takes an imprint of your companion. Your companion remains; a Bloodborn form begins in the chamber.”
- Closing thought: “I cannot prove what this world was. I can answer for what I make within it.”

## What to preserve

All 137 creature entries have descriptions. The eight-family, seventeen-element structure is legible, and the language consistently supports forms, traces, boundaries, and persistence. The extra Bloodmask is a display-identity issue, not a missing description. Future passes should trade some repeated visual observations for concrete behavior or habitat details; every creature need not speak in the same metaphysical register.

The dungeon names and mechanics give the cosmic expansion its strongest identity: Wind-Crown Spire, Cinder Cathedral, Mirror-Tide Temple, Buried Giant, Storm Circuit, Molten Labyrinth, Molten Reliquary, Venom Monastery, Frozen Observatory, Sinking Altar, Ruins of Time, Prism Labyrinth, Verdant Crypt, Echo Grave, Eclipse Vault, Beacon Archive, and Sanguine Orrery. Their interactions make the theme playable. Keep that specificity.

Keep the difference between a calm instruction voice, a fallible first-person narrator, and concise environmental inscriptions. Coherence does not require making every shop button sound like a prophecy.

## Recommended implementation order and acceptance checks

1. **Protect earned progression:** fix the Bloodborn scale; secure altar and Ring reward transactions; add memory-event recovery. Verify failures/relaunches cannot lose commitments, duplicate rewards, or strand story state.
2. **Repair current facts and routes:** resolve the orphaned planet callback, starter/fusion trigger distinction, legacy Mystic names, Bloodmask distinction, purity-help claim, and malformed gate/ending text. Test both fresh and legacy story flags.
3. **Connect the story:** introduce the central motive and three milestone observations; preserve branching exploration order; surface guardian and witness progress. Explicitly choose the Ring's consequence before revising its dialogue.
4. **Polish and record:** quote register, original replacements where selected, length-aware intro pacing, seen-story journal, and an inventory generated from live content rather than hardcoded historical summaries.
5. **Fresh-save presentation pass:** exercise all four faction openings, both ship/memory orderings, ordinary and family-gated descent, full-chamber summoning, first Blood unlock, missing witnesses, multiple active companions at the Ring, interrupted ending, and replay. The Ring currently checks only the first active slot, so a valid Blood Mystic in another active slot deserves a specific acceptance test.

Estimated acquisition time and full-campaign difficulty remain unmeasured. The collection commitment is verified; how long it feels, and whether the emotional payoff earns that time, require a representative real progression run.
