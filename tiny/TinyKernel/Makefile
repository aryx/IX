# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-kernel: TinyKernel.ml (../TinyKernel.ml), a free kernel in ML for
# tiny-machine (docs/notes_tiny_kernel.md):
#
#   make run          the kernel on tiny-machine: sh on the console
#   make check        mltests, a script through sh, the utilities through
#                     rc (utils: walk, du, cp, mv, xd, test, ln, grep, sort, ls -l...; pipes of six stages; ed and sam; emacs's
#                     ^C, M-x and a macro; office's page, a text and a sheet, saved,
#                     and a page not saved left by File's Quit twice; troff's text and web page of
#                     /examples/report.ixd), then the network (ping,
#                     get, and put kept across two boots, against
#                     tiny-machine's end of the wire, a
#                     packet lost, each packet as -net-trace says it,
#                     without its time), against check.expected;
#                     then three recorded sessions, the mouse and the keys
#                     from a file, the screen at the halt against its sum:
#                     paint.events (paint on the screen), windows.events
#                     (windows, tiny-windows: three windows, ls, paint in one, a
#                     move, a delete, one brought to the front) and
#                     nested.events (tiny-windows in a window of
#                     tiny-windows, two windows in it), play.events (square,
#                     a game on ../TinyLibPlayground.ml, in a window: the
#                     arrows) and tetris.events (tetris in a window: six
#                     pieces moved, turned and dropped; and its sounds,
#                     the speaker's samples as a WAV, against their sum;
#                     and play's, /examples/korobeiniki.wav played) and calc.events
#                     (calc, on ../TinyLibGUI.ml, in a window: 12 * 3 = by its
#                     buttons, + 6 by the keys, a press taken back, a
#                     button held) and temp.events (temp, its two
#                     fields typed in, in a window) and emacs.events
#                     (emacs f in a window: two lines typed, a word
#                     killed and another typed, saved, quit, cat f);
#                     the office's (office, officesheet, officedraw,
#                     officepaint: a page, a sheet and its chart, a
#                     drawing, a paint, in a window); and with the
#                     network, ../tests/www's pages, the browser's (www,
#                     wwwlink, wwwback, wwwgo, wwwpicture, wwwwin,
#                     wwwscroll, wwwmenu, wwwhistory: the OCaml article,
#                     a link followed and back, a section gone to, its
#                     pictures, in a window, scrolled, the History menu
#                     open, the page before chosen in it); and the disk
#                     (../TinyKernelFS.ml), the root, three boots on a blank one:
#                     files and a directory made in /usr/glenda, a link, a program
#                     copied to /bin and run from there, a file of /boot/bin
#                     written over in /bin (copied to the disk) then removed
#                     (/boot/bin's again), and the snapshots in /dump, read only.
#                     A few minutes
#
# The kernel: entry.tm first (the machine starts at 0), the runtime
# (TinyML's, by tiny-c), the rows TinyKernelGraphics.ml draws by (draw.tm),
# the machine's font (font.tm, made of mini-9pi's console's: 128
# characters of 8 by 16 bits), the kernel (tiny-ml: TinyMemory.ml,
# TinyKernelGraphics.ml, TinyKernelNetwork.ml, TinyKernelAudio.ml,
# TinyKernelFS.ml and ../TinyKernel.ml, one program), end.tm last. Its
# files come after it in boot.img: for each program a name, a line, its
# size, a line, its bytes; an empty line at the end (no disk). The
# programs are tiny-linker's images (linked at 0: the kernel runs each
# at the start of its partition), start.tm first, with libc
# (../TinyCRuntime/) and sys.tm. Each .tm is an object of
# tiny-assembler's first (_make/x.o, from x.tm here or in _make/). A hard link is a name and a line
# "link utils" (what link() does, at the boot): utils (../TinyUtilities.ml, tiny-utils) is in the image once,
# under the name of each of its utilities (cat, ls, wc...). user/'s
# cat, echo, ls, wc, mkdir and rm in C are not in the image any more,
# but t6's (TinyKernel/steps/t6/user/ has links to them).
#
# user/ has the programs, a file each (the ones in C; an ML one's
# last file, which runs it); libc/ what a C program is linked with to
# call this kernel (user.h, sys.tm, draw.c, net.c); libml/ the same
# for an ML one (mlsys.c, TinyCalls.ml, TinyLibSystem.ml).
#
# What is built goes to _make/ and nowhere else, so that this
# directory shows the sources: _make/*.tm the kernel's assembly, *.o
# its objects, kernel.img, user/*.tm the programs' assembly, bin/ the
# programs as they are in the image (each image with its .map, its
# labels' addresses, for tiny-prof), boot.img the image; make clean
# removes it.
# The tools from the PATH (after `dune install`), or from ix's bin/.

