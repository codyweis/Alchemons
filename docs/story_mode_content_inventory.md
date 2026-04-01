# Story Mode Content Inventory

Generated from authored text found in the repo.

## Active Story Notes

- `StoryIntroScreen` is part of the real boot flow, not just replay.
- `StoryEvent.firstBreeding` is the only StoryEvent currently triggered in gameplay.
- Dormant StoryManager branches and the old `sproutling` reveal path were removed from source.

## Boot / Replay Story Intro

- Source: `lib/main.dart, lib/screens/profile_screen.dart, lib/screens/story/story_intro_screen.dart, lib/screens/story/models/story_page.dart`
- Reachability: Reachable on first launch, after reset-to-new-game, and from Profile -> Replay Story.

- [Quote] "In the history of science the collector of specimens preceded the zoologist and followed the exponents of natural theology and magic."
- [Quote] "But, except in a rudimentary way, he was not yet a physiologist, ecologist, or student of animal behaviour. His primary concern was to make a census, to catch, kill, stuff, and describe as many kinds of beasts as he could lay his hands on."
- [Quote] "Alchemy's not love, it's playing God. And there's a penance paid for entering the temple like a fraud in your charade."
- [Quote] "Did you know the father's DNA stays inside the mother for seven years?"
- [Quote] "Have you ever waited seven years?"
- [Quote] "Have you ever woken from a dream just to realize that you're still asleep?"
- [Quote] "Do you ever wish you were still asleep?"
- [Quote] "Do you ever wish you wouldn't wake up?"
- [Loading] INITIALIZING LABORATORY SYSTEMS

## StoryManager: firstBreeding Queue

- Source: `lib/screens/story/models/story_page.dart + lib/screens/breed/breed_screen.dart`
- Reachability: Currently the only StoryEvent wired through StoryManager. Fires after the first extraction completes.

- [Element Intro] Did two ever exist?
- [Subtitle] Two becomes one again.

## Starter / Extraction Setup

- Source: `lib/screens/home_screen.dart`
- Reachability: Reachable during starter grant flow.

- [Dialog] VIAL SECURED
- Your vial has been placed in the Extraction Chamber and is ready for processing.

## Wilderness Tutorial Flow

- Source: `lib/screens/scenes/scene_page.dart`
- Reachability: Reachable in tutorial wilderness mode. Presented before the first forced encounter.

- [Dialog] Ancient Portal
- This portal was created eons ago. Is this false perception? Beauty obstructs reality.
- [Dialog] Alchemy is Power
- Tap the creature to begin your first fusion. Select one of your Alchemons to attempt the fuse. Alchemons are stronger here. Fusing with them should provide formidable results.
- [Success Dialog] Fusion Successful!
- Your new Alchemon is cultivating in the chamber.

## Post-Planet Wilderness Beat

- Source: `lib/screens/scenes/scene_page.dart`
- Reachability: Reachable once after the first cosmic planet-entry story has happened, on first visit to valley/sky/swamp/volcano.

- [Dialog] Self Deception
- Does reality dictate beauty?

## Cosmic: First Planet Entry

- Source: `lib/screens/cosmic/cosmic_screen.dart`
- Reachability: Reachable on the first pathway entry into a cosmic planet scene.

- [Dialog] Beauty Obstructs Reality
- [Dream Prompt] AM I DREAMING?
- [Response] No, I am finally awake.
- [Desolation Popup] Trees and valleys are absent in this universe.
- It is nothing but desolation and precariousness. Eventually reality seeps through the mind's defense. Why would I create such a world.

## Cosmic: Recipe / Pathway Guidance

- Source: `lib/screens/cosmic/cosmic_screen.dart`
- Reachability: Reachable through cosmic progression.

- [Dialog] The Planet Whispers a Pattern
- Something in this sphere remembers an older design. An alchemical recipe lies veiled here. Gather the essences it asks for, and when the pattern is whole, let the summon answer.
- [Dialog] Elemental pathway discovered.
- A new route has opened. Recipes now reveal how to enter the planet.

## Cosmic: Ship Discovery

- Source: `lib/screens/scenes/scene_page.dart`
- Reachability: Reachable after visiting all four core biomes and finding the ship in valley.

- [Dialog] The Cosmic Ship
- "Recognizing that the world is but an illusion, does not act as if it were real, so he escapes suffering."

