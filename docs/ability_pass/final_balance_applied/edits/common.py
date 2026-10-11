# Shared helpers for edit modules.
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = json.load(open(os.path.join(HERE, 'final_values.json')))

def K(mode, name, default):
    """A tunable number: knob() in the experiment tree, the chosen literal in main."""
    if mode == 'exp':
        return f"knob('{name}', {default})"
    v = FINAL.get(name, default)
    return repr(float(v)) if isinstance(v, (int, float)) and not isinstance(v, bool) else str(v)
