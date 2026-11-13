# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-kernel: TinyKernel.ml, a free kernel in ML for
# tiny-machine (docs/notes/notes_tiny_kernel.md):
#
#   make run          runs the kernel on tiny-machine, with sh on the console
#   make run-window   does the same in a window of the host's, with the
#                     screen, the mouse and the speaker (tiny-windows,
#                     paint, tetris... from sh)
#   make check        checks the following against check.expected, with
#                     the programs' sizes masked (MASK):
#                     - mltests, and a script through sh;
#                     - the utilities through rc (utils: walk, du, cp,
#                       mv, xd, test, ln, grep, sort, ls -l...; pipes of
#                       six stages; ed and sam);
#                     - emacs's ^C, M-x and a macro;
#                     - office's page, a text and a sheet, saved, and a
#                       page not saved, left by File's Quit twice;
#                     - troff's text and web page of /examples/report.ixd;
#                     - trace on cat and on rc's pipeline (-f);
#                     - debug on ping (stopped in write, bt, a step) and
#                       on trace (an ML backtrace, the value stack's
#                       slots), with trace and debug both also attached
#                       to a loop of rc's in the background;
#                     - /examples' hello, built, run, traced and debugged;
#                     - then the network: ping, get, and put, whose file
#                       is kept across two boots, against tiny-machine's
#                       end of the wire, with a packet lost and the file
#                       whole anyway.
#                     Then come the recorded sessions, with the mouse
#                     and the keys read from a file, and the screen at
#                     the halt checked against its sum:
#                     - paint.events (paint on the screen);
#                     - windows.events (windows, tiny-windows: three
#                       windows, ls, paint in one, a move, a delete, one
#                       brought to the front);
#                     - nested.events (tiny-windows in a window of
#                       tiny-windows, with two windows in it);
#                     - play.events (square, a game on
#                       ../TinyLibPlayground.ml, in a window, played
#                       with the arrows);
#                     - tetris.events (tetris in a window: six pieces
#                       moved, turned and dropped), with its sounds, the
#                       speaker's samples as a WAV, checked against
#                       their sum, and play's sounds, with
#                       /examples/korobeiniki.wav played;
#                     - calc.events (calc, on ../TinyLibGUI.ml, in a
#                       window: 12 * 3 = by its buttons, + 6 by the
#                       keys, a press taken back, a button held);
#                     - temp.events (temp in a window, with its two
#                       fields typed in);
#                     - debug.events (debug -window ping in a window: a
#                       breakpoint, c, s, the next and continue buttons,
#                       to its end);
#                     - emacs.events (emacs f in a window: two lines
#                       typed, a word killed and another typed, saved,
#                       quit, then cat f);
#                     - emacsmx.events (emacs f in a window: three lines
#                       typed, a macro recorded and run, then M-x with
#                       Tab's completion for replace-string and
#                       goto-line);
#                     - emacscolors.events (a C file of its own text,
#                       written by echo in the window's rc, then opened,
#                       to see its colors; it is not one of tiny/'s
#                       sources, whose edits would change the screen);
#                     - the office's sessions (office, officesheet,
#                       officedraw, officepaint: a page, a sheet and its
#                       chart, a drawing and a paint, in a window);
#                     - with the network, on ../tests/www's pages, the
#                       browser's sessions (www, wwwlink, wwwback,
#                       wwwgo, wwwpicture, wwwwin, wwwscroll, wwwmenu,
#                       wwwhistory, wwwsearch, wwwplay: the OCaml
#                       article, a link followed and back, a section
#                       gone to, its pictures, in a window, scrolled,
#                       the History menu open, the page before chosen in
#                       it, a search's results (s), a WAV file given to
#                       play, with play's own sound);
#                     - and the disk (KFS.ml): the root, three boots
#                       on a blank one, with the image's repair kit
#                       alone in /boot/bin; files and a directory made
#                       in /usr/glenda, a link, rc copied to /bin and run
#                       from there, ed (of /boot/bin) written over in
#                       /bin (copied to the disk) then removed (so that
#                       /boot/bin's is used again), and the snapshots in
#                       /dump, which are read only.
#                     Each session boots on a copy of the system's disk,
#                     except that last one; the toolchain's session also
#                     has the sources' disk, /src; /examples' programs
#                     are built with /lib alone.
#                     It takes a few minutes.
#   make self         has tiny-kernel build its image from its sources,
#                     /src, on a disk, and checks that the image is the
#                     host's, byte for byte (about 50 minutes)
#   make self-quick   does the same for a few of its targets (3 minutes)
#   MEMORY=segments   runs any of these with the processes in segments,
#                     their text shared (plan_tiny_memory.md; partitions
#                     are the default), with /boot/memory in the image,
#                     under _make-segments;
#   MEMORY=pages      or with the processes in pages, given when touched
#                     and shared after a fork until written, under
#                     _make-pages
#
# ../Buildfile says what is built, and how (t-IX built by tiny-build):
# - the kernel (by the Buildfile here: kentry.s first, the runtime, the
#   kernel's units, the library, kend.s last);
# - then the image, boot.img: the kernel followed by /boot's files, the
#   repair kit (sh, rc, utils, ed), each as a name, a line, its size, a
#   line and its bytes (a hard link is a name and a line "link bin/utils",
#   since utils is cat, ls, wc...), with an empty line at the end;
# - and the system, /bin, /lib and /examples, by build install.
# This Makefile runs that build in a copy of tiny/ (see the build,
# below), and makes two disks: the system's, disk.img, and the
# sources', src.img. Then it runs the machine on them, and its tests.
#
# ../user/ has the programs' main files. In C, each file is a program;
# in ML, each is one line, which runs its module's main with
# TinyLibSystem.main. What a C program is linked with to call this
# kernel (user.h, sys.s, draw.c, net.c) is in ../runtime/c/. For an ML
# program, it is ../runtime/ml/'s mlsys.c and
# ../TinyLibSystem/tinykernel/TinyLibSystem.ml, which sits beside the
# other systems' TinyLibSystem (../TinyLibSystem/README.md).
#
# What is built goes to _make/ and nowhere else, so that this directory
# shows only the sources. _make/ holds:
# - src, the copy that is built in;
# - system, what the copy's build install put there;
# - boot.img and kernel.img, copied out of the copy;
# - disk.img and src.img, the two disks, and their grown copies that
#   the runs and the tests use (run.img, runsrc.img, check/...).
# make clean removes it.
# The tools come from the PATH (after `dune install`), or from ix's bin/.

