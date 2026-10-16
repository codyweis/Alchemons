# Story Mode Content Inventory

Authored story text found in the repo, in the order a new player meets it. Re-audited 2026-10-16 against the code. Canon is [campaign_story_canon.md](campaign_story_canon.md).

## Active Story Notes

- `StoryIntroScreen` is part of the real boot flow, not just replay.
- `StoryEvent.firstBreeding` is the only StoryEvent. It fires on the first fusion that lands (`lib/screens/story/first_fusion_story.dart`).
- The first planetary descent is the only place the game says the alchemist made the realms. Earlier text may hint at it but never says it. "The Beautiful Lie" (a Field dialog after the first return from space) was removed on 2026-10-16 because it said this before the descent did.
- Removed earlier and no longer in the game: the "INITIALIZING LABORATORY SYSTEMS" loader and "VIAL SECURED" dialog (2026-10-03), and the boss gauntlet's beats "Alchemy is Power?", "Summon From The Stars" and "The Last Warden?" (2026-06-11, when dungeons replaced the bosses). Also gone: the planet recipe dialogs "The Planet Whispers a Pattern" and "Elemental pathway discovered", and the Blood Ring gate's "Complete planetary recipes to unlock a sacrifice."

## Boot / Replay Story Intro

- Source: `lib/main.dart, lib/screens/profile_screen.dart, lib/screens/story/story_intro_screen.dart, lib/screens/story/models/story_page.dart`
- Reachability: Reachable on first launch, after reset-to-new-game, and from Profile -> Replay Story. The last tap gathers the grains into the faction picker.

- [Quote] "In the history of science the collector of specimens preceded the zoologist and followed the exponents of natural theology and magic."
- [Quote] "But, except in a rudimentary way, he was not yet a physiologist, ecologist, or student of animal behaviour. His primary concern was to make a census, to catch, kill, stuff, and describe as many kinds of beasts as he could lay his hands on."
- [Quote] "Alchemy's not love, it's playing God. And there's a penance paid for entering the temple like a fraud in your charade."
- [Quote] "Did you know the father's DNA stays inside the mother for seven years?"
- [Quote] "Have you ever waited seven years?"
- [Quote] "Have you ever woken from a dream just to realize that you're still asleep?"
- [Quote] "Do you ever wish you were still asleep?"
- [Quote] "Do you ever wish you wouldn't wake up?"

## Wilderness Tutorial Flow

- Source: `lib/screens/scenes/scene_page.dart`
- Reachability: Reachable in tutorial wilderness mode. Presented before the first forced encounter.

- [Voice] Ancient Portal: This portal was created eons ago. Is this false perception? Beauty obstructs reality.
- [Dialog] Alchemy is Power: Tap the wild Alchemon, then choose one of yours to fuse with it. Fusing with a wild Alchemon can produce rare mutations, which only happen in the wild.

## First Fusion

- Source: `lib/screens/story/first_fusion_story.dart`, `lib/screens/story/models/story_page.dart`
- Reachability: Once, on the first fusion that lands, from the breed chamber or the wild. The starter vial fuses nothing, so it does not count.

- [Dialog] An older echo: Two lives pour into one vial. Another presence speaks as though it remembers an earlier ritual.
- [Element Intro] Did two ever exist?
- [Subtitle] Two becomes one again.

## The First Memory

- Source: `lib/screens/home_screen.dart`, `lib/screens/cosmic/cosmic_screen.dart` (`memoryTutorial: true`), `lib/services/cosmic_memory_tutorial_service.dart`
- Reachability: Once, after the third exit from a core wild realm (the harvest tutorial must be done). Home shakes and a portal opens onto a fight in space. This comes before the player has a ship.

- [Voice] Is this a memory?
- [Dialog] The memory drifts: The field thins. Whatever this was, it is already behind you — and you are only remembering it.

## Cosmic: Ship Discovery

- Source: `lib/screens/scenes/scene_page.dart`
- Reachability: Reachable after the ship comes down (the eighth visit to the wild, in whichever realm) and is claimed.

- [Dialog] The Cosmic Ship: "Recognizing that the world is but an illusion, does not act as if it were real, so he escapes suffering."
- [Dialog, if the player walks away] The Cosmic Ship: The ship is beckoning.

## Cosmic: The First Crossing and First Arrival

- Source: `lib/screens/cosmic/cosmic_prologue_screen.dart`, `lib/screens/cosmic/cosmic_screen.dart`
- Reachability: The first time in cosmic space. The prologue plays first, then the intro.

- [Title] FIRST CROSSING: He defined hope as a "waking dream"
- [Title] FOUR GATES
- [Voice] Reality Unfolds: "We are travelers on a cosmic journey, stardust, swirling and dancing in the eddies and whirlpools of infinity."
- [Dialog] Establish Home Base: Fly around and choose where to anchor your home base. Most systems stay locked until home is built.

