# Responsiveness: a tap is answered at once

The rule (2026-10-21, after the battle lobby's LEAVE "froze for a bit"): **a
screen never waits on the network, or on heavy work, before it answers a
tap.** The tap is answered on the next frame: the screen moves, the button
turns, the notice shows. What has to happen elsewhere happens behind it.

## Firestore writes

Firestore has a write on this phone the moment it is made. The listeners
(`snapshots()`) fire with it straight away, flagged `hasPendingWrites`, and
the SDK sends it to the server when it can, even after the screen has gone.
Awaiting the write only waits for the server's acknowledgement. That takes
0.2–1 s online, and with our 20 s timeouts it can take 20 s offline.

So:

- **Don't `await` a write in a tap handler.** Start it and go on. Rooms and
  similar services have `later(write)`. It logs failures and shows a notice
  (`showGameSnackAnywhere`) only for a refusal (permission denied, not
  found). Being offline isn't a refusal: Firestore keeps the write and sends
  it later.
- **Let the screen follow the snapshot, not the write.** A READY label, a
  seat, a room's state come from the room as this phone has it, so they
  change at once.
- **Create documents with an id made on the phone** (`collection.doc()`) and
  open the screen on that id at once. Room services have `hostNow(...)` for
  this. Their `host(...)` is the awaited form, for tests.
- **Close or leave first, write after.** Pop the screen, then send the
  delete or update. When the host closes a room, its stream goes in one
  batch with the room delete.
- **Guard double taps with local state** (for example, the run START was
  pressed for), not by disabling a button until the server answers.
- **Await only what the next step truly needs**, and show that wait at once
  (the button says what is happening). Examples: reading a friend's home
  before picturing it, or reading the server clock.

## Heavy work on the UI thread

Building a field (`SceneGame`), picturing a game (`RealmPicture.record`,
`toImage`), decoding many sprites, and long loops all run on the screen's
own thread and stall it.

- **Never during a route's way in or out, or a cinematic.** Wait for the
  route's animation to complete and for a short still moment. See
  `BattleJourneyPrep._whenStill`.
- **Spread it across frames.** `await WidgetsBinding.instance.endOfFrame`
  between steps.
- **Do it ahead, while the screen is idle,** and keep the result. The live
  battle's home picture is taken in the lobby, so the way in only draws a
  picture.
- **Stop work that is no longer wanted.** The lobby drops the picture
  build when a fight starts before it's done.
- **Mount nothing heavy offstage that ticks.** Pause Flame games until they
  are shown (`pauseEngine`, then `stepEngine` to warm up). Opaque routes over
  live screens keep the screens underneath from drawing.

## Checking it

- **Fake Firestore applies writes instantly, so tests don't catch a waiting
  screen.** Read the tap handlers for `await` on a write before a
  navigation or a visible change.
- **On the Fold** (profile build), a tap that doesn't move the screen within
  a frame or two is a bug. To find the stall, use `tool/cpu_profile.dart`
  (see the perf toolkit notes).