export PATH := $(abspath ../../bin):$(PATH)

# Each tool is given by its path, the one in ix's bin/ when it is
# there. This is so that what a tool makes is made again when the tool
# changes (the build below starts afresh when a tool's sum changed: a
# new tiny-ml remakes the units, and a new tiny-as remakes the
# objects), and so that make 3.81 (macOS's), which runs a command
# without a shell from the PATH it started with, not the one exported
# above, finds the tool.
tool = $(firstword $(wildcard $(abspath ../../bin)/$(1)) $(1))
TML = $(call tool,tiny-ml)
TC = $(call tool,tiny-cc)
AS = $(call tool,tiny-as)
LD = $(call tool,tiny-ld)
AR = $(call tool,tiny-ar)
MKFS = $(call tool,tiny-mkfs)
MACHINE = $(call tool,tiny-machine)
MKFSBIN = $(wildcard $(MKFS))

# how the kernel gives the processes memory (KMemory.mli)
MEMORY = partitions
O = $(if $(filter segments pages,$(MEMORY)),_make-$(MEMORY),_make)
# the size of /boot/memory, which holds the word and a newline
MEMSIZE = $(if $(filter segments,$(MEMORY)),9,6)
# where make check's check.expected, sessions (.events) and screens'
# sums (.cksum) are
T = ../tests/TinyKernel_tests

# The build is ../Buildfile, t-IX's build by tiny-build, the same one
# that tiny-kernel runs in /src (make self). It runs here in a copy of
# tiny/, _make/src (its outputs go beside its sources, as in /src),
# with the host's tools under tiny-kernel's names in _make/tools (ml,
# cc, as, ld, ar, build, and tiny-shell for rc). The copy is made again
# at each make, and tiny-build makes again what changed (by its
# digests). Before the build, the file that the host alone makes is put
# in the copy: TinyKernel/kfont.s, the font's bytes.
BUILD = $(call tool,tiny-build)
RC = $(call tool,tiny-shell)
S = $(O)/src
# tiny/, without tests/ (it is not the system's) and without what is
# built from it: the build directories and the outputs
COPY = --exclude ./tests --exclude '_make*' --exclude '_mk*' --exclude '*.o' \
  --exclude '*.tmi' --exclude '*.a' --exclude .tiny-build --exclude '*.img' \
  --exclude '*.map'

all: $(O)/boot.img $(O)/disk.img $(O)/src.img

