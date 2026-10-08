#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind plan_system_singularity.md (docs/plans/done/): Microsoft
# Research's Singularity as its Research Development Kit 2.0 gives it
# (a mirror of the kit; under Microsoft's research licence, for
# non-commercial academic use: read here, nothing of it copied in ix),
# its parts and their lines, its ABI, its contracts, its documents; and
# what of ix a mini-singularity would stand on.
# usage: kernels/singularity/survey.sh [dir]
#   dir: where the kit is kept (cloned there when missing, 930 MB;
#   default: $TMPDIR/singularity-rdk)

cd "$(dirname "$0")"
S=${1:-${TMPDIR:-/tmp}/singularity-rdk}
[ -d "$S/base" ] || GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 https://github.com/lastweek/source-singularity.git "$S" || exit 1
B=$S/base
lines() { find "$@" -type f \( -name '*.cs' -o -name '*.sg' -o -name '*.cpp' -o -name '*.c' -o -name '*.h' -o -name '*.asm' -o -name '*.inc' \) -print0 | xargs -0 cat | wc -l; }
row() { for d in "$@"; do printf "%8d %s\n" $(lines "$B/$d") "$d"; done; }

echo "== the kit (lines of C#, Sing#, C++, assembly)"
row Kernel Kernel/Singularity Kernel/Native Kernel/System Libraries Contracts boot
echo "== the kernel's own (Kernel/Singularity)"
row Kernel/Singularity/Channels Kernel/Singularity/Memory Kernel/Singularity/Scheduling Kernel/Singularity/Loader Kernel/Singularity/Io Kernel/Singularity/V1 Kernel/Singularity/Isal
echo "== what runs as processes"
row Services/Fat Services/NetStack Services/RamDisk Services/ServiceManager Services/Iso9660 Services/Smb Drivers/Disk Drivers/LegacyKeyboard Drivers/Vesa Drivers/Network Applications/Shell
echo "  applications: $(ls $B/Applications | wc -l) directories"
echo "== the ABI (Singularity.V1.ABI.Txt: its groups, the functions in each)"
grep '\[[0-9]*\]' $B/Singularity.V1.ABI.Txt | sed 's/^/  /'
echo "  $(grep -o '\[[0-9]*\]' $B/Singularity.V1.ABI.Txt | tr -d '[]' | paste -sd+ | bc) functions"
echo "== the contracts (Contracts/, and those beside their programs)"
echo "  in Contracts/: $(grep -rhE '^\s*(public |internal )?contract [A-Za-z]+' $B/Contracts --include=*.sg | wc -l) contracts, $(grep -rhE '^\s*(in|out) +message ' $B/Contracts --include=*.sg | wc -l) messages, $(grep -rhE '^\s*(override )?state [A-Za-z]+' $B/Contracts --include=*.sg | wc -l) states"
echo "  in the kit: $(grep -rhE '^\s*(public |internal )?contract [A-Za-z]+' $B --include=*.sg | wc -l) contracts"
echo "  the smallest (PingPong.Contracts/PongContract.sg):"
grep -E 'contract|message|state' $B/Contracts/PingPong.Contracts/PongContract.sg | sed 's/^ */    /'
echo "== a driver's resources (Drivers/LegacyKeyboard): what its manifest asks"
grep -hoE '\[(IoPortRange|IoIrqRange|IoMemoryRange|ExtensionEndpoint|ServiceEndpoint)[^]]*\]' $B/Drivers/LegacyKeyboard/*.sg | grep -v '^\[IoIrqRange(0' | sed 's/^/  /'
echo "== the documents"
echo "  $(ls "$S/docs/Design Notes" | wc -l) design notes, $(ls "$S/docs/Papers" | wc -l) papers, $(ls "$S/docs/Technical Reports" | wc -l) technical reports"
echo "== ix: what a mini-singularity would stand on"
T=../..
echo "  the runtime's heap: $(grep -c '^static value \(space0\|space1\|vstack\)' $T/languages/ml/runtime/runtime.c) static arrays in runtime.c (a program's own, in its image)"
echo "  mini-ld: -T address (CLI.ml: $(grep -c -- '-H0 -T address' $T/linker/CLI.ml) lines say it); relocations: '$(grep -o 'no relocations in the objects or here' $T/linker/Link.mli)'"
echo "  externals in lib_core (what a process's code may not write, but its library has): $(grep -rh '^external' $T/lib_core --include=*.ml | wc -l)"
echo "  mini-ml's flags about safety: $(grep -o '"-[a-z-]*safe[a-z-]*"' $T/languages/ml/CLI.ml | tr '\n' ' ')"
wl() { find "$@" -name '*.ml' -o -name '*.mli' | grep -v '/tests/\|/build/' | xargs cat | wc -l; }
printf "%8d %s\n" $(wl $T/lib_core/concurrency) "lib_core/concurrency (Thread, Event, Mutex, Condition, Source)" \
  $(wl ../9pi/processes) "kernels/9pi/processes" $(wl ../xv6) "kernels/xv6" $(wl ../lib_machine) "kernels/lib_machine" \
  $(wl ../9pi/filesystems/user) "mini-dossrv" $(wl $T/lib_9p) "lib_9p" $(wl $T/shell) "shell (mini-rc)"
