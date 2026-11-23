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
#  1. the top mkfile on the card, mk -k in /src at the console, each
#     directory's mk timed (BUILD/console.txt, the card's /tmp/self.log
#     as BUILD/card.log, with the top mk's profile, -p), what the
#     kernel waited on and what held its lock (/dev/waits and
#     /dev/lockstat, at the console), then tests/self/'s two programs
#     run;
#  2. the card's /src copied out by Xv6test: its sources to BUILD/src,
#     what the build made to BUILD/card-mk;
#  3. the same mkfile on Linux in BUILD/src, for the card's machine
#     and system: mini-mk -k MINI=mini- O=5 OS=plan9 (BUILD/linux.log);
#  4. each file of the two _mk compared: the same, but the libraries'
#     dirs (their tree's path), the .depend files with that path as
#     the card's.
# -q: the mkfile's self-quick, minutes, not hours (the whole build: 3
# hours under QEMU, 2 minutes on Linux). -k: a directory that fails
# does not stop the others, but those that need it. The status: 0 when no directory failed
# and every file is Linux's.
set -u
q=; timeout=40000
[ "$1" = -q ] && { q=self-quick; timeout=3000; shift; }
card=$1 build=$2; shift 3
ix=$(cd "$(dirname "$0")/../../.." && pwd)
xv6=$ix/_build/default/kernels/9pi/filesystems/lib_xv6fs/tests/Xv6test.exe
# (absolute: the Linux build runs in BUILD/src)
build=$(mkdir -p "$build" && cd "$build" && pwd)
cp "$card" "$build/card.img"

# 1. the build on the card
# (the card's ml with MLOPT as mkconfig's, -O3 unless set: its objects
# Linux's. Each command timed only with SELF_TIMES=1: each time is a
# process more for each of the build's 1,300 commands, part of mk's
# 0.24 s a command on the card (mkconfig's TIMES); each directory's
# mk is timed either way, MK=time mk for the top mkfile alone, and
# kept in BUILD/times.txt)
t=; [ -n "${SELF_TIMES:-}" ] && t="'TIMES=time'"
o=; [ -n "${MLOPT:-}" ] && o="'MLOPT=$MLOPT'"
cat > "$build/session.cmds" <<EOF
cd /src
mk -k -p 'MK=time mk' $t $o $q > /tmp/self.log >[2=1]
grep '^mk: cd ' /tmp/self.log
cat /dev/waits /dev/lockstat
du -s /src/_mk
cat /dev/osversion
/src/_mk/5-plan9/kernels/9pi/tests/self/hello-c
/src/_mk/5-plan9/kernels/9pi/tests/self/hello-ml
EOF
echo "self: the build on the card, under QEMU (BUILD/console.txt; $(date +%H:%M))"
start=$(date +%s)
"$ix/kernels/lib_machine/session.py" --prompt "% " --timeout $timeout \
  --out "$build/console.txt" --lines "$build/session.cmds" -- \
  "$@" -drive file="$build/card.img",if=sd,format=raw > /dev/null 2>&1
echo "self: $(( ($(date +%s) - start) / 60 )) minutes on the card"

# 2. the card's file system, its second partition, read on the host:
# its first sector from the MBR, the second entry's (at 446 + 16) start,
# a little-endian word at its byte 8 (old: sfdisk -d, util-linux's,
# which macOS has not: an empty skip, and every check below passed on
# nothing)
part=$(od -An -t u4 -j 470 -N 4 "$build/card.img" | tr -d ' ')
[ -n "$part" ] && [ "$part" -gt 0 ] || { echo "FAIL self: no second partition in $build/card.img"; exit 1; }
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
(cd "$build/src" && PATH=$ix/bin:$PATH NPROC=4 \
  mini-mk -k MINI=mini- O=5 OS=plan9 ${MLOPT:+"MLOPT=$MLOPT"} $q > "$build/linux.log" 2>&1)

# 4. the two compared
status=0
# (tests/self/'s programs, run on the card after the build)
for l in "hello from C" "hello from OCaml"; do
  if grep -q "^$l" "$build/console.txt"; then echo "ok self: on the card: $l"
  else echo "FAIL self: on the card, no \"$l\" (BUILD/console.txt)"; status=1; fi
