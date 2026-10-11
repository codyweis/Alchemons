import sys
sys.path.insert(0, '/private/tmp/claude-501/-Users-codyweisenberger-Documents-repos-Alchemons/32dc18e4-c7f3-4a9f-a325-bcd6409073b1/scratchpad/fb/tools')
import ana, statistics as st
base=ana.load_dir(sys.argv[1]); res,med,_=ana.summarise(base)
ab=sys.argv[2]
for t in sys.argv[3:]:
    rows=ana.load_dir(t); c=ana.cells(rows); out=[]; thirds=[]
    for b in ana.BANDS:
        v=[]; th=[0,0,0]
        for s in ana.NONBOSS:
            k=(ab,b,s)
            if k not in c: continue
            secs=c[k][0][0][0]['seconds']
            v.append(ana.added(c[k],'damage')/(secs/45)/max(1,med[(b,s)]))
            t3=ana.thirds(c[k]); th=[th[i]+t3[i] for i in range(3)]
        out.append(st.mean(v) if v else float('nan')); tot=sum(th) or 1
        thirds.append('/'.join(f'{x/tot:.2f}' for x in th))
    print(t.split('/')[-1], ' '.join(f'{x:5.2f}' for x in out), ' thirds', thirds)
