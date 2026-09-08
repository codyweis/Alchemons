# Campaign canon and implementation decisions

Confirmed with the creator September 8, 2026. This supersedes the proposed central theme in the September 7 [audit](game_progression_story_audit.md).

## The story

**Beauty masks reality.** The unnamed player is the alchemist. He once pursued alchemy at the expense of living things, then made a beautiful false world to conceal that cruelty and escape his own nature. He awakens without remembering. The wilderness is this beautiful mask; cosmic space and its dangerous planets are the reality beneath it.

Uncovering reality initially drives the player. On first planetary descent, the familiar Valley appears and disintegrates into the actual planet. Eventually the alchemist recognizes himself. Knowledge does not free him from the desire to continue. He collects, breeds, takes guardian relics, and recreates creatures while understanding what he is doing. The character's tragedy is relapse into a desire he once tried to escape, rather than an uncomplicated redemption or acceptance of fate.

Desired feelings: curiosity, guilt, unease. First-person passages and new fragments can belong to another presence or a memory. Their ambiguity is deliberate. Guardians protect their planets **from alchemy**. Summoned Mystics are new creatures entering the collection, not evidence that the defeated being was resurrected.

Alchemons occupy the tension between companions and specimens. Collection offers satisfaction at the expense of living things. The atmosphere can remain mysterious while mechanical requirements and permanent consequences remain explicit.

## Text policy

- Preserve existing quotations. Do not remove or replace them without the creator's specific confirmation.
- The opening's family/seven-year/sleep references primarily serve atmosphere; do not build an unapproved literal family backstory around them.
- Add original connective passages to explain the intended arc, with the presence identified as such.
- The DNA claim and external quotation provenance remain flagged in the audit. Their retention is not a factual endorsement or a verification of permissions.
- The ending's existing first sentence was completed with a main clause; its original opening wording remains. New final passages establish attempted change, recovered memory, and continued ritual.
- Story cards wait for a tap. Cinematic movement can animate, but it cannot dismiss the text automatically.

## Progression contracts

- Keep the complete-collection ending: all 16 earlier guardians, the recorded 16 earlier Mystic summons, the Blood guardian, Blood altar requirements, and the Ring.
- Survival, contests, Pureblood rites, constellation completion, and base progression remain optional activities; achievements do not add story gates.
- The Blood Ring uses sacrifice/rebirth language, but **transforms the same instance** into Bloodborn. It keeps its ID, species, nickname, level, XP, nature, genetics, Dominants, and Enhancement ranks. All four Potentials become **95/100** and current stats are recalculated. No duplicate creature or vial is created.
- Existing completed Ring saves remain completed. This pass does not silently alter creatures from past rewards or replay rewards for them.
- Commitments and Mystic rewards are transactional. A full chamber sends the Mystic vial to Cold Storage without purchasing capacity.
- Preserve existing saves and permanent earned progress. Interrupted memory events can resume; story seen flags are acknowledged after reading.

## Delivered surfaces

- **Home book button / Profile → Journal & Achievements.** Journey shows the next requirement; Memories shows unlocked campaign fragments and preserves the opening passages; Achievements offers one-time Gold/Silver claims.
- **First planetary descent.** The live dungeon remains frozen behind layered Valley art. Tap to dissolve the mask, then acknowledge the awakening and presence. Completion persists only after acknowledgment, so interruption does not lose the reveal. Reduced-motion mode skips the dissolve motion.
- **First relic and first Mystic.** Added presence passages state what the guardian resisted and distinguish it from the collected creature. Existing altar quotes remain.
- **First extraction.** The original two-to-one passage is introduced as an older remembered ritual, so it does not falsely describe the starter vial's creation.
- **Return to wilderness.** Existing Self Deception dialogue now responds to the actual new revelation milestone while respecting its old flag for legacy saves.
- **Ending.** Existing passages remain, with additional relapse-oriented text and an explicit same-companion transformation preview before selection.

The suggested blinking-eyes effect on the home page remains an optional presentation idea, not part of this implementation. It should be staged alongside the existing starter modal rather than racing it.

## Achievement reward schedule

Rewards are intentionally modest additions to the existing economy. They are granted only on an explicit Collect action, with eligibility checked again inside the database transaction.

| Achievement | Gold | Silver |
|---|---:|---:|
| Discover 10 / 25 / 50 / 100 species | 1 / 2 / 3 / 5 | 100 / 250 / 500 / 1000 |
| Discover every catalog species | 10 | 1500 |
| First extraction | 1 | 100 |
| Recover ship | 2 | 200 |
| See planetary revelation | 2 | 250 |
| Overcome 1 / all 16 earlier guardians | 2 / 8 | 250 / 1000 |
| First Mystic summon | 2 | 250 |
| Complete the Blood Ring | 10 | 1500 |
| Clear Survival wave 20 / 50 | 3 / 8 | 300 / 1000 |
| Complete five Pureblood rites | 3 | 400 |
| Win a round in each contest discipline | 2 each | 250 each |

Collection uses permanently discovered catalog species, not currently owned specimens. Existing saved progression counts. Saved Survival wave reached is conservatively treated as the previous wave cleared; new clears are recorded immediately. Earlier Pureblood ladder stages count, and weekly completions are counted from this update onward because old saves do not contain a complete weekly history.

## Verification and limits

Validation completed: 397 tests passed across campaign progression, story UI, planet layouts, and the Blood Orrery. Targeted Flutter analysis reports no issues.

Database tests exercise duplicate reward taps, rollback after injected write failures, full-chamber storage, retained specimen identity/training, exact 95 Potential, missing companions, Blood witness gates, immediate Survival clear credit, and interrupted story recovery. Widget checks cover tap-only reveal progression and a 390-pixel-wide journal. Preview exports use a plain background stand-in for the live planet; normal gameplay shows the actual dungeon underneath.

Phone performance and a complete fresh-save campaign run still need device playtesting. This pass does not rebalance species acquisition time or lower collection requirements. The Journal is a campaign record; it does not yet archive every incidental contest note or every constellation inscription.


## Achievement UX follow-up

The trophy entry on Home and Profile now opens Achievements directly. The main story mission, explicit requirement, chapter number, progress, and reward occupy the top card. Story progress and Memories are secondary screens. Ten mission milestones cover the starter, ship, revelation, first guardian, first Mystic, all earlier guardians, Blood guardian, sixteen witnesses, Blood Mystic, and Ring. Existing story achievement IDs remain the reward IDs, preserving collected rewards and preventing duplicate payouts.

Ready rewards appear first with individual Collect buttons and Collect all. Unfinished achievements have category filters and progress; collected achievements collapse below. Three new late-story rewards grant 4 Gold / 500 Silver for the Blood guardian, 8 / 1000 for sixteen witnesses, and 5 / 750 for the Blood Mystic.

In-game notifications include an unclaimed-reward count on the trophy and a View notification for newly available rewards. Refreshes follow database changes, returning to the screen, and app resume; they do not poll during gameplay or request system push-notification permission. Old ship owners are credited for the prerequisite starter mission even if their save predates its flag.