## Cosmic: The Signal and the Trials

- Source: `lib/screens/cosmic/cosmic_screen.dart`, `lib/games/cosmic_survival/cosmic_survival_screen.dart`
- Reachability: After home is built, then once each when the Survival Portal and the stadium are found. The voices are the journal's "signal" and "stadium" entries.

- [Dialog] Signal Detected: Something out here is sending a signal. Open your map and find where it blinks.
- [Dialog + voice] Survival Portal Unlocked: The signal came from the Survival Portal. Enter it when you are ready. / You follow a signal to a door in the dark. You tell yourself it is only a test of strength.
- [Dialog] A Test? (first survival menu): Something here refuses to finish. The field closes, the wave breaks, the silence returns, and then the same war leans forward again as if no ending was ever allowed to remain. / Is this my creation? Or has this constant alchemical war always existed somewhere beneath memory, waiting for a witness strong enough to mistake it for a test?
- [Dialog] Another Signal: Something else is flashing out here. Find it on your map. Nothing will point the way this time.
- [Dialog + voice] The Trials: Six Alchemons race here, and every stat counts. Fly in and enter when you are ready. / A crowd of lights cheers for what you made. You let them. It is easier than asking what they cheer for.

## Cosmic: Gate Pattern

- Source: `lib/screens/cosmic/cosmic_screen.dart`
- Reachability: Once, on first arrival at a planet's gate.

- [Dialog] A Gate Pattern: Gates take only the cargo your ship carries, not what is banked at home. Fill the meter to the marks on it: a 70% match opens the gate. A failed offering uses up the cargo.

## Cosmic: First Planet Entry

- Source: `lib/screens/story/beauty_mask_reveal.dart` (shown by `lib/games/planet_dungeon/planet_dungeon_screen.dart`)
- Reachability: Reachable once, on the first descent into any planet's dungeon. The cinematic: the descent lands in the live Valley with the party standing in it; the Valley stops, then it and every other wild realm (Sky, Swamp, Volcano, Arcane, Dunes, Geode, Tidal) sift away in turn onto black, the party left standing; the realms' grains gather into the wild map's circles in the dark and come apart; the memory below plays; only as it thins is the planet's room shown (dim, the party on its floor); after the stanza the planet's light rises. Each line waits for a tap.

- [Line] Beauty Obstructs Reality
- The valley is here, where it cannot be.
- [Line] Trees and valleys are absent in this universe.
- It is nothing but desolation and precariousness. Eventually reality seeps through the mind's defense. Why would I create such a world?
- [Line] AM I DREAMING?
- No, I am finally awake.
- [Line] You did not make the realms for the love of Alchemons. You did it to protect your own perception from what you know is wrong.
- [Memory] Your work (`lib/screens/story/work_memory.dart`): in brass grains on black, two wild Alchemons drift in space; the player's ship (the equipped hull) takes them on ropes of grain and they strain against them; they are forced into one sphere (one pulls back out once) and it settles into the kind that leads the party, made from the two kinds the recipe tables most often make it from; the grains it did not need drift off and go out; the ship goes and the memory thins, and the new one crosses, still in brass, to where the party's lead stands in the room and becomes it.
- [Line, during the memory, while they strain] The opening's second card (`AlchemonsStory.darkPrelude[1]`, the collector's census: catch, kill, stuff and describe).
- [Stanza, after the memory, beside the party; a line a tap, each staying as the next comes] I am a collector and Alchemons exist to be collected. / I am not sorry. / I do not need to hide reality behind beauty. / If Alchemy is wrong, why is it so beautiful?

## First Guardian, Relic and Mystic

- Source: `lib/screens/cosmic/cosmic_screen.dart`, `lib/screens/mystic_altar/boss_altar_detail_screen.dart`
- Reachability: The first guardian's dialog plays back in space after the first guardian falls. The altar intro plays on the first visit to a relic altar. The Mystic dialog plays on leaving the altar after the first summon. The guardian and Mystic voices are the journal's "guardian" and "mystic" entries.

- [Dialog] The first relic: It was guarding this place from alchemy. You have called what remains a relic. / Bring the relic to the Mystic Altar. Each elemental ritual requires one of every non-Mystic species of that element.
- [Dialog] A Relic Is Not A Trophy: It is what remains when form fails. Not the creature, not its beauty, but the instruction that endured beneath both. / Is creation discovery or concealment, is beauty truth made visible, or a veil drawn over something worse?
- [Dialog] Another creature: The guardian resisted you. The creature you make from its relic will enter your collection. You know the difference. You continue.

## Blood Mystic Altar Beats