## Cosmic: Blood Ring Ending

- Source: `lib/screens/cosmic/blood_ring_ending_screen.dart`
- Reachability: Reachable at the Blood Ring ending ritual.

- [Flash] THE BLOOD RING AWAKENS
- Whether you accept reality for the beauty it is, or forge deceptions of beauty to shield yourself from chaos, the ring does not care.
- Reality bends to the witness and the wound at once. What you call truth is only a story that survived long enough to be believed.
- <mysticName> and <favoriteName> stand at the seam of worlds, where every certainty dissolves into choice.
- If all things are constructs, then this construct is yours now. Walk forward.

## Cosmic: Blood Ring Gate

- Source: `lib/screens/cosmic/cosmic_screen.dart`
- Reachability: Reachable if the player finds the Blood Ring before the first planet-entry pathway story has been seen.

- [Gate Message] Complete planetary recipes to unlock a sacrifice.

## Boss Gauntlet Intro

- Source: `lib/screens/boss/boss_intro_screen.dart`
- Reachability: Reachable once on first entry to the boss gauntlet screen.

- [Dialog] Alchemy is Power?
- Power does not wait for morality to agree. Break a warden, take the relic, and you begin to see the question beneath all of this: were these created to reveal reality, or to keep reality...real?

## Blood Boss Gate Beats

- Source: `lib/screens/boss/boss_intro_screen.dart`
- Reachability: Reachable around the final blood-boss unlock path. The unlock beat fires after first defeating boss 016; the lock popup appears if the constellation finale has not been seen; the victory beat fires after first defeating the blood boss.

- [Dialog] Summon From The Stars
- The constellations do not guide the way to Sanguorath. They bar it.
- Only a summons drawn from the stars can open the entrance.
- [Locked Popup] Summon From The Stars
- The constellations still bar the entrance to <boss name>.
- Summon from the stars before the way will open.
- [Dialog] The Last Warden?
- This was never an ending. Only the final guard.
- Blood was not the secret, only the cost. Take the relic back. What waits at the altar is not resurrection, but the proof that a form can be made to continue.

## Boss Relic / Mystic Altar Intro

- Source: `lib/screens/mystic_altar/boss_altar_detail_screen.dart`
- Reachability: Reachable once on first entry to the boss relic altar detail screen.

- [Dialog] A Relic Is Not A Trophy
- It is what remains when form fails. Not the creature, not its beauty, but the instruction that endured beneath both.
- Is creation discovery or concealment, is beauty truth made visible, or a veil drawn over something worse.

## Blood Mystic Altar Beats

- Source: `lib/screens/mystic_altar/boss_altar_detail_screen.dart`
- Reachability: Reachable in the blood relic altar flow. The altar intro appears once on first entry to the blood mystic ritual; the witness section is a persistent requirement on the blood ritual UI; the space hint appears once after first successfully summoning the blood mystic.

- [Dialog] Not A Return
- A relic does not bring something back. It gives the surviving instruction a body again.
- If the mystics were made to guard what this world could not bear, then Sanguorath is what remains when sacrifice itself is taught to take shape.
- [Witness Requirement] All 16 prior mystics must already be summoned before the blood mystic ritual can complete.
- [Dialog] Carry It Outward
- Do not keep it here.
- The stars are not above this world. They are part of the seal. Bring the blood mystic outward, where the last offering can be witnessed.

## Survival Mode Intro

- Source: `lib/games/survival/survival_game_screen.dart`
- Reachability: Reachable once on first entry to the survival menu.

- [Dialog] A Test?
- Something here refuses to finish. The field closes, the wave breaks, the silence returns, and then the same war leans forward again as if no ending was ever allowed to remain.
- Is this my creation? Or has this constant alchemical war always existed somewhere beneath memory, waiting for a witness strong enough to mistake it for a test?

## Pure Lineage Extraction Intro

- Source: `lib/widgets/pure_breeding_intro_dialog.dart`
- Reachability: Reachable once on first pure extraction result. More explanatory than dramatic, but still part of the narrative framing around breeding.

- [Dialog] Pure Lineage Extracted
- You just extracted a Pure Alchemon.
- Pure means its ancestry resolves to one element line and one species line.
- Pure specimens get small base bonuses to Beauty, Strength, and Intelligence when they are extracted.

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
