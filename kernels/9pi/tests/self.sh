#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The Makefile's self and self-quick: ix built by ix on mini-9pi, and
# the files it makes against Linux's (plan_self_hosting.md, stage 3).
#   self.sh [-q] CARD BUILD -- EMULATOR...
# CARD: make card-self's image (the repository in /src), copied to
# BUILD, where the build writes (the checks' cards are snapshots);
# EMULATOR: the Pi 2's, with its four cores. Then:
#  1. tests/self.rc on the card, at the console, each compile and link
#     timed (BUILD/console.txt, the card's /tmp/self.log as BUILD/card.log),
#     then tests/self/'s two programs run;
#  2. the card's /src copied out by Xv6test: its sources to BUILD/src,
#     what the build made to BUILD/card-mk;
#  3. tests/self.rc on Linux in BUILD/src, the tools under the card's
#     names (BUILD/bin: ml is mini-ml...), objtype=arm as on the card
#     (BUILD/linux.log);
#  4. each file of the two _mk compared: the same, but the libraries'
#     dirs (their tree's path).
# -q: self.rc -q, minutes, not hours (the whole build: 3 hours under
# QEMU, 2 minutes on Linux). The status: 0 when no directory failed
# and every file is Linux's.
set -u
q=; timeout=40000
[ "$1" = -q ] && { q=-q; timeout=3000; shift; }
card=$1 build=$2; shift 3
ix=$(cd "$(dirname "$0")/../../.." && pwd)
xv6=$ix/_build/default/kernels/9pi/filesystems/lib_xv6fs/tests/Xv6test.exe
# (absolute: the Linux build runs in BUILD/src)
build=$(mkdir -p "$build" && cd "$build" && pwd)
cp "$card" "$build/card.img"

# 1. the build on the card
# (the card's ml with MLOPT as mkconfig's, -O3 unless set: its objects
# Linux's)
cat > "$build/session.cmds" <<EOF
cd /src
T=('ML=time ml -m 5 ${MLOPT:--O3}' 'LD=time ld -m 5 -map' 'CC=time cc -m 5' 'AS=time asm -m 5' 'AR=time ar')
rc kernels/9pi/tests/self.rc $q \$T > /tmp/self.log >[2=1]
grep FAILED /tmp/self.log
du -s /src/_mk
/src/_mk/5-plan9/kernels/9pi/tests/self/hello-c
/src/_mk/5-plan9/kernels/9pi/tests/self/hello-ml
EOF
echo "self: the build on the card, under QEMU (BUILD/console.txt; $(date +%H:%M))"
start=$(date +%s)
"$ix/kernels/lib_machine/session.py" --prompt "% " --timeout $timeout \
  --out "$build/console.txt" --lines "$build/session.cmds" -- \
  "$@" -drive file="$build/card.img",if=sd,format=raw > /dev/null 2>&1
echo "self: $(( ($(date +%s) - start) / 60 )) minutes on the card"

# 2. the card's file system, its second partition, read on Linux
part=$(/usr/sbin/sfdisk -d "$build/card.img" | sed -n 's/.*img2 : start= *\([0-9]*\),.*/\1/p')
dd if="$build/card.img" of="$build/fs.img" bs=512 skip="$part" status=none
"$xv6" "$build/fs.img" cat /tmp/self.log > "$build/card.log"
# (copy DIR TO SKIP: the card's DIR into TO, but its entry SKIP)
copy() {
  mkdir -p "$2"
  "$xv6" "$build/fs.img" ls "$1" | while read -r n _; do
    case $n in
      ./|../|"$3") ;;
      */) copy "$1/${n%/}" "$2/${n%/}" "" ;;
      *) "$xv6" "$build/fs.img" cat "$1/$n" > "$2/$n" ;;
    esac
  done
}
rm -rf "${build:?}/src" "${build:?}/card-mk"
copy /src "$build/src" _mk/
copy /src/_mk "$build/card-mk" ""
rm -f "$build/fs.img"

# 3. the same build on Linux
mkdir -p "$build/bin"
for t in ml cc asm ar ld lex yacc walk rc mk; do
  ln -sf "$ix/bin/mini-$t" "$build/bin/$t"
done
(cd "$build/src" && PATH=$build/bin:$ix/bin:$PATH MKSHELL=mini-rc objtype=arm NPROC=4 \
  mini-rc kernels/9pi/tests/self.rc $q > "$build/linux.log" 2>&1)

# 4. the two compared
status=0
# (tests/self/'s programs, run on the card after the build)
for l in "hello from C" "hello from OCaml"; do
  if grep -q "^$l" "$build/console.txt"; then echo "ok self: on the card: $l"
  else echo "FAIL self: on the card, no \"$l\" (BUILD/console.txt)"; status=1; fi
done
for l in card linux; do
  n=$(grep -c '^=== ' "$build/$l.log")
  f=$(grep '^FAILED ' "$build/$l.log" | sed 's/^FAILED //' | tr '\n' ' ')
  if [ -z "$f" ]; then echo "ok self: $n directories built on $l"
  else echo "FAIL self: on $l, of $n directories: $f"; status=1
    # (each failed one's lines that are not mk's recipes, what the
    # programs said, at most 40, and its last 5 lines: on GitHub, BUILD
    # is in the image. old: its last 10 lines, mk's stops, the error
    # above them; then the lines of words like "error", which missed
    # doom's and quake's and kept the links' -start ... Stack ...)
    awk '/^=== /{n=0; e=0} {s[n++%5]=$0}
      !/^(ml|ld|cc|asm|ar|mk|mkdir|cp|mv|rm|touch|for\(|f=|b=|a=|if\(|echo|=== |[0-9.]+u )/ &&
        e < 40 {err[e++]=substr($0, 1, 200)}
      /^FAILED /{print "  " $2 ":"; for(i=0;i<e;i++) print "    " err[i]
        print "    ..."; for(i=n-5;i<n;i++) if(i>=0) print "    " substr(s[i%5], 1, 200)}' \
      "$build/$l.log"
  fi
done
(cd "$build/card-mk" && find . -type f | sort) > "$build/card.files"
(cd "$build/src/_mk" && find . -type f | sort) > "$build/linux.files"
comm -3 "$build/linux.files" "$build/card.files" | sed 's/^\t/card only: /; /^card only/!s/^/linux only: /' > "$build/differ.txt"
same=0
while read -r f; do
  if cmp -s "$build/card-mk/$f" "$build/src/_mk/$f"; then same=$((same + 1))
  else case $f in */dirs) ;; *) echo "differ: $f" >> "$build/differ.txt" ;; esac; fi
done < <(comm -12 "$build/linux.files" "$build/card.files")
if [ -s "$build/differ.txt" ]; then
  echo "FAIL self: $(wc -l < "$build/differ.txt") files not Linux's (BUILD/differ.txt):"
  head -20 "$build/differ.txt"; status=1
else echo "ok self: the $same files made on the card are Linux's, byte for byte (but the libraries' dirs)"; fi
# each directory's time on the card, mk's line (BUILD/times.txt)
awk '/^=== /{d=$2} /r \t mk /{for(i=1;i<=NF;i++) if($i ~ /r$/){sub(/r$/,"",$i); t[d]+=$i; break}}
  END{for(k in t) printf "%-40s %6.0f\n", k, t[k]}' "$build/card.log" | sort > "$build/times.txt"
echo "self: $(awk '{s+=$2} END{printf "%d", s}' "$build/times.txt") s of mk on the card (BUILD/times.txt)"
exit $status