- Source: `lib/screens/mystic_altar/boss_altar_detail_screen.dart`
- Reachability: Reachable in the blood relic altar flow. The altar intro appears once on first entry to the blood mystic ritual; the witness section is a persistent requirement on the blood ritual UI; the space hint appears once after first successfully summoning the blood mystic.

- [Dialog] Not A Return: A relic does not bring something back. It gives the surviving instruction a body again. / If the mystics were made to guard what this world could not bear, then Sanguorath is what remains when sacrifice itself is taught to take shape.
- [Witness Requirement] All 16 prior mystics must already be summoned before the blood mystic ritual can complete.
- [Dialog] Carry It Outward: Do not keep it here. / The stars are not above this world. Bring the blood mystic outward, where the last offering can be witnessed.

## Cosmic: Blood Ring Ending

- Source: `lib/screens/story/blood_finale.dart` (pushed by `lib/screens/cosmic/cosmic_screen.dart` after the ring's ritual plays in space; replayed by tapping the ring once it is done, and from Profile > DEVELOPER > FINALE)
- Reachability: Reachable at the Blood Ring ending ritual. The offering gathers up out of the ring's light in its grains (it is only ever shown as grains), is sacrificed (blood runs down over it and it drips away, all of it, into a pool at its feet), and a new one rises out of the blood, bigger and brighter, embers of blood rising round it: Bloodborn. It is sent below to the chamber (it drips away into the pool and the pool is drawn down), and the credits roll over the census (every species the save has found, in grains, in three lanes; a tapped one comes apart and gathers back). Last comes the vial: that pool sealed in a round chamber, the new one half formed out of it, beating. Each line waits for a tap. In the save the offering is consumed and a Bloodborn Vial waits, ready, in the extraction chamber (or cold storage); its extraction has its own ceremony, in which the blood shell melts into a pool, three heartbeats pass, and the reborn rises.

- [Picker] Choose Favorite Alchemon: Sacrifice and rebirth: choose a reserve companion to offer. It is consumed, and a Bloodborn Vial goes to your extraction chamber. What is extracted keeps its level, training and nickname; any Potential below 95 becomes 95, and none is lowered. Its Potential Souls come back to you. This cannot be undone.
- [Line] Every collection has a favorite.
- [Line] Alchemy is power.
- [Line] Favorites can always become stronger.
- [Credits] ALCHEMONS (the title in grains) / Created by: Cody Weisenberger, Luck3yApps LLC / Alchemon designs and sprites by: Nehaalg / Music by: Cleyton Kauffman, GloryToTheMachine / Special thanks to: Bryce, Whitney, Diego
- [Line] The census is finished. The collector is not.
- [Line] Thank you for playing.

## Journal: Memories

- Source: `lib/services/campaign_journal_service.dart` (`campaignEntries`), read in Journal → Memories (`lib/screens/story/campaign_journal_screen.dart`)
- Reachability: Each entry unlocks at its moment. Only "signal", "stadium", "guardian" and "mystic" are also shown as dialogs (above). "Revelation" is a line of the first descent. The rest appear in the journal without an announcement. The ending has no memory (removed 2026-10-16); its "Reborn" achievement is the only record.

- [Waking] (first extraction) You wake somewhere beautiful enough that you never think to ask why you needed it.
- [The first form] (first extraction) A living thing leaves the vial. You call it a discovery. The word comes easily.
- [A memory returns] (the first memory done) Am I beginning to remember? But what is remembrance without truth, if not illusion.
- [Beyond the realms] (ship recovered) You follow the ship beyond the world that soothed you. Something there remembers your work.
- [The signal] (Survival Portal found) You follow a signal to a door in the dark. You tell yourself it is only a test of strength.
- [Lights in the dark] (stadium found) A crowd of lights cheers for what you made. You let them. It is easier than asking what they cheer for.
- [Beauty obstructs reality] (first descent) You did not make the realms for the love of Alchemons. You did it to protect your own perception from what you know is wrong.
- [The first relic] (first guardian) It was guarding this place from alchemy. You have called what remains a relic.
- [Another creature] (first Mystic) The guardian resisted you. The creature you make from its relic will enter your collection. You know the difference. You continue.
- [The last guardian] (Sanguorath) Nothing beautiful stands between you and your work now. Still, you prepare another ritual.

## Pure Lineage Extraction Intro

- Source: `lib/widgets/pure_breeding_intro_dialog.dart`
- Reachability: Reachable once on first pure extraction result. More explanatory than dramatic, but still part of the narrative framing around breeding.

- [Dialog] Pure lineage: You extracted a Pure Alchemon: its ancestry resolves to one element line and one species line. This one carries a <element> element line and a <family> family line. / Purity is tracked apart from generation, so a line stays pure for as long as its ancestry stays unbroken.
- [Dialog] What purity does: A pure line strengthens one stat, chosen at extraction and fixed for life. A full line raises one of the four by 15%. An element line raises Beauty or Intelligence by 10%; a species line raises Speed or Strength by 10%. Analysis shows which one it rolled. / Everything else still comes from species, level, Potential, nature and Enhancement.

## Constellation Story Fragments

- Source: `lib/games/constellations/constellation_game.dart`
- Reachability: Reachable as animated connection text in the constellation trees.

- [Breeder Tree] In the hush before barter,
- [Breeder Tree] The first heartbeat
- [Breeder Tree] or waking breath,
- [Breeder Tree] the moment marking
- [Breeder Tree] flesh and life,
- [Breeder Tree] a flicker in the night,
- [Breeder Tree] the light grows,
- [Breeder Tree] the light flickers,
- [Breeder Tree] then fades,
- [Breeder Tree] can you remember
- [Breeder Tree] the glow?
- [Combat Tree] They built the arena in a place sound refused to cross.
- [Combat Tree] No cheers, no drums, only breath and impact.
- [Combat Tree] Your first step inside felt heavier than gravity allowed.
- [Combat Tree] Old scars in the floor traced obsolete strategies.
- [Combat Tree] You stood where legends once evaporated into statistics.
- [Combat Tree] A single light followed you like an accusing star.
- [Combat Tree] Your partner waited, muscles coiled, eyes full of questions.
- [Combat Tree] You answered with a gesture: not command, but invitation.
- [Combat Tree] The opening move drew a new constellation of motion.
- [Combat Tree] Every dodge rewrote your understanding of survival.
- [Combat Tree] Victory arrived not as triumph, but as continued existence.
- [Combat Tree] Outside, the world kept turning, indifferent but available.
- [Combat Tree] You left the ring marked—less by wounds than by clarity.
- [Combat Tree] Protection, you realized, is just violence with better boundaries.
- [Combat Tree] From then on, every fight was a negotiation with fate.
- [Combat Tree] The arena stayed silent, but the sky learned your name.
- [Extraction Tree] The loneliness
- [Extraction Tree] of the night
- [Extraction Tree] stands before me,
- [Extraction Tree] silence is the only thing
- [Extraction Tree] to be heard.
- [Extraction Tree] My thoughts are released
- [Extraction Tree] and now are set free.
- [Extraction Tree] But silence
- [Extraction Tree] is still present,
- [Extraction Tree] for thoughts
- [Extraction Tree] are not words.

## Cosmic Contest Hint Lore

- Source: `lib/games/cosmic/cosmic_contests.dart`
- Reachability: Reachable as collectible hint notes in cosmic contest arenas. Not main story, but definitely authored quote/lore content.

- A torn note: "Lightning, water, and ice are whispered to outrun all."
- A racer's chalk mark: "Wing bloodlines catch speed early."
- A pit-lane scrap: "Let lines launch quick off the start."
- A bent telemetry card: "Swift by name, hyperbolic by legend - both love speed."
- A storm etching: "Pure lightning lineages hold pace better than mixed drag."
- A polished shard reads: "Crystal and light hold beauty better than poison ever could."
- An engraved plate: "Prismatic coats draw every eye in beauty trials."
- A stage memo: "Rare variants and unusual tints tend to sway the judges."
- A velvet ribbon note: "Single-element blood sings cleaner on the beauty floor."
- A critic ledger: "Pure species lines read as deliberate elegance, not noise."
- A perfume card: "Elegant natures bloom brighter under lights."
- A basalt tablet: "Earth and lava bodies endure where soft forms fail."
- A field memo: "Large frames carry momentum; size matters in strength."
- A smudged journal: "Winged lines usually gain tempo before the horned."
- A cipher strip: "Deep mixed lineages think in more patterns than pure strains."
- A library scrap: "Spirit, light, dark, and crystal are favored in mind duels."
- A critic card: "Judges penalize corrosive palettes - poison and blood rarely place."
- A track warning: "Mud and earth drag acceleration in speed lanes."
- A coach note: "Horn and mane bloodlines often peak in raw force."
- A cracked plate: "Mighty natures convert stance into impact."
- A quarry annotation: "Pure earth-heavy lines keep leverage through the shove."
- A margin note: "Mask and kin lines tend to solve puzzle rounds faster."
- A librarian's tag: "Clever natures break cipher loops quickly."
- A neural sketch: "Neuroadaptive minds learn between rounds, not after."
- A sealed thesis: "Pure species lines retain cleaner memory structures."
- A folded field card: "Purity matters most when the bloodline matches the contest trait."

## Suggested Optimization Targets

- Unify the story funnel. Right now the game has authored narrative in several separate systems that do not share one clean chronological progression.
- Make Replay Story mirror the real campaign flow if that screen is meant to summarize the player journey.
- Normalize tone across features. The game has at least four voices right now: existential intro, tutorial instruction, cosmic metaphysics, and system explanation.
