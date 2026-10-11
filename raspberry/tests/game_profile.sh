#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Where cameltry's instructions go in play under mini-qemu
# (plan_web.md, 2026-10-11): the game built by ix's tools in a
# directory of its own (D: the tree's _mk and card are not touched),
# put on a card of its own, started on the bare screen with its meter
# (stats=on: the update, the view and the showing of 40 frames), a
# space typed, then the guest's profile of 14 seconds of play by module
# and function (guest_profile.py).
#   usage: game_profile.sh D [name [ips]]
#   FLAGS="'late=1'"  more of the game's flags (one tick a frame: the showing alone)
#   K=kernel.img KS=kernel.syms  another kernel (default: kernel-pi1-web.img, nm of its ELF)
# Needs: bin/ (make ix), _mk/5-plan9 (the card's other programs), dune
# build ./raspberry/tests/Boot_bench.exe ./kernels/tools, the web kernel
# (make -C kernels/9pi ix-web), an arm nm for KS. Minutes.
R=$(cd "$(dirname "$0")/../.." && pwd); S=${1:?a directory}; name=${2:-play}; ips=${3:-12}
mkdir -p $S/gb; [ -d $S/gb/lib_core ] || cp -r $R/_mk/5-plan9/lib_core $S/gb/
cd $R/games && PATH=$R/bin:$PATH mini-mk O=5 OS=plan9 CATEGORIES=arcade B=$S/gb > $S/gb.log 2>&1 || { grep -v '^mini-ml\|^mkdir' $S/gb.log | tail -20; exit 1; }
# (the link's command, when the game was linked again: once more with -v, its listing)
L=$(grep 'mini-ld' $S/gb.log | tail -1)
if [ -n "$L" ]; then
  L=$(echo "$L" | sed 's/`echo $stem | tr A-Z a-z`/x.out/; s/-nofollow/-nofollow -v/; s|-o [^ ]*/x.out|-o '$S'/x.out|')
  (cd $R/games/arcade && PATH=$R/bin:$PATH sh -c "$L" > $S/camel.list 2>&1)
  grep 'TEXT ' $S/camel.list | sed 's/^\([0-9a-f]*\): [0-9a-f]*\tTEXT \([^+]*\).*/\1 T \2/' > $S/camel.syms
fi
cd $R/kernels/9pi; I=$R/_mk/5-plan9
make BOARD=pi1 CARD=$S/card.img CARD_FS=$S/fs.img CARD_NS=$S/ns "CARD_games=tetris=$I/games/puzzle/tetris wolfenstein=$I/games/fps/tinywolfenstein tetris-soft=$I/games/puzzle-soft/tetris wolf-soft=$I/games/fps-soft/tinywolfenstein cameltry=$S/gb/games/arcade/tinycameltry camel-soft=$I/games/arcade-soft/tinycameltry" $S/card.img > /dev/null 2>&1
timeout 900 $R/_build/default/raspberry/tests/Boot_bench.exe -ips $ips ${K:-kernel-pi1-web.img} $S/card.img -do "s 12; k +; s 10; prof; s 14; shot $S/$name.ppm" -prof $S/$name.prof -- "cameltry 'stats=on' ${FLAGS} &" 2>&1 | grep -a 'frames in\|showing' | tail -3
python3 $R/raspberry/tests/guest_profile.py $S/camel.syms ${KS:?the kernel's symbols} $S/$name.prof ${N:-40}
