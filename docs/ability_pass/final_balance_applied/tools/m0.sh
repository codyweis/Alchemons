#!/bin/zsh
S=/private/tmp/claude-501/-Users-codyweisenberger-Documents-repos-Alchemons/32dc18e4-c7f3-4a9f-a325-bcd6409073b1/scratchpad
$S/fb/tools/run.sh $S/fb/base $S/fb/m0/main/horn,wing.jsonl FAMS=horn,wing MODE=both SEEDS=4242,7,19,31 SECONDS=45 SCENS=horde,siege,shooters &
sleep 25
$S/fb/tools/run.sh $S/fb/base $S/fb/m0/main/let,pip.jsonl FAMS=let,pip MODE=both SEEDS=4242,7,19,31 SECONDS=45 SCENS=horde,siege,shooters &
sleep 25
$S/fb/tools/run.sh $S/fb/base $S/fb/m0/main/mane,mask.jsonl FAMS=mane,mask MODE=both SEEDS=4242,7,19,31 SECONDS=45 SCENS=horde,siege,shooters &
sleep 25
$S/fb/tools/run.sh $S/fb/base $S/fb/m0/main/kin,mystic.jsonl FAMS=kin,mystic MODE=both SEEDS=4242,7,19,31 SECONDS=45 SCENS=horde,siege,shooters &
wait
