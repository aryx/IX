#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_kernel_swap.md: Plan 9's pager
# (principia's kernel/memory), counted, and what uses it; mini-9pi's
# memory code, counted; the pages it gives processes; the card's
# partitions; what a program of mini-ml's holds for what it keeps.
# usage: scripts/stats/swap_survey.sh [principia]
cd "$(dirname "$0")/../.."
S=${1:-$HOME/github/principia-softwarica}
M=$S/kernel/memory
echo "== Plan 9's memory (principia's kernel/memory), lines"
wc -l $M/swap.c $M/page.c $M/fault.c $M/segment.c | sed "s|$S/||; s/^/  /"
echo "== swap.c's functions"
grep -o '^[a-z][a-z]*(' $M/swap.c | tr -d '(' | tr '\n' ' ' | sed 's/^/  /'; echo
echo "== the lines outside swap.c that name its functions or a page that is out"
grep -c 'kickpager\|putswap\|dupswap\|pagedout\|onswap\|swapalloc\|setswapchan\|swapcount' $M/page.c $M/fault.c $M/segment.c $S/kernel/console/devcons.c $S/kernel/init/arm/main.c | sed "s|$S/||; s/^/  /"
echo "== mini-9pi's, lines"
wc -l kernels/9pi/memory/Fault.ml kernels/lib_machine/Mmu.ml | sed 's/^/  /'
echo "== the pages it gives processes (Arch.pages), each board"
grep -n '^let pages' kernels/lib_machine/pi1/Arch.ml kernels/lib_machine/pi4/Arch.ml | sed 's/^/  /'
echo "== where a page is asked for, and what a refusal does"
grep -n 'kalloc ()\|Mmu.create ()' kernels/9pi/memory/*.ml kernels/9pi/processes/*.ml | sed 's/^/  /' | cut -c1-150
echo "== the card (kernels/9pi/Makefile; kernels/tools/Mkcard.ml: the MBR's entries used)"
grep -n '^CARD_MB\|^CARD_FS_MB' kernels/9pi/Makefile | sed 's/^/  /'
grep -c 'partition mbr [0-9]' kernels/tools/Mkcard.ml | sed 's/^/  partitions written: /'
echo "== a program of mini-ml's: its heap's halves (languages/ml/runtime/gc.c)"
grep -n 'define MAXHEAP\|define HEAPSTART' languages/ml/runtime/gc.c | sed 's/^/  /'