done
for l in card linux; do
  # (the top mkfile's recipe for a directory, as mk says it before it
  # runs it, and mk's word when it failed: mk: cd DIR && ... : exit status)
  # (anywhere in a line, each directory once: four jobs write the log,
  # and a recipe was once said after another's line not yet ended,
  # languages/smalltalk counted out of 86)
  n=$(grep -a -o -E 'cd [^ ]+ && (time )?(mini-)?mk ' "$build/$l.log" | sort -u | wc -l | tr -d ' ')
  f=$(sed -n 's/^mk: cd \([^ ]*\) && .*/\1/p' "$build/$l.log" | tr '\n' ' ')
  if [ -z "$f" ]; then echo "ok self: $n directories built on $l"
  else echo "FAIL self: on $l, of $n directories: $f"; status=1
    # (each failed one's lines but its recipes, what the programs and mk
    # said (a killed program's "ml 12: suicide", mk's "exit status"), at
    # most 40, and its last 5 lines: on GitHub, BUILD is in the image.
    # old: its last 10 lines, mk's stops, the error above them; then the
    # lines of words like "error", which missed doom's and quake's and
    # kept the links' -start ... Stack ...; then recipes as lines
    # starting with ml or mk, which hid "ml 12:" and "mk:")
    # (Linux builds four directories at once, so a failed one's lines
    # there are among the others')
    awk '/^cd [^ ]+ && (time )?(mini-)?mk /{n=0; e=0} {s[n++%5]=$0}
      !/^((time )?(mini-)?(ml|ld|cc|asm|ar|mk) [^0-9]|mkdir|cp|mv|rm|touch|for\(|f=|b=|a=|if\(|echo|cd |[0-9.]+u |[ \t]*#)/ &&
        e < 40 {err[e++]=substr($0, 1, 200)}
      /^mk: cd /{print "  " $3 ":"; for(i=0;i<e;i++) print "    " err[i]
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
  # (a .depend names other libraries' summaries by the tree's path:
  # /src on the card, BUILD/src here)
  elif [[ $f == */.depend* ]] &&
    cmp -s "$build/card-mk/$f" <(sed "s|$build/src/|/src/|g" "$build/src/_mk/$f"); then
    same=$((same + 1))
  else case $f in */dirs) ;; *) echo "differ: $f" >> "$build/differ.txt" ;; esac; fi
done < <(comm -12 "$build/linux.files" "$build/card.files")
if [ -s "$build/differ.txt" ]; then
  echo "FAIL self: $(wc -l < "$build/differ.txt") files not Linux's (BUILD/differ.txt):"
  head -20 "$build/differ.txt"; status=1
else echo "ok self: the $same files made on the card are Linux's, byte for byte (but the libraries' dirs)"; fi
# each directory's time on the card, mk's line (BUILD/times.txt)
awk '/^cd [^ ]+ && time mk /{d=$2} /r \t mk /{for(i=1;i<=NF;i++) if($i ~ /r$/){sub(/r$/,"",$i); t[d]+=$i; break}}
  END{for(k in t) printf "%-40s %6.0f\n", k, t[k]}' "$build/card.log" | sort > "$build/times.txt"
# (and which kernel it was: its stamp, the checksum of its objects, so
# that two runs compared are seen to be two kernels, or the same one)
stamp=$(grep -a -A1 '^% cat /dev/osversion' "$build/console.txt" | tail -1 | tr -d '\r')
echo "self: $(awk '{s+=$2} END{printf "%d", s}' "$build/times.txt") s of mk on the card (BUILD/times.txt), kernel $stamp"
# The kernel's lock, the bound of the four cores (plan_9pi_self_speed.md,
# 2026-11-23, a number to bring down): how long it was held during the
# build, of the top mk's time (mk -p's first line), and how long each
# core waited for it; then what held it most (/dev/lockstat's accounts,
# a name, times, ms; its "in" lines are parts of those, and "in
# unlocked" ones their time out of the lock, not held)
tr -d '\r' < "$build/console.txt" | sed -n '/^% cat \/dev\/waits/,/^% /p' > "$build/lock.txt"
mk_s=$(grep -a -m1 '^mk: [0-9.]* s:' "$build/card.log" | awk '{print $2}')
awk -v mk="${mk_s:-0}" '
  /^lock / { for (i = 2; i <= NF; i++) w += $i; nc = NF - 1 }
  /^in unlocked / { held -= $NF }
  /^[^%]/ && !/^(in|lock|ready|page) / && $NF ~ /^[0-9]+$/ && $(NF-1) ~ /^[0-9]+$/ { held += $NF }
  END { if (nc) printf "self: the kernel'"'"'s lock held %d s of mk'"'"'s %d (%d%%), each core waited %d s for it (BUILD/lock.txt)\n",
          held / 1000, mk, (mk > 0 ? held / 10 / mk : 0), w / 1000 / nc }' "$build/lock.txt"
awk '/^[^%]/ && !/^(in|lock|ready|page) / && $NF ~ /^[0-9]+$/ && $(NF-1) ~ /^[0-9]+$/ {
       ms = $NF; $(NF-1) = ""; $NF = ""; sub(/ +$/, ""); printf "%d %s\n", ms, $0 }' "$build/lock.txt" \
  | sort -rn | head -6 | awk '{ms = $1; $1 = ""; l = l sprintf("%s%s %d s", sep, substr($0, 2), ms / 1000); sep = ", "} END { if (l != "") print "self: what held it most: " l }'
exit $status
