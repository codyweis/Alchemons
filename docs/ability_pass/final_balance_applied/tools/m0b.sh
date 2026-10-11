#!/bin/zsh
S=/private/tmp/claude-501/-Users-codyweisenberger-Documents-repos-Alchemons/32dc18e4-c7f3-4a9f-a325-bcd6409073b1/scratchpad
($S/fb/tools/run.sh $S/fb/base $S/fb/m0/main/control.jsonl CONTROL=1 SEEDS=4242,7,19,31 SECONDS=45 SCENS=horde,siege,shooters; $S/fb/tools/run.sh $S/fb/base $S/fb/m0/boss/a.jsonl FAMS=horn,wing,let,pip SCENS=boss BOSS_HOLD=1 MODE=both SEEDS=4242,7,19,31 SECONDS=45) &
sleep 25
$S/fb/tools/run.sh $S/fb/base $S/fb/m0/boss/b.jsonl FAMS=mane,mask,kin,mystic SCENS=boss BOSS_HOLD=1 MODE=both SEEDS=4242,7,19,31 SECONDS=45 &
wait
