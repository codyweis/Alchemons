#!/bin/zsh
# exp.sh <tag> <KNOBS> <FAMS> <ELEMS> [SECONDS=45] [SCENS=horde,siege,shooters] [SEEDS=4242,7,19,31] [BANDS=all] [EXTRA_ENV...]
S=/private/tmp/claude-501/-Users-codyweisenberger-Documents-repos-Alchemons/32dc18e4-c7f3-4a9f-a325-bcd6409073b1/scratchpad
TAG=$1; KN=$2; FA=$3; EL=$4; SEC=${5:-45}; SC=${6:-horde,siege,shooters}; SE=${7:-4242,7,19,31}; BA=${8:-P50,P70,P90,P100E10}
shift 8 2>/dev/null
mkdir -p $S/fb/x/$TAG
O=$S/fb/x/$TAG/run.jsonl
: > $O
cd $S/fb/exp && env KNOBS="$KN" FAMS=$FA ELEMS=$EL SECONDS=$SEC SCENS=$SC SEEDS=$SE BANDS=$BA MODE=both "$@" OUT=$O flutter test test/ability_scaling_report_test.dart --tags preview --plain-name measure > $S/fb/x/$TAG/run.log 2>&1
echo "$TAG done: $(grep -c '^SCALE' $S/fb/x/$TAG/run.log) rows; $(tail -1 $S/fb/x/$TAG/run.log)"
