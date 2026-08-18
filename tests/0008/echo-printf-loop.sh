#!/usr/bin/env bash
# Comparison sample: for-loop with echo and printf
# shave/shave writes echo-printf-loop.c and echo-printf-loop beside this script

for i in 1 2 3 4 5; do
    echo "echo line $i"
    printf "printf line %s\n" "$i"
done