export PATH := $(abspath ../../bin):$(PATH)

TML = tiny-ml
TC = tiny-c
AS = tiny-assembler
LD = tiny-linker
CPU = tiny-cpu
MACHINE = tiny-machine

O = _make
# make check's check.expected, sessions (.events) and screens' sums (.cksum)
T = ../tests/TinyKernel_tests
KERNEL = $(O)/entry.o $(O)/udivmod.o $(O)/runtime.o $(O)/draw.o $(O)/font.o $(O)/kernel.o $(O)/end.o
FONT = ../../kernels/lib_machine/font1.bin
PROGS = sh rc emacs office troff play mltests paint windows square tetris calc temp ping get put httpd utils ed bigmem www prof db vcs build as ld cc ml
# other names (hard links), a name:program each
LINKS = editor:emacs sam:ed
# utils's names (TinyUtilities.ml's table)
UTILS = [ basename cat cmp cp du echo grep ln ls mkdir mv pwd rm seq sleep sort tail tee test touch walk wc xd
L = ../TinyCRuntime
ULIB = $(O)/start.o $(O)/udivmod.o $(O)/libc.o $(O)/libc/sys.o

all: $(O)/boot.img

# an object: of a .tm made in _make/, or of one here, or of the C
# runtime's; the .tm made are kept (make deletes what it made on the
# way to another target)
$(O)/%.o: $(O)/%.tm
	$(AS) -o $@ $<
$(O)/%.o: %.tm
	@mkdir -p $(@D)
	$(AS) -o $@ $<
$(O)/%.o: $(L)/%.tm
	@mkdir -p $(@D)
	$(AS) -o $@ $<
.SECONDARY:

# (what tiny-ml compiles depends on tiny-ml too, when TML is a path, as
# ../../tiny-machine gives it: its binary carries TinyLibCore/, the
# first units of every program; old: a change there left the objects
# made before, some units of a program on the old library)
TMLBIN = $(wildcard $(TML))
$(O)/kernel.tm: TinyMemory.ml TinyKernelGraphics.ml TinyKernelNetwork.ml TinyKernelAudio.ml TinyKernelFS.ml ../TinyKernel.ml $(TMLBIN)
	@mkdir -p $(@D)
	$(TML) -o $@ $(filter %.ml,$^)

# the font's bytes, and k_font(), where they are (an ML integer)
$(O)/font.tm: $(FONT)
	@mkdir -p $(@D)
	printf 'k_font:\n\tla\tr13, font\n\tshli\tr13, r13, 1\n\tori\tr13, r13, 1\n\tret\nfont:\n' > $@
	od -An -v -tu1 $(FONT) | awk 'NF { printf "\t.byte\t%s", $$1; for (i = 2; i <= NF; i++) printf ", %s", $$i; print "" }' >> $@
	printf '\t.align\t4\n' >> $@

$(O)/runtime.tm: ../TinyMLRuntime/core.c

$(O)/kernel.img: $(KERNEL)
	$(LD) -map -o $@ $(KERNEL)

$(O)/libc.tm: $(L)/libc.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

# a file in C: the kernel's runtime.c, a program of user/, or what a
# program is linked with besides: libc/ for one in C (draw.c, net.c),
# libml/ for one in ML (mlsys.c)
$(O)/%.tm: %.c libc/user.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

$(O)/bin/%: $(ULIB) $(O)/user/%.o
	@mkdir -p $(@D)
	$(LD) -map -o $@ $(ULIB) $(O)/user/$*.o

# a program in ML: its units, each compiled once by tiny-ml -c into
# _make/ml/ (an object, U.tm, and its interface, U.tmi), after the
# interfaces of the units it names (I_U, in the order of the programs it
# is in: their names are one name space, so a unit sees only what comes
# before it there); linked after mlsys.c (TinyML's runtime and the
# system calls as ML's externals, its stack of values and its heap from
# 384 KB, or from its end when it is larger) with the main
# tiny-ml makes of the program's interfaces (_make/main/: the prelude,
# each unit's init in their order). tiny-linker leaves out what a
# program does not use of its units.
# (old: each program's files compiled whole by tiny-ml, as one
# program, the library's unused toplevel left out by tiny-ml:
# plan_tiny_self_hosting.md, step 4)
U = $(O)/ml
I_TinyLibSystem = TinyCalls
I_TinyLibRegex = TinyCalls TinyLibSystem
I_TinyLibPlayground = TinyCalls TinyLibDraw
I_TinyLibGUI = TinyCalls TinyLibDraw TinyLibPlayground
I_TinyWindows = TinyLibDraw
I_TinyAppTetris = $(I_TinyLibGUI)
I_TinyAppCalculator = $(I_TinyLibGUI) TinyLibGUI
I_TinyAppTemperature = $(I_TinyAppCalculator)
GUI = TinyCalls TinyLibDraw TinyLibPlayground TinyLibGUI
I_TinyEditorScreen = $(GUI)
I_TinyOffice = $(GUI)
I_TinyTroff = $(GUI) TinyOffice
I_TinyPlay = $(GUI)
I_TinyBrowser = $(GUI)
I_TinyShell = $(I_TinyLibRegex)
I_TinyUtilities = $(I_TinyLibRegex) TinyLibRegex
I_TinyEditorLine = $(I_TinyUtilities)
I_TinyProfiler = TinyCalls TinyLibSystem
I_TinyDatabase = TinyCalls TinyLibSystem
I_TinyVCS = TinyCalls TinyLibSystem
I_TinyBuildSystem = TinyCalls TinyLibSystem
I_TinyAssembler = TinyCalls TinyLibSystem TinyMachineISA
I_TinyLinker = $(I_TinyAssembler)
I_TinyC = TinyCalls TinyLibSystem
I_TinyML = TinyCalls TinyLibSystem TinyMLPrelude
I_Square = $(I_TinyLibGUI)
I_Machine = $(I_TinyLibGUI) Square
I_Tetris = $(I_TinyAppTetris) TinyAppTetris
I_Calc = $(I_TinyAppCalculator) TinyAppCalculator
I_Temp = $(I_TinyAppTemperature) TinyAppTemperature
I_Emacs = $(GUI) TinyEditorScreen
I_Office = $(GUI) TinyOffice
I_Troff = $(GUI) TinyOffice TinyTroff
I_Play = $(GUI) TinyPlay
I_Www = $(GUI) TinyBrowser
# each unit's file
F_TinyCalls = libml/TinyCalls.ml
F_TinyLibSystem = libml/TinyLibSystem.ml
F_Square = ../tests/TinyLibPlayground_tests/Square.ml
F_Machine = ../tests/TinyLibPlayground_tests/machine.ml
F_Tetris = user/tetris.ml
F_Calc = user/calc.ml
F_Temp = user/temp.ml
F_Emacs = user/emacs.ml
F_Office = user/office.ml
F_Troff = user/troff.ml
F_Play = user/play.ml
F_Www = user/www.ml
F_Bigmem = user/bigmem.ml
F_TinyMachineISA = ../TinyMachine/TinyMachineISA.ml
F_TinyMLPrelude = $(O)/TinyMLPrelude.ml
# (a static pattern's targets: make uses an implicit rule once in a
# chain, and a unit's interface is another unit's prerequisite)
UNITS = TinyCalls TinyLibSystem TinyLibRegex TinyLibDraw TinyLibPlayground TinyLibGUI TinyProfiler TinyDatabase TinyVCS TinyBuildSystem TinyMachineISA TinyAssembler TinyLinker TinyC TinyMLPrelude TinyML \
  TinyWindows TinyAppTetris TinyAppCalculator TinyAppTemperature TinyEditorScreen TinyOffice TinyTroff TinyPlay TinyBrowser \
  TinyShell TinyUtilities TinyEditorLine Square Machine Tetris Calc Temp Emacs Office Troff Play Www Bigmem
.SECONDEXPANSION:
$(UNITS:%=$(U)/%.tm): $(U)/%.tm: $$(addprefix $(U)/,$$(addsuffix .tmi,$$(I_$$*))) $$(or $$(F_$$*),../$$*.ml) $(TMLBIN)
	@mkdir -p $(@D)
	$(TML) -c -o $@ $(filter %.tmi,$^) $(filter %.ml,$^)
$(UNITS:%=$(U)/%.tmi): $(U)/%.tmi: $(U)/%.tm ;

# each program's units, in their order (windows: tiny-windows, after
# ../TinyLibDraw.ml; rc: tiny-shell, on libml/TinyLibSystem.ml, the system's
# calls it asks for (the host's is host/TinyLibSystem.ml); utils and ed
# with ../TinyLibRegex.ml for grep; emacs, office, troff, play, www:
# run by ../TinyLibGUI.ml's run_canvas; square: the playground's
# test's); its memory when it asks for more than 1 MB, linked as an
# a.out whose header says so (tiny-linker -a): tiny-kernel gives it a
# partition of that size and mlsys.c a heap of it (bigmem: the test;
# www: a page's lines live in its heap; play: the WAV file is read
# whole into it; as, ld, cc, ml: the toolchain, a file whole in memory
# and the compilers' recursions over it).
ML = windows bigmem www play square tetris calc temp rc utils ed emacs office troff prof db vcs build as ld cc ml
UNITS_windows = TinyLibDraw TinyWindows
UNITS_square = $(I_Machine) Machine
UNITS_tetris = $(I_Tetris) Tetris
UNITS_calc = $(I_Calc) Calc
UNITS_temp = $(I_Temp) Temp
UNITS_emacs = $(I_Emacs) Emacs
UNITS_office = $(I_Office) Office
UNITS_troff = $(I_Troff) Troff
UNITS_play = $(I_Play) Play
UNITS_www = $(I_Www) Www
UNITS_rc = $(I_TinyShell) TinyShell
UNITS_utils = $(I_TinyUtilities) TinyUtilities
UNITS_ed = $(I_TinyEditorLine) TinyEditorLine
UNITS_bigmem = Bigmem
UNITS_prof = $(I_TinyProfiler) TinyProfiler
UNITS_db = $(I_TinyDatabase) TinyDatabase
UNITS_vcs = $(I_TinyVCS) TinyVCS
UNITS_build = $(I_TinyBuildSystem) TinyBuildSystem
UNITS_as = $(I_TinyAssembler) TinyAssembler
UNITS_ld = $(I_TinyLinker) TinyLinker
UNITS_cc = $(I_TinyC) TinyC
UNITS_ml = $(I_TinyML) TinyML
MEM_bigmem = -a 8
MEM_www = -a 10
MEM_play = -a 4
MEM_as = -a 16
MEM_ld = -a 16
MEM_cc = -a 16
MEM_ml = -a 32
$(O)/libml/mlsys.tm: ../TinyMLRuntime/core.c
# tiny-ml's library, TinyLibCore/'s modules as strings in a unit of its
# own (tiny/dune's and tiny/mkfile's rule)
CORE = Stdlib Char Seq List String Bytes Array Option Int64 Filename Buffer Hashtbl Common Sha1
$(O)/TinyMLPrelude.ml: $(CORE:%=../TinyLibCore/%.ml)
	@mkdir -p $(@D)
	(echo 'let modules = ['; for m in $(CORE); do echo "\"$$m\", {|"; cat ../TinyLibCore/$$m.ml; echo '|};'; done; echo ']') > $@
$(O)/main/%.tm: $$(addprefix $(U)/,$$(addsuffix .tmi,$$(UNITS_$$*))) $(TMLBIN)
	@mkdir -p $(@D)
	$(TML) -o $@ $(filter %.tmi,$^)
# (the main right after mlsys.c, which calls its ml_start by a jal: 128 KB)
# (end.o last: _end, where mlsys.c puts its stack of values when the
# program is past 384 KB; old: a program past it refused here)
$(ML:%=$(O)/bin/%): $(O)/bin/%: $(ULIB) $(O)/libml/mlsys.o $(O)/main/%.o $$(addprefix $(U)/,$$(addsuffix .o,$$(UNITS_$$*))) $(O)/end.o
	@mkdir -p $(@D)
	$(LD) -map $(MEM_$*) -o $@ $(filter %.o,$^)

# a program that draws: with draw.c, the messages (draw.h); a demo, in
# examples/ (not counted by make loc)
$(O)/user/paint.tm: examples/paint.c libc/user.h libc/draw.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<
$(O)/bin/paint: $(ULIB) $(O)/libc/draw.o $(O)/user/paint.o
	@mkdir -p $(@D)
	$(LD) -map -o $@ $(ULIB) $(O)/libc/draw.o $(O)/user/paint.o
# a program that reaches a machine by its name: with net.c
$(O)/bin/get $(O)/bin/put: $(O)/bin/%: $(ULIB) $(O)/libc/net.o $(O)/user/%.o
	@mkdir -p $(@D)
	$(LD) -map -o $@ $(ULIB) $(O)/libc/net.o $(O)/user/$*.o

BINS = $(addprefix $(O)/bin/,$(PROGS))

# files to edit, in /examples: sources of programs, two in C (wc.c, the
# t6 step kernel's: steps/t6/user/) and two in OCaml, which emacs shows in colors (emacs
# /examples/emacs.ml: the editor around the editor); a page of the
# office's, which troff prints (office /examples/report.ixd, troff -h
# /examples/report.ixd); a sound, which play plays (play
# /examples/korobeiniki.wav: tetris's tune, its first four bars, made by
# m-ix's mini-play, at 11,025 samples a second in 16 bits); a profile and
# its map, which prof reads (prof /examples/spin.prof -u
# /examples/spin.map: ../tests/TinyProfiler_tests/spin.tm, linked with
# -map and run by tiny-cpu -prof); a unit's object and interface as
# the host's tiny-ml and tiny-assembler made them, which ml's and as's on
# tiny-kernel are compared with (make check)
EXAMPLES = steps/t6/user/wc.c user/sh.c user/emacs.ml ../TinyEditorScreen.ml examples/report.ixd examples/korobeiniki.wav $(O)/spin.prof $(O)/spin.map \
	$(U)/TinyMachineISA.tm $(U)/TinyMachineISA.tmi $(U)/TinyMachineISA.o

# sources, in /src as they are in tiny/, for the toolchain on tiny-kernel:
# ping's C and what it is linked with, a unit of ML
# (plan_tiny_self_hosting.md, step 7; its step 8 puts them all)
SRC = TinyKernel/user/ping.c TinyKernel/libc/user.h TinyKernel/libc/sys.tm TinyCRuntime/start.tm TinyCRuntime/udivmod.tm \
	TinyCRuntime/libc.c TinyCRuntime/libc.h TinyMachine/TinyMachineISA.ml TinyMachine/TinyMachineISA.mli

$(O)/spin.prof: ../tests/TinyProfiler_tests/spin.tm
	@mkdir -p $(@D)
	$(AS) -o $(O)/spin.o $<
	$(LD) -map -o $(O)/spin $(O)/spin.o
	$(CPU) -prof $@ $(O)/spin > /dev/null
$(O)/spin.map: $(O)/spin.prof

$(O)/boot.img: $(O)/kernel.img $(BINS) $(EXAMPLES) $(SRC:%=../%)
	cp $(O)/kernel.img $@
	for f in $(BINS); do printf 'bin/%s\n%d\n' $$(basename $$f) $$(wc -c < $$f) >> $@; cat $$f >> $@; done
	for f in $(EXAMPLES); do printf 'examples/%s\n%d\n' $$(basename $$f) $$(wc -c < $$f) >> $@; cat $$f >> $@; done
	for f in $(SRC); do printf 'src/%s\n%d\n' $$f $$(wc -c < ../$$f) >> $@; cat ../$$f >> $@; done
	for u in $(UTILS); do printf 'bin/%s\nlink bin/utils\n' "$$u" >> $@; done
	for l in $(LINKS); do printf 'bin/%s\nlink bin/%s\n' $${l%%:*} $${l#*:} >> $@; done
	printf '\n' >> $@
	@test $$(wc -c < $@) -lt 7864320 || { echo "$@: over 7.5 MB, where runtime.c has the kernel's stack of values"; rm $@; exit 1; }

run: $(O)/boot.img
	$(MACHINE) $(O)/boot.img

# the recorded sessions, each against its screen's sum; the browser's
# read ../tests/www's pages
SCREENS = paint windows nested play tetris calc temp emacs emacsmx emacscolors office officesheet officedraw officepaint \
	www wwwlink wwwback wwwgo wwwpicture wwwwin wwwscroll wwwmenu wwwhistory
check: $(O)/boot.img
	echo mltests | timeout 300 $(MACHINE) $(O)/boot.img > $(O)/check.out
	echo bigmem | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f; mkdir d; cd d; echo x > g; cd ..; cat d/g\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nx=(a b c); echo $$x $$#x $$x^.c\nfor(i in a b) echo $$i\nfn greet { echo hello $$1 }; greet you\ny=`{echo one two}; echo $$#y\n{ echo a; echo b } > f; cat f | wc; cat < f; rm f\n~ b $$x && echo b is in x\nnosuch || echo failed: $$status\nmkdir d; echo x > d/g; echo */g; cd /nowhere\necho x >> f\necho no >[1=2]\nexit\necho echo $$1 $$2 > s\nrc s from a file\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nmkdir -p d/e; cd d; pwd; echo hello > e/f; walk; du; cp e/f g; mv g e/h; ls e; cmp e/f e/h && echo same\nxd -c e/f; seq 2 2 6; tail -1 e/f; test -d e -a ! -f e && echo dir; [ -f nosuch ] || echo none\nmv e x; cd /; rm -r d; ls d\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nmkdir b; ln /bin/wc b/wc; echo one two three | b/wc -w\necho hi > f; ln f g; echo bye > g; cat f; rm f; cat g\nln b c; ln nosuch c; ls c\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\ncd /bin; ls | grep \x27^t\x27 | sort -r\nls | grep -c \x27^(ls|wc|cat)$$\x27\nseq 12 -3 1 | sort -n; seq 5 | sort -r | grep -v \x27[2-4]\x27\ngrep \x27(\x27 /bin/sh; echo $$status\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nls /dev; ls -l /cat /bin/cat /bin/utils /bin/emacs /bin/editor /bin/ping\nls -l /bin > f; wc f; ls -l /bin | wc; cat f | grep -v zzz | wc\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nseq 30 | grep 1 | sort -rn | tail -3 | cat | wc -l\ntest -f no | cat | test -f no; echo $$status\nseq 3 | cat | cat | cat | cat | cat | wc -l\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\necho hello world > f\ned f\n,x/o/c/0/\n$$a\nadded\n.\n,p\nw\nq\ncat f\nsam f\n,x/l+/c/L/\n,p\nq\nq\nls -l /bin/ed /bin/sam /bin/emacs /bin/editor\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	timeout 300 $(MACHINE) -events $(T)/emacskeys.events $(O)/boot.img >> $(O)/check.out
	timeout 300 $(MACHINE) -events $(T)/officekeys.events $(O)/boot.img >> $(O)/check.out
	timeout 300 $(MACHINE) -events $(T)/officequit.events $(O)/boot.img >> $(O)/check.out
	printf 'rc\ntroff /examples/report.ixd\ntroff -h /examples/report.ixd > r.html; troff -p /examples/report.ixd > r.pdf; wc r.html r.pdf; troff\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'play /nosuch\nplay /examples/report.ixd\nplay\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'prof /examples/spin.prof -u /examples/spin.map\nprof -n 2 /examples/spin.prof\nprof\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	timeout 300 $(MACHINE) $(O)/boot.img < $(T)/db.keys >> $(O)/check.out
	timeout 300 $(MACHINE) $(O)/boot.img < $(T)/vcs.keys >> $(O)/check.out
	timeout 300 $(MACHINE) $(O)/boot.img < $(T)/build.keys >> $(O)/check.out
	timeout 600 $(MACHINE) $(O)/boot.img < $(T)/toolchain.keys >> $(O)/check.out
	rm -rf $(O)/kept; mkdir $(O)/kept
	printf 'rc\necho hello world > notes; put notes\nseq 2000 > big; put big numbers\nput nosuch\nput notes ../x\nget \x27\x27\nexit\n' | timeout 300 $(MACHINE) -net $(O)/kept $(O)/boot.img >> $(O)/check.out
	cat $(O)/kept/notes >> $(O)/check.out; wc -c < $(O)/kept/numbers >> $(O)/check.out
	printf 'rc\nfor(f in `{get \x27\x27}) get $$f > $$f\ncat notes; wc numbers\nexit\n' | timeout 300 $(MACHINE) -net $(O)/kept $(O)/boot.img >> $(O)/check.out
	printf 'ping\nping 10.0.0.9\n' | timeout 300 $(MACHINE) -net . $(O)/boot.img >> $(O)/check.out
	printf 'get hello.txt\nget il.txt | wc\nget nothing\nget hello.txt 10.0.0.9\n' | timeout 300 $(MACHINE) -net ../tests/www -net-lose 7 -net-trace $(O)/boot.img >> $(O)/check.out 2> $(O)/check.trace
	cut -c15- $(O)/check.trace >> $(O)/check.out
	printf "rc\nget 'www OCaml' | wc\nget 'www https://en.wikipedia.org/wiki/OCaml#History' | wc\nget 'www Plan 9 from Bell Labs'\nexit\n" | timeout 300 $(MACHINE) -net ../tests/www $(O)/boot.img >> $(O)/check.out
	rm -f $(O)/check.img
	printf 'rc\nmkdir d; echo hello > d/f; ln d/f g; seq 2000 > big; cp /bin/get /bin/g2; echo new > /bin/ping; ls -l . d /bin/g2 /bin/ping /boot/bin/ping; ls /; g2; cat /bin/ping; ln d/f /boot/f\nexit\n' | timeout 300 $(MACHINE) -d $(O)/check.img $(O)/boot.img >> $(O)/check.out
	printf 'rc\npwd; cat d/f g; wc big; rm g big; echo bye > d/f; ls /dump; cat /dump/1/usr/glenda/d/f\nexit\n' | timeout 300 $(MACHINE) -d $(O)/check.img $(O)/boot.img >> $(O)/check.out
	printf 'rc\nls /dump /dump/2/usr/glenda; cat d/f /dump/2/usr/glenda/d/f /dump/1/usr/glenda/g; rm /bin/ping; ls -l /bin/ping; rm d; rm /dump/1/usr/glenda/d/f; echo no > /dump/1/x\nexit\n' | timeout 300 $(MACHINE) -d $(O)/check.img $(O)/boot.img >> $(O)/check.out
	diff $(T)/check.expected $(O)/check.out
	for s in $(SCREENS); do \
	  timeout 300 $(MACHINE) -net ../tests/www -events $(T)/$$s.events -screen $(O)/check.ppm $(O)/boot.img > /dev/null || exit 1; \
	  cksum < $(O)/check.ppm > $(O)/check.sum; diff $(T)/$$s.cksum $(O)/check.sum || { echo "tiny-kernel: $$s.events: another screen ($(O)/check.ppm)"; exit 1; }; \
	done
	timeout 300 $(MACHINE) -events $(T)/tetris.events -audio $(O)/check.wav $(O)/boot.img > /dev/null
	cksum < $(O)/check.wav > $(O)/check.sum; diff $(T)/tetris.wav.cksum $(O)/check.sum || { echo "tiny-kernel: tetris.events: other sounds ($(O)/check.wav)"; exit 1; }
	printf 'play /examples/korobeiniki.wav\nsleep 2\n' | timeout 300 $(MACHINE) -audio $(O)/check.wav $(O)/boot.img > /dev/null
	cksum < $(O)/check.wav > $(O)/check.sum; diff $(T)/korobeiniki.wav.cksum $(O)/check.sum || { echo "tiny-kernel: play: other sounds ($(O)/check.wav)"; exit 1; }
	rm $(O)/check.out $(O)/check.trace $(O)/check.ppm $(O)/check.wav $(O)/check.sum $(O)/check.img && echo "tiny-kernel: check ok"

clean:
	rm -rf $(O)

.PHONY: all run check clean
.SECONDARY:
