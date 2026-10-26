#!/usr/bin/env python3
"""Export Gnuplot data from median_cycles.txt, excluding interpolated values."""
from pathlib import Path
import re
import argparse
p=argparse.ArgumentParser()
p.add_argument('input',nargs='?',default='median_cycles_4iter_1cycle.txt')
a=p.parse_args()
root=Path(__file__).resolve().parent
source=Path(a.input)
groups={};b=k=None
for line in source.read_text(encoding='utf-8').splitlines():
 line=line.strip()
 if line in ('imatmul','iconv2d-output','iconv2d-ifmap'):
  b=line;groups.setdefault(b,{})
 elif m:=re.fullmatch(r'S=(\d+)',line):
  k=(int(m[1]),);groups[b].setdefault(k,{})
 elif m:=re.fullmatch(r'F=(\d+), (?:OUTPUT|IFMAP)=(\d+)',line):
  k=(int(m[1]),int(m[2]));groups[b].setdefault(k,{})
 elif m:=re.match(r'(DELAY=\d+|LDPC):\s*([\d.]+) cycles',line):
  if 'interpol' in line.lower() or 'extrapol' in line.lower():continue
  conf='LDPC' if m[1]=='LDPC' else int(m[1].split('=')[1])
  groups[b][k][conf]=float(m[2])
selected={'imatmul':[(8,),(16,),(32,),(64,),(128,)],'iconv2d-output':[(3,64),(5,128),(5,256),(7,128)],'iconv2d-ifmap':[(3,64),(5,128),(5,256),(7,128)]}
for b,d in groups.items():
 with (root/f'{b}_delay.dat').open('w') as out:
  out.write('# Columns: DELAY '+str(selected[b])+'\n')
  for delay in (0,1,2,3,4,6,8):
   row=[str(delay)]
   for k in selected[b]:
    vals=d.get(k,{});base=vals.get(0)
    row.append(f'{100*(vals[delay]/base-1):.10g}' if base and delay in vals else 'NaN')
   out.write(' '.join(row)+'\n')
 with (root/f'{b}_ldpc.dat').open('w') as out:
  out.write('# index increase_percent label\n');index=0
  for k in sorted(d):
   vals=d[k]
   if not vals.get(0) or 'LDPC' not in vals:continue
   label=str(k[0]) if b=='imatmul' else f'({k[0]}, {k[1]})'
   out.write(f'{index} {100*(vals["LDPC"]/vals[0]-1):.10g} "{label}"\n');index+=1
print('Data files written in',root)
