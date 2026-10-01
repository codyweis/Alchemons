# Materia

Standalone browser alchemy prototype. From the repository root, run:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Open http://127.0.0.1:8765/docs/prototypes/alchemy/.

Choose one of 17 materials and drag in the chamber. Pour, stir, or erase; Shift temporarily stirs. Space pauses; brackets change the brush radius. Feed toggles the active experiment's sources; Clear empties the chamber and disables its feed. Reset restores the chosen experiment. Sound is opt-in.

The canonical `assets/data/alchemons_element_recipes.json` is loaded at runtime. Each pair always produces its main (highest-weight) product; the numerical probabilities are not used for randomness. Names are normalized case-insensitively and ingredient order is irrelevant. Each contact consumes two cells and produces one product cell. Other contacts use density and phase movement. Gases drift upward and dissipate; solids remain where placed or formed. These are prototype behaviors, not changes to game rules.

Three supplied experiments demonstrate steam, mineral reaction chains, and Blood. Rendering uses Canvas 2D with light diffusion and gas filaments. There are no build dependencies. Optional Google Fonts have system fallbacks.

Run the focused simulation checks:

```sh
node docs/prototypes/alchemy/verify.cjs
```

The prototype is isolated from the Flutter game and does not modify its recipes or survival/cosmic code.
