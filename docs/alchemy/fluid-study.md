> Current implementation: the bulk-material rebuild below supersedes the earlier
> 750-particle studies. Earlier performance figures do not apply to this engine.

# Materia: Water / Fire / Steam

Open Profile → General Settings → Alchemy Chamber.

This replaces the original cell renderer in the native chamber. It is a focused interactive study, not the complete seventeen-element sandbox. The canonical Fire+Water recipe is checked on load; there are no randomized reaction rolls. Contact transfers heat, creates vapor, and eventually consumes heated water particles. Nothing writes to the player save.

## Architecture

- `fluid_scene.dart`: fixed-step continuous water particles, a spatial hash, cohesive forces and separation constraints; semi-Lagrangian transport and pressure projection for heat and vapor. No Flutter dependencies.
- `alchemy_fluid.frag`: reconstructs water as an isosurface with normals, specular highlights, optical depth and refraction-like shading. Heat emission and vapor density are driven by simulated fields. Noise adds visual detail only.
- `fluid_scene_painter.dart`: one shader draw. No per-particle blur or large stack of compositing layers.
- `alchemy_chamber_screen.dart`: pointer controls, lifecycle, bounded texture uploads, shader/image cleanup and frame timing instrumentation.

Simulation is bounded at 750 water particles and a 64×96 field. Water/field updates use a 60 Hz fixed step. Density uploads are capped at 60 Hz and shader animation runs at display cadence. These are explicit quality limits, not a claim of a high-resolution physical fluid solver. The single water density field has no stable three-dimensional refraction or ray tracing.

The previous cell simulation and its 41-recipe tests remain isolated as a reference for later element integration. They do not drive the replacement screen.

## Verification

```
flutter test test/alchemy_simulation_test.dart test/alchemy_fluid_test.dart test/alchemy_chamber_screen_test.dart
flutter analyze lib/games/alchemy lib/screens/alchemy_chamber_screen.dart lib/alchemy_benchmark.dart
```

With `--dart-define=ALCHEMY_CAPTURE=true`, the renderer test writes `/tmp/materia_gpu.png` using the actual runtime shader.

## On-device profiling

```
flutter run --profile -t lib/alchemy_benchmark.dart -d DEVICE_ID
```

This uses the same application ID as the main app: restore the regular release afterward using an update install (never uninstall or clear data). Leave the app foregrounded for at least 40 seconds. The benchmark warms up for four simulated seconds, then exercises pouring, heat and stirring. It prints `ALCHEMY_BENCHMARK` with simulation CPU p95, Flutter build p95, raster p50/p95 and the number of raster frames over 16.67 ms. Shader/image encoding time is not included in the simulation CPU number; frame timings cover the rendering path. Profile results are not a guarantee of sustained performance under thermal load.

The first completed profile run on the connected Samsung (SM F971U1, Impeller/Vulkan) collected 1,615 raster samples at a maximum of 750 water particles:

- Simulation CPU p95: 13.339 ms.
- Flutter build p95: 14.508 ms.
- Raster p50: 0.858 ms; raster p95: 1.646 ms.
- Raster samples over 16.67 ms: 0.

That run used 30 Hz texture uploads. The next revision shares interpolation work across the four transported fields and precomputes per-frame/per-row coefficients, and increases texture updates to 60 Hz. The optimized run, including 60 Hz texture uploads, collected 1,652 raster samples:

- Simulation CPU p95: 10.848 ms (18.7% lower).
- Flutter build p95: 12.591 ms (13.2% lower).
- Raster p50: 0.930 ms; raster p95: 1.684 ms.
- Build samples over 16.67 ms: 26 / 1,652 (1.57%).
- Raster samples over 16.67 ms: 0.
- 750 particles at the end; 25 completed evaporation events.

This improves measured headroom but does not establish a locked 60 fps or sustained thermal performance. CPU figures omit density encoding / image upload; do not add them to build duration because build timings already include overlapping work.


## Mineral expansion — 2026-09-30

The chamber now offers Water, Fire, Earth, Mud, Lava and Stir. Steam emerges from water/heat contact. Earth+Water produces Mud in either ingredient order; Earth+Fire and Mud+Fire produce Lava. These main products are validated against the canonical JSON. This is still a subset of the full element system: reactions whose products have not been implemented (for example Lava+Mud→Poison) are deferred. Lava’s crust is an optical effect, not a new cooling recipe.

