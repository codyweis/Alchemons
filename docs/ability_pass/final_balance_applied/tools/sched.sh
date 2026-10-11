#!/bin/zsh
# Runs fb/queue/*.job (zsh scripts) while fewer than MAX harness runs are live
# (counted as running fb/tools/run.sh|exp.sh processes), GAP s between starts.
Q=/private/tmp/claude-501/-Users-codyweisenberger-Documents-repos-Alchemons/32dc18e4-c7f3-4a9f-a325-bcd6409073b1/scratchpad/fb/queue
MAX=${MAX:-4}; GAP=${GAP:-20}
last=0
while [ ! -f $Q/STOP ]; do
  live=$(pgrep -f "fb/tools/(run|exp)\.sh" | wc -l | tr -d ' ')
  now=$(date +%s)
  if [ ! -f $Q/PAUSE ] && [ $live -lt $MAX ] && [ $((now - last)) -ge $GAP ]; then
    next=$(ls $Q/*.job 2>/dev/null | sort | head -1)
    if [ -n "$next" ]; then
      b=$(basename $next); mv $next $Q/running/$b
      (zsh $Q/running/$b > $Q/running/$b.out 2>&1; mv $Q/running/$b $Q/done/; echo "$(date +%H:%M:%S) finished $b" >> $Q/sched.log) &
      last=$now; echo "$(date +%H:%M:%S) started $b (live was $live)" >> $Q/sched.log
      sleep 5
    fi
  fi
  sleep 3
done