# The font's bytes: k_font() says where they are, and k_font_size() how
# many there are (as ML integers). The font is Plan 9's default font
# (FONT=fonts/grey.font gives Ubuntu Mono, with two bits a pixel; see
# fonts/README.md).
FONT = fonts/plan9.font
$(O)/kfont.s: $(FONT)
	@mkdir -p $(@D)
	printf 'k_font:\n\tla\tr13, font\n\tshli\tr13, r13, 1\n\tori\tr13, r13, 1\n\tret\n' > $@
	printf 'k_font_size:\n\tla\tr13, font_end\n\tla\tr12, font\n' >> $@
	printf '\tsub\tr13, r13, r12\n\tshli\tr13, r13, 1\n\tori\tr13, r13, 1\n\tret\nfont:\n' >> $@
	od -An -v -tu1 $(FONT) | awk 'NF { printf "\t.byte\t%s", $$1; for (i = 2; i <= NF; i++) printf ", %s", $$i; print "" }' >> $@
	printf 'font_end:\n\t.align\t4\n' >> $@

# boot.img and kernel.img are made by the Buildfile, and copied out of
# the copy when they changed (so that what stands on them is not made
# again). The same build installs the system in _make/system (its bin,
# lib and examples).
$(O)/boot.img: $(O)/kfont.s FORCE
	mkdir -p $(O)/tools
	for t in $(TML) $(TC) $(AS) $(LD) $(AR) $(BUILD) $(RC); do cksum < $$(command -v $$t); done > $(O)/tools.new
	cmp -s $(O)/tools.new $(O)/tools.sum || rm -rf $(S); mv $(O)/tools.new $(O)/tools.sum
	mkdir -p $(S)
	tar -C .. $(COPY) -cf - . | tar -C $(S) -xf -
	cp $(O)/kfont.s $(S)/TinyKernel/kfont.s
	for t in ml:$(TML) cc:$(TC) as:$(AS) ld:$(LD) ar:$(AR) build:$(BUILD) tiny-shell:$(RC); do \
	  ln -sf $$(command -v $${t#*:}) $(O)/tools/$${t%%:*}; done
	rm -rf $(SYSTEM)
	cd $(S) && PATH=$(abspath $(O)/tools):$$PATH MEMORY=$(MEMORY) MEMSIZE=$(MEMSIZE) \
	  build -j $(J) BIN=$(SYSTEM)/bin LIB=$(SYSTEM)/lib EXAMPLES=$(SYSTEM)/examples boot.img install
	cmp -s $(S)/boot.img $(O)/boot.img || cp $(S)/boot.img $(O)/boot.img
	cmp -s $(S)/TinyKernel/kernel.img $(O)/kernel.img || cp $(S)/TinyKernel/kernel.img $(O)/kernel.img
	@test $$(wc -c < $@) -lt 10485760 || { echo "$@: over 10 MB, where KFS.ml has its buffers"; rm $@; exit 1; }
$(O)/kernel.img: $(O)/boot.img
FORCE:
SYSTEM = $(abspath $(O))/system

# The disks use tiny-kernel's file system and are made by tiny-mkfs
# (TinyKernel/host/TinyMkfs.ml), as m-ix's machine has its boot.img and
# its card.img. They are given to the machine by -d: the first is the
# root, in a union with the image's files (/boot), and the second is
# /src. Each disk holds a directory's files, in the order of their
# names, so that the same files make the same disk. A disk is made at
# each make, as the image is (a program of the disk can change while
# the image does not), and kept when its bytes are the same:
#     $(call disk,directory,megabytes,disk)
# A disk has the fewest megabytes that hold its files, which is what a
# web page fetches. For a run or a build on tiny-kernel, a copy is grown
# to 64 by truncate -s (KFS.mli's fs_mount uses the disk whole).
disk = cd $(1) && $(MKFS) -m $(2) $(abspath $(3)).new $$(find . -type f | sed 's|^\./||' | LC_ALL=C sort | sed 's|.*|&=&|') && \
  cd $(CURDIR) && { cmp -s $(3).new $(3) && rm $(3).new || mv $(3).new $(3); }

# disk.img holds the system, which build install put in _make/system:
# /bin (where utils's names are its hard links), /lib and /examples
$(O)/disk.img: $(O)/boot.img $(MKFSBIN) FORCE
	$(call disk,$(SYSTEM),12,$@)
# src.img holds the copy's sources, tiny/'s and the font the host made,
# as the build read them here; they are what tiny-kernel builds itself
# from
$(O)/src.img: $(O)/boot.img $(MKFSBIN) FORCE
	rm -rf $(O)/srcdisk; mkdir -p $(O)/srcdisk
	tar -C .. $(COPY) -cf - . | tar -C $(O)/srcdisk -xf -
	cp $(O)/kfont.s $(O)/srcdisk/TinyKernel/kfont.s
	$(call disk,$(O)/srcdisk,8,$@)
	rm -rf $(O)/srcdisk

# A disk of 64 MB is one of the two disks, grown. It is used for a run
# (run.img and runsrc.img: what is written there is kept from one run
# to the next, until the disk is made again), for a build on
# tiny-kernel (self.img...) and for a check session.
grown = cp $(1) $(2); truncate -s 64M $(2)
$(O)/run.img: $(O)/disk.img
	$(call grown,$<,$@)
$(O)/runsrc.img: $(O)/src.img
	$(call grown,$<,$@)
run: $(O)/boot.img $(O)/run.img $(O)/runsrc.img
	$(MACHINE) -d $(O)/run.img -d $(O)/runsrc.img $(O)/boot.img
run-window: $(O)/boot.img $(O)/run.img $(O)/runsrc.img
	$(MACHINE) -window -d $(O)/run.img -d $(O)/runsrc.img $(O)/boot.img

# The recorded sessions, each checked against its screen's sum. The
# browser's sessions read ../tests/www's pages.
SCREENS = paint windows nested play tetris calc temp debug emacs emacsmx emacscolors office officesheet officedraw officepaint \
	www wwwlink wwwback wwwgo wwwpicture wwwwin wwwscroll wwwmenu wwwhistory wwwsearch
# What changes with the programs' code and the kernel's timing is masked
# in check.out before it is compared:
# - a program's size in /bin (ls -l is checked for its names and links);
# - where a program died (the trap's address);
# - a ping's time;
# - tiny-vcs's hashes (its commits have the date of their second, the
#   boot's and the ticks since);
# - an address, 0x and three digits or more (trace's pointers, a jump's
#   target, a value stack's slot);
# - a backtrace's place in each function (main+0x1c4).
# These follow the code's size. What trace and debug show of the code is
# not masked: the calls and their results, the frames' names and their
# integers.
MASK = -e 's|^(%? ?[-d] +[0-9]+) +[0-9]+ ((/boot)?/bin/)|\1 * \2|' -e 's|: trap ([0-9]+) at [0-9]+,|: trap \1 at *,|' -e 's|in [0-9.]+ ms$$|in * ms|' \
	-e 's|[0-9a-f]{40}|*|g' -e 's|^(%? ?)[0-9a-f]{10} |\1* |' \
	-e 's|^([0-9]+[[:blank:]]+[^+[:blank:]]+)\+0x[0-9a-f]+|\1+*|' -e 's|0x[0-9a-f]{3,}|0x*|g'

# (The machine's date is fixed, 2026-01-01 in seconds since 2000, so
# that a run is the same each time, for tiny-vcs's commits and the
# files' dates. It needs override because a tiny-machine can be given as
# MACHINE on the command line.)
check check-parts self self-quick self-cores: override MACHINE := $(MACHINE) -date 820540800 -seed 1
# The check's parts run side by side, J at a time unless make was given
# -j. Each session's text goes in $(O)/check/NN.out, and these files are
# put together in their order; each screen and sound goes in its own
# files. Sessions that share a disk or files are in one rule, one after
# the other. With every session one after the other, the check would
# take some 15 minutes.
J = 32
NCHECK = 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28
check: $(O)/boot.img
	rm -rf $(O)/check; mkdir -p $(O)/check
	$(MAKE) $(if $(findstring jobserver,$(MAKEFLAGS)),,-j$(J)) check-parts
	cat $(NCHECK:%=$(O)/check/%.out) | sed -E $(MASK) > $(O)/check/check.out
	diff $(T)/check.expected $(O)/check/check.out
	rm -rf $(O)/check && echo "tiny-kernel: check ok"
check-parts: $(NCHECK:%=$(O)/check/%.out) $(SCREENS:%=$(O)/check/%.sum) $(O)/check/tetris.wav.heard $(O)/check/korobeiniki.wav.sum $(O)/check/wwwplay.sum
# Each session has its own copy of the system's disk, the root, grown
# (what it writes stays there) and named after the session: $(D).
D = -d $(O)/check/$(basename $(@F)).img
$(O)/check/%.img: $(O)/disk.img
	$(call grown,$<,$@)
$(NCHECK:%=$(O)/check/%.out): $(O)/check/%.out: $(O)/check/%.img
$(SCREENS:%=$(O)/check/%.sum) $(O)/check/korobeiniki.wav.sum $(O)/check/wwwplay.sum: $(O)/check/%.sum: $(O)/check/%.img
$(O)/check/tetris.wav.heard: $(O)/check/tetris.wav.img
$(O)/check/01.out: $(O)/boot.img
	echo mltests | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/02.out: $(O)/boot.img
	echo bigmem | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/03.out: $(O)/boot.img
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f; mkdir d; cd d; echo x > g; cd ..; cat d/g\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/04.out: $(O)/boot.img
	printf 'rc\nx=(a b c); echo $$x $$#x $$x^.c\nfor(i in a b) echo $$i\nfn greet { echo hello $$1 }; greet you\ny=`{echo one two}; echo $$#y\n{ echo a; echo b } > f; cat f | wc; cat < f; rm f\n~ b $$x && echo b is in x\nnosuch || echo failed: $$status\nmkdir d; echo x > d/g; echo */g; cd /nowhere\necho x >> f\necho no >[1=2]\nexit\necho echo $$1 $$2 > s\nrc s from a file\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/05.out: $(O)/boot.img
	printf 'rc\nmkdir -p d/e; cd d; pwd; echo hello > e/f; walk; du; cp e/f g; mv g e/h; ls e; cmp e/f e/h && echo same\nxd -c e/f; seq 2 2 6; tail -1 e/f; test -d e -a ! -f e && echo dir; [ -f nosuch ] || echo none\nmv e x; cd ..; rm -r d; ls d\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/06.out: $(O)/boot.img
	printf 'rc\nmkdir b; ln /bin/wc b/wc; echo one two three | b/wc -w\necho hi > f; ln f g; echo bye > g; cat f; rm f; cat g\nln b c; ln nosuch c; ls c\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/07.out: $(O)/boot.img
	printf 'rc\ncd /bin; ls | grep \047^t\047 | sort -r\nls | grep -c \047^(ls|wc|cat)$$\047\nseq 12 -3 1 | sort -n; seq 5 | sort -r | grep -v \047[2-4]\047\ngrep \047(\047 /bin/sh; echo $$status\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/08.out: $(O)/boot.img
	printf 'rc\nls /dev; ls -l /cat /bin/cat /bin/utils /bin/emacs /bin/editor /bin/ping\nls -l /bin > f; ls -l /bin | wc > a; wc < f > b; cat f | grep -v zzz | wc > c; cmp a b && cmp b c && echo the same counts\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/09.out: $(O)/boot.img
	printf 'rc\nseq 30 | grep 1 | sort -rn | tail -3 | cat | wc -l\ntest -f no | cat | test -f no; echo $$status\nseq 3 | cat | cat | cat | cat | cat | cat | cat | cat | cat | cat | cat | cat | cat | wc -l\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/10.out: $(O)/boot.img
	printf 'rc\necho hello world > f\ned f\n,x/o/c/0/\n$$a\nadded\n.\n,p\nw\nq\ncat f\nsam f\n,x/l+/c/L/\n,p\nq\nq\nls -l /bin/ed /bin/sam /bin/emacs /bin/editor\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/11.out: $(O)/boot.img
	timeout 300 $(MACHINE) $(D) -events $(T)/emacskeys.events $(O)/boot.img > $@
$(O)/check/12.out: $(O)/boot.img
	timeout 300 $(MACHINE) $(D) -events $(T)/officekeys.events $(O)/boot.img > $@
$(O)/check/13.out: $(O)/boot.img
	timeout 300 $(MACHINE) $(D) -events $(T)/officequit.events $(O)/boot.img > $@
$(O)/check/14.out: $(O)/boot.img
	printf 'rc\ntroff /examples/report.ixd\ntroff -h /examples/report.ixd > r.html; troff -p /examples/report.ixd > r.pdf; wc r.html r.pdf; troff\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/15.out: $(O)/boot.img
	printf 'play /nosuch\nplay /examples/report.ixd\nplay\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/16.out: $(O)/boot.img
	printf 'rc\ncd /examples; build spin\nprof spin.prof -u spin.map\nprof -n 2 spin.prof\nprof\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/17.out: $(O)/boot.img
	timeout 300 $(MACHINE) $(D) $(O)/boot.img < $(T)/db.keys > $@
$(O)/check/18.out: $(O)/boot.img
	timeout 300 $(MACHINE) $(D) $(O)/boot.img < $(T)/vcs.keys > $@
$(O)/check/19.out: $(O)/boot.img
	timeout 300 $(MACHINE) $(D) $(O)/boot.img < $(T)/build.keys > $@
$(O)/check/20.out: $(O)/boot.img $(O)/src.img
	$(call grown,$(O)/src.img,$(O)/check/20src.img)
	timeout 600 $(MACHINE) $(D) -d $(O)/check/20src.img $(O)/boot.img < $(T)/toolchain.keys > $@
$(O)/check/21.out: $(O)/boot.img
	rm -rf $(O)/check/kept; mkdir $(O)/check/kept
	printf 'rc\necho hello world > notes; put notes\nseq 2000 > big; put big numbers\nput nosuch\nput notes ../x\nget \047\047\nexit\n' | timeout 300 $(MACHINE) $(D) -net $(O)/check/kept $(O)/boot.img >> $@
	cat $(O)/check/kept/notes >> $@; wc -c < $(O)/check/kept/numbers | tr -d ' ' >> $@
	printf 'rc\nfor(f in `{get \047\047}) get $$f > $$f\ncat notes; wc numbers\nexit\n' | timeout 300 $(MACHINE) $(D) -net $(O)/check/kept $(O)/boot.img >> $@
$(O)/check/22.out: $(O)/boot.img
	printf 'ping\nping 10.0.0.9\n' | timeout 300 $(MACHINE) $(D) -net . $(O)/boot.img > $@
$(O)/check/23.out: $(O)/boot.img
	printf 'get hello.txt\nget il.txt | wc\nget nothing\nget hello.txt 10.0.0.9\n' | timeout 300 $(MACHINE) $(D) -net ../tests/www -net-lose 7 -net-trace $(O)/boot.img > $@ 2> $(O)/check/trace
	cut -c15- $(O)/check/trace | grep -q '^x ' && echo "the wire: a packet lost" >> $@
$(O)/check/24.out: $(O)/boot.img
	printf "rc\nget 'GET OCaml HTTP/1.0' | wc\nget 'GET https://en.wikipedia.org/wiki/OCaml#History HTTP/1.0' | wc\nget 'GET Plan 9 from Bell Labs HTTP/1.0'\nexit\n" | timeout 300 $(MACHINE) $(D) -net ../tests/www $(O)/boot.img > $@
$(O)/check/25.out: $(O)/boot.img
	rm -f $(O)/check/blank.img
	printf 'rc\nmkdir d; echo hello > d/f; ln d/f g; seq 2000 > big; cp /bin/rc /bin/r2; echo new > /bin/ed; ls -l . d /bin/r2 /bin/ed /boot/bin/ed; ls /; r2 -c \047echo from r2\047; cat /bin/ed; ln d/f /boot/f\nexit\n' | timeout 300 $(MACHINE) -d $(O)/check/blank.img $(O)/boot.img >> $@
	printf 'rc\npwd; cat d/f g; wc big; rm g big; echo bye > d/f; ls /dump; cat /dump/1/usr/glenda/d/f\nexit\n' | timeout 300 $(MACHINE) -d $(O)/check/blank.img $(O)/boot.img >> $@
	printf 'rc\nls /dump /dump/2/usr/glenda; cat d/f /dump/2/usr/glenda/d/f /dump/1/usr/glenda/g; rm /bin/ed; ls -l /bin/ed; rm d; rm /dump/1/usr/glenda/d/f; echo no > /dump/1/x\nexit\n' | timeout 300 $(MACHINE) -d $(O)/check/blank.img $(O)/boot.img >> $@
# trace and debug (plan_tiny_debugger.md):
# - cat's calls, with its output kept apart;
# - a pipeline's processes (-f), one process's lines after another's,
#   because how they interleave moves with any change of the kernel's
#   speed;
# - ping stopped in write (its labels are after its image: -s), the
#   backtrace, a step from the breakpoint, then on to its exit;
# - an ML program's backtrace (trace's), with its slots;
# - a loop of rc's in the background, attached to by trace (to its end)
#   and by debug (stopped in its wait, then let go; it runs four
#   seconds, because debug takes three to start).
# The loops' output goes in files, because on the console it would fall
# among the prompts at times that move too.
$(O)/check/26.out: $(O)/boot.img
	printf "rc\necho hello > f\ntrace cat f\ntrace cat f > g; cat g\ntrace nosuch\ntrace -f rc -c 'cat f | wc' >[2] t\ngrep '^.12. ' t; grep '^.13. ' t; grep '^.14. ' t\ndebug ping\nb write\nc\nbt\nx/i pc 3\ns\nn\nd write\nc\ndebug trace\nb u_write\nc\nbt\nq\n{ for(i in 1 2) { sleep 1; echo \$$i } } > l &\ntrace \$$apid\n{ for(i in 1 2 3 4) { sleep 1; echo \$$i } } > m &\ndebug \$$apid /bin/rc\nb wait\nc\nq\nwait\ncat l m\nexit\n" | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
# ps reads /dev/ps, kill ends a process in the background, and date is
# given seconds (the date of now differs at each run)
$(O)/check/27.out: $(O)/boot.img
	printf 'rc\nsleep 100 &\nps\ncat /dev/ps | wc -l\nkill $$apid; echo $$status; ps -a\nkill 99; echo $$status\ndate 0; date 5184000; date 1073741823; date -n 7\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
# /examples' hello and helloml, tried as the manual has them tried after
# make run. They are built by their Buildfile, by their names (not the
# other examples, so that adding one changes nothing here), run, built
# again (up to date), traced, and debugged (hello stopped in square, the
# assembly's function: bt, x/i, a step; helloml stopped in insert: an ML
# frame and its slots).
$(O)/check/28.out: $(O)/boot.img
	printf 'rc\ncd /examples; build hello helloml; ./hello; ./helloml\nbuild hello helloml\ntrace ./hello\ndebug ./hello\nb square\nc\nbt\nx/i pc 3\ns\nq\ndebug ./helloml\nb insert\nc\nbt\nq\nexit\n' | timeout 300 $(MACHINE) $(D) $(O)/boot.img > $@
$(O)/check/%.sum: $(T)/%.events $(O)/boot.img
	timeout 300 $(MACHINE) $(D) -net ../tests/www -events $< -screen $(O)/check/$*.ppm $(O)/boot.img > /dev/null
	cksum < $(O)/check/$*.ppm > $@; diff $(T)/$*.cksum $@ || { echo "tiny-kernel: $*.events: another screen ($(O)/check/$*.ppm)"; exit 1; }
# tetris's music must be heard: 8-bit samples at 8000 a second, over
# 100,000 bytes (12 s), with more than half of them not the silence's
# 128. The WAV's sum is not checked, because it would move with any
# change of the image (the music's notes fall in other places among the
# keys).
$(O)/check/tetris.wav.heard: $(O)/boot.img
	timeout 300 $(MACHINE) $(D) -events $(T)/tetris.events -audio $(O)/check/tetris.wav $(O)/boot.img > /dev/null
	n=$$(wc -c < $(O)/check/tetris.wav); \
	  s=$$(tail -c +45 $(O)/check/tetris.wav | LC_ALL=C tr -d '\200' | wc -c); \
	  echo "$$n bytes, $$s samples not silent" > $@; \
	  [ $$n -gt 100000 ] && [ $$((s * 2)) -gt $$n ] || \
	  { echo "tiny-kernel: tetris.events: no music ($(O)/check/tetris.wav: $$n bytes, $$s not silent)"; exit 1; }
$(O)/check/korobeiniki.wav.sum: $(O)/boot.img
	printf 'play /examples/korobeiniki.wav\nsleep 2\n' | timeout 300 $(MACHINE) $(D) -audio $(O)/check/korobeiniki.wav $(O)/boot.img > /dev/null
	cksum < $(O)/check/korobeiniki.wav > $@; diff $(T)/korobeiniki.wav.cksum $@ || { echo "tiny-kernel: play: other sounds ($(O)/check/korobeiniki.wav)"; exit 1; }
# A link's WAV file (Content-Type audio/wav) is kept by www and given to
# play; the session checks the page that says so, and play's own sound.
$(O)/check/wwwplay.sum: $(T)/wwwplay.events $(O)/boot.img
	timeout 300 $(MACHINE) $(D) -net ../tests/www -events $< -screen $(O)/check/wwwplay.ppm -audio $(O)/check/wwwplay.wav $(O)/boot.img > /dev/null
	cksum < $(O)/check/wwwplay.ppm > $@; diff $(T)/wwwplay.cksum $@ || { echo "tiny-kernel: wwwplay.events: another screen ($(O)/check/wwwplay.ppm)"; exit 1; }
	cksum < $(O)/check/wwwplay.wav > $@.wav; diff $(T)/korobeiniki.wav.cksum $@.wav || { echo "tiny-kernel: wwwplay.events: other sounds ($(O)/check/wwwplay.wav)"; exit 1; }

# tiny-kernel building itself (plan_tiny_self_hosting.md, step 8). It
# boots on the two disks grown to 64 MB, and the first shell runs build
# all boot.img in /src, with the Buildfile the host's build ran
# (self.keys), and keeps the image in /usr/glenda/self. build install
# puts what it built in /bin, /lib and /examples, over the host's (so
# the builds after it run tiny-kernel's own tools). Then come three
# more builds:
# - after a comment is added to a module (the module is compiled again,
#   its object is the same, and nothing more is done, no link);
# - after a line is added to a program (it is compiled again and the
#   program is linked again; calc is the disk's, so the image is not
#   made again);
# - after nothing (everything is up to date).
# Each build's transcript is kept there (first.log...). The shell prints
# a line of facts for each rebuild, how many units it compiled and
# whether it linked, and those facts are checked here. The transcript's
# lines are not checked, since a unit, a program or a flag added would
# change them, and nothing is compared with a recording. The image of
# the first build, read from the disk by KFS_tests' Cat, must be
# _make/boot.img, byte for byte: the same sources are built by the
# host's tools and by tiny-kernel's, so a change of the code changes
# both, and a difference means that a tool of tiny-kernel's (tiny-ml's
# code, the runtime, the kernel) is wrong. And each file that build
# install put on the disk must be the host's, _make/system's. It takes
# about 50 minutes, so it is not in check.
FSCAT = $(abspath ../../_build/default/tiny/tests/KFS_tests/Cat.exe)
self: $(O)/boot.img $(O)/disk.img $(O)/src.img
	$(call grown,$(O)/disk.img,$(O)/self.img); $(call grown,$(O)/src.img,$(O)/selfsrc.img)
	timeout 36000 $(MACHINE) -d $(O)/self.img -d $(O)/selfsrc.img $(O)/boot.img < $(T)/self.keys > $(O)/self.out
	for f in 'comment: compiled 1 linked 0' 'calc: compiled 1 linked 1 image 0' 'last: compiled 0 linked 0'; do \
	  grep -q "$$f" $(O)/self.out || { echo "tiny-kernel: self: not \"$$f\":"; cat $(O)/self.out; exit 1; }; done
	$(FSCAT) $(O)/self.img usr/glenda/self/first.img > $(O)/self.boot.img
	cmp $(O)/boot.img $(O)/self.boot.img
	cd $(SYSTEM) && for f in $$(find . -type f | sed 's|^\./||'); do \
	  $(FSCAT) $(abspath $(O))/self.img $$f | cmp -s - $$f || { echo "tiny-kernel: self: /$$f not the host's"; exit 1; }; done
	rm $(O)/self.img $(O)/selfsrc.img $(O)/self.out $(O)/self.boot.img && echo "tiny-kernel: self ok, its image the host's"

# self in minutes: a few of the Buildfile's targets are built in /src,
# ping (cc, as, ld) and the library (ml, ar), and each one is compared
# with the host's in the system's disk (self-quick.keys: cmp). What the
# shell printed must be self-quick.expected, once masked by MASK (the
# build's transcript is in /usr/glenda/quick.log). The kernel is not
# linked here; make self links it.
self-quick: $(O)/boot.img $(O)/disk.img $(O)/src.img
	$(call grown,$(O)/disk.img,$(O)/self-quick.img); $(call grown,$(O)/src.img,$(O)/self-quicksrc.img)
	timeout 1800 $(MACHINE) -d $(O)/self-quick.img -d $(O)/self-quicksrc.img $(O)/boot.img < $(T)/self-quick.keys > $(O)/self-quick.out
	sed -E $(MASK) $(O)/self-quick.out | diff $(T)/self-quick.expected -
	rm $(O)/self-quick.img $(O)/self-quicksrc.img $(O)/self-quick.out && echo "tiny-kernel: self-quick ok, ping and the library the host's"

# self on several cores (plan_tiny_multicore.md): tiny-machine -cores 4,
# with each build run with -j 4. Only the image of the first build is
# compared with the host's (the recipes' lines are in the order they
# started, which depends on the cores). By default the cores run in
# turns, so the run is the same each time, and as slow as one core on
# the host. To run on the host's cores, each core on a domain, build
# tiny-machine with OCaml 5 (in _build5, as ./mini-pi -P does), and run
#   make self-cores CORES='-cores 4 -cores-parallel' \
#     MACHINE=../../_build5/default/tiny/TinyMachine.exe
CORES = -cores 4
self-cores: $(O)/boot.img $(O)/disk.img $(O)/src.img
	$(call grown,$(O)/disk.img,$(O)/self-cores.img); $(call grown,$(O)/src.img,$(O)/self-coressrc.img)
	sed 's|^build |build -j 4 |' $(T)/self.keys | timeout 36000 $(MACHINE) $(CORES) -d $(O)/self-cores.img -d $(O)/self-coressrc.img $(O)/boot.img > $(O)/self-cores.out
	$(FSCAT) $(O)/self-cores.img usr/glenda/self/first.img > $(O)/self-cores.boot.img
	cmp $(O)/boot.img $(O)/self-cores.boot.img
	rm $(O)/self-cores.img $(O)/self-coressrc.img $(O)/self-cores.out $(O)/self-cores.boot.img && echo "tiny-kernel: self-cores ok, its image the host's"

clean:
	rm -rf $(O)

.PHONY: all run run-window check check-parts self self-quick self-cores clean FORCE
.SECONDARY:
