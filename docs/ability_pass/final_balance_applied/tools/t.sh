#!/bin/zsh
typeset -A pids
b=x.job
sleep 5 > /dev/null 2>&1 &
p=$!; pids[$b]=$p
echo "pid=${pids[$b]} keys=${(k)pids}"
for j in ${(k)pids}; do kill -0 ${pids[$j]} && echo alive || echo dead; done
