#!/usr/bin/env bash
# Comparison sample: GNU wc usage
# shave/shave writes wc.c and wc beside this script

wc data/a.txt
wc -l data/a.txt
wc -c data/a.txt
wc -w data/a.txt
wc -m data/a.txt
wc -L data/tab.txt
wc -lw data/a.txt
wc -clw data/a.txt
wc --lines --words --bytes data/a.txt
wc data/a.txt data/b.txt
wc -l data/a.txt data/b.txt
wc data/empty.txt
wc data/nonew.txt
wc data/a.txt data/b.txt data/empty.txt data/nonew.txt
wc --total=never data/a.txt data/b.txt
wc --total=only data/a.txt data/b.txt
wc --total=always data/a.txt
wc -- data/a.txt
wc -lwL data/a.txt