Material density is now reconstructed at 128×192, while the flow solver remains 64×96. A single 256×192 opaque RGB atlas holds water/earth/mud in its left half and lava/heat/vapor in its right half. Linear interpolation replaces the old per-cell eased interpolation, eliminating repeated flat spots in surface normals. Resolution-aware edge smoothing works on both Skia and Impeller. The automatic source reserves 150 particle slots for manual input.

`fluid_worker.dart` runs simulation and density encoding in a persistent isolate. Only one request may be in flight; commands are batched, pending time is capped, textures use transferable buffers, and workers are killed on route disposal. Drawing and gestures stay on the UI isolate. The phone also displays the most recent reaction.

### Mixed-material device measurements

A direct-on-UI implementation regressed under the expanded workload (750 particles): build p95 28.408 ms, simulation CPU p95 18.782 ms. That implementation was rejected.

The background-worker revision on the same Samsung / Impeller Vulkan workload completed with:

- 1,734 frame timing samples; 1,918 presented frames and 1,920 field packets over 32 simulated seconds.
- Worker p95 (simulation plus encoding): **13.842 ms**.
- Flutter build p95: **1.205 ms**.
- Raster p50: **0.815 ms**; raster p95: **0.877 ms**.
- Build samples over 16.67 ms: **0**. Raster samples over 16.67 ms: **0**.
- 750 particles and 570 recorded transformations at completion.

Worker and main-thread work run concurrently; do not sum their timings. This is a short profile benchmark, not a thermal endurance guarantee. The earlier 30/60 Hz single-material results above describe historical revisions.

Additional verification: `test/alchemy_worker_test.dart` checks batched input, transferred texture size, clear while paused and disposal during startup. The complete alchemy suite has 16 passing tests, including both material renders and four screen sizes.

## Continuous reconstruction pass

The shader now reconstructs both atlas layers with a 4×4 cubic B-spline basis. It computes analytic density derivatives from the same basis for surface normals; it no longer estimates normals from separately interpolated neighboring fields. The basis has continuous first and second derivatives at sample boundaries. Every tap is clamped within its atlas half. The GPU performs this reconstruction without increasing simulation or texture dimensions.

Low-density flame emission now fades continuously instead of switching on at a fixed heat threshold. Vapor edge lighting uses the reconstructed derivative as well. Render verification includes 3× views drawn directly from the runtime shader, written under `/tmp/materia_water_closeup.png` and `/tmp/materia_mineral_closeup.png` with `ALCHEMY_CAPTURE=true`. Water, flame, and mineral boundaries were visually inspected; the simulation is still particle-based, so small rounded surface undulations are expected and are distinct from grid tiling.

The cubic pass completed its Samsung/Impeller profile run with 1,683 frame samples, 1,916 presented frames, and 1,862 field packets over 32 simulated seconds: worker p95 16.378 ms, build p95 1.221 ms, raster p50 0.815 ms, raster p95 0.873 ms. There were zero measured build or raster frames over 16.67 ms. These concurrent-stage measurements do not imply a thermally sustained or perfectly uniform simulation update rate.


## Device-only detail seams — 2026-09-30

The user's phone screenshot still showed rectangular patches after cubic density reconstruction. Desktop Skia render captures had missed them. A diagnostic entry point, `lib/alchemy_render_probe.dart`, now exports frozen water and mixed-material scenes using the phone's actual runtime shader backend. Run with `flutter run --profile -t lib/alchemy_render_probe.dart -d DEVICE_ID`; PNG paths are printed as `ALCHEMY_PROBE`. Retrieve those generated files, then restore a normal `lib/main.dart` release using an update install. This diagnostic replaces the launcher temporarily and does not clear app data.

On the Samsung's Impeller/Vulkan renderer, identical frozen-field comparisons showed:

1. Original shader: rectangular discontinuities in the flame and lava detail.
2. Explicit high precision: identical PNG to the original, with seams remaining.
3. Constant procedural noise: the rectangular patches disappeared while field reconstruction stayed unchanged.
4. Continuous domain-warped waves: detail returned without visible rectangular seams in the inspected scene.

The production detail function now uses bounded sums of smooth directional waves instead of interpolated floating-point corner hashes. The comparisons isolate the observed defect to the procedural detail path; they do not establish a specific compiler or driver bug. Density reconstruction, simulation, recipes, and texture resolution are unchanged. Future visual verification must include device renders, not only desktop tests.

All 16 alchemy tests pass, including runtime shader renders and four screen sizes; targeted analysis reports no issues. The visual comparison covers frozen water/mixed scenes, not every possible arrangement or device.

The follow-up timing run did not complete because the app left the foreground before its sampling window ended. No new frame-time claim is made for this detail replacement; the earlier cubic-pass figures are historical. The normal release build succeeded.


## Bulk-material rebuild — 2026-09-30

### Capacity and interaction

`fluid_scene.dart` now uses a 160×240 dense typed-array material lattice, with **36,660 usable cells** inside the boundary. There is no 750-particle cutoff or pairwise particle search. Reset and entry both start empty with Source off. The chamber shows percentage occupied, supports continuous pouring (48 requested cells per 60 Hz input step, limited by available local space), drag stirring, a local eraser, pause, reset and clear. Pouring into occupied cells never overwrites them.

Water, Fire, Earth and Air are available directly. The Elements picker exposes all 17 canonical elements; Stir and Erase remain independent tools. Controls wrap on narrow screens. Filling the vessel is limited by actual spatial capacity, not a hidden count smaller than the vessel.

### Material transport and recipes

The worker loads the canonical recipe JSON and builds a symmetric fixed-size lookup table for all 41 pairs. Each known contact always produces the main product; original weights only identify that product and are never rolled. Both participating cells become the product so reactions retain bulk volume. Gases vent at the ceiling and have finite lifetimes; these are explicit material-removal mechanisms, alongside Erase/Clear.

Liquids settle and spread laterally; Mud and Lava move more slowly. Powders fall and form slopes. Solid-phase materials remain anchored unless directly stirred. Density determines downward displacement between different movable substances. Stir applies bounded directional impulses through adjacent swaps, avoiding teleportation through walls. Gas drift varies by height and time, and Fire/Lightning fade as they age. This is a cellular material sandbox, not a full incompressible-fluid solver.

### Rendering and verification

A 640×240 opaque atlas packs four RGB fields: dense albedo, dense/gas occupancy plus roughness, gas color, and emission. Separable binomial filters smooth these fields before cubic GPU reconstruction and analytic normal calculation: a three-tap filter for dense surfaces and a seven-tap filter for gases/emission, reducing granular flame edges without blurring solid silhouettes. The shader retains continuous procedural detail, liquid highlights, depth shading, gas opacity and glowing mineral crust. The simulation lattice is not drawn as individual squares.

`lib/alchemy_benchmark.dart` first exports frozen device GPU renders, then opens a workload seeded with 30,732 occupied cells, adding sediment, fire and stirring over 32 simulated seconds. `lib/alchemy_render_probe.dart` can export the same frozen scenes independently. These entry points temporarily replace the normal launcher; always restore `lib/main.dart` with an update install afterward.

Local validation: 16 alchemy tests passed. New coverage includes a fully occupied 36,660-cell vessel, all 41 recipes in both ingredient orders, conservation with more than 25,000 moving water cells, gas ascent, fixed solids, stirring, erase and opaque atlas encoding. Picker/controls checks additionally passed at all four tested screen sizes with all 17 elements available. Targeted analysis reports no issues, and the normal release APK builds successfully.

Wireless debugging interrupted the first phone run. After reconnection, the final shader exported water/fire and dense mixed-material scenes on the Samsung Impeller/Vulkan backend. Both actual device renders were retrieved and inspected: the previous rectangular detail seams were not visible in these scenes. The denser gas filter removes the fine cellular fringe seen in the first rebuild captures. This is a frozen-scene visual check, not a guarantee for every arrangement. Do not use historical particle-engine benchmarks as results for this rebuild.

The final live timing session also disconnected before a completed `ALCHEMY_BENCHMARK` record. Recovered Flutter/AndroidRuntime logs contained the completed render exports and no completed timing record. Sustained device performance remains unverified; no new FPS or frame-time guarantee is made. The final local suite passes all 16 tests and targeted analysis is clean.

The normal `lib/main.dart` release was restored on the connected Samsung with `adb install -r` (Success), preserving app data. The chamber remains accessible through Profile → General Settings → ALCHEMY CHAMBER.
