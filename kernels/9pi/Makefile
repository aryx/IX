# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-9pi (plan_9pi.md): principia's Plan 9 kernel for the Pi1, in
# OCaml. Its modules (ML below) over kernels/lib_machine's machine (lib_machine/kernel.mk
# builds the image), and 9pi's bootdir embedded (mini-mkbootdir,
# ../tools: the programs from ~/principia that 9pi links into its own
# image).
#
# The directories are principia's kernel/'s: core/ (the types),
# files/ (dev, chan, 9P), processes/, memory/, security/, syscalls/
# (the table; the arch's entry and notes), console/,
# devices/{sys,storage,keyboard,mouse,screen}/, buses/ (USB), init/; an
# arch's code in its arm/ (the Pi1's; arm64/ for the Pi4 some day),
# its interface in the directory above. lib_graphics/ is the pixels
# (PIXEL: ocaml/, or c/ the glue to principia's C), conf/ the bootdir's
# and KERNDATE's
# scripts, tests/ the sessions and screens make check compares.
#
#   make            kernel-pi1.img
# The SD card is principia's (qemu-sd.img: its FAT, served by dossrv,
# the root), its writes kept in memory (snapshot=on).
#
#   make run        under mini-qemu (Ctrl-A x quits)
#   make qemu       under QEMU
#   make check      stage C's session (raspberry/tests/9pi.py's, typed
#                   at the boot's rc: tests/session-c.cmds) under
#                   mini-qemu and QEMU, the console as tests/session-c:
#                   the C 9pi's under QEMU but hoc's pid (40, 9pi's 48:
#                   its usbd's processes, stage D); step D1's (the
#                   processes: sleep, a kill by note, plumber's threads
#                   and mount: tests/session-d); a session typed on
#                   QEMU's USB keyboard (usbd, usb/kb, #Ι/kbin: the C
#                   9pi's byte for byte; tests/session-usb); then stage B's
#                   (tests/boot-b.rc as /boot/boot, no card: the
#                   namespace, the environment, pipes, processes;
#                   tests/session-b); then the screen (the console drawn
#                   as 9pi draws it, the arrow cursor), after a session
#                   and after the USB mouse moved, under mini-qemu and
#                   QEMU: the C 9pi's pixels (tests/screen*-c.ppm.gz)
#                   Then rio (tests/graphics.py: raspberry/tests/9pi_graphics.py's
#                   steps, the USB keyboard and mouse: the console, rio
#                   started, its menu, a window swept out, a command in
#                   it), every screen and the console the C 9pi's
#                   (tests/rio-c.md5, tests/rio-c.txt), under mini-qemu
#                   and QEMU
#   make expected-screen  the C 9pi's screens, under QEMU (tests/*.ppm.gz)
#   make expected-rio     the C 9pi's rio screens (their md5s) and console

MAKEFLAGS += --no-builtin-rules

PRINCIPIA ?= $(HOME)/principia
# the modules, in link order, in principia's kernel/ directories; the
# kernel's arch's own (ARCH: arm the Pi1's, arm64 the Pi4's) in its
# directory, their interfaces in the directory above. The programs are
# arm's on both boards (principia's, 5c's: AArch32 at EL0 on the Pi4),
# so syscalls/arm/Syscall is their ABI on both; the Pi4's EMMC and
# DWC2 are the Pi1's as QEMU's raspi4b has them
ARCH = $(if $(filter pi4,$(BOARD)),arm64,arm)
ML = syscalls/$(ARCH)/Ureg core/Errors core/Types files/Dev processes/Proc files/Kchan processes/Kproc devices/sys/Devroot security/Rng console/Devcons \
  devices/sys/Devenv devices/sys/Devsys devices/sys/Devarch devices/sys/Devdup devices/sys/Devsrv devices/sys/Devpipe \
  devices/sys/Devproc devices/storage/arm/Emmc devices/storage/Devsd filesystems/lib_fat/Fat filesystems/Kdos filesystems/lib_xv6fs/Xv6fs filesystems/Kfs files/P9 files/P9_wire devices/sys/Devmnt \
  buses/Usb buses/arm/Usbdwc buses/Devusb devices/keyboard/Latin1 devices/keyboard/Kbd $(PIXEL_ML) devices/screen/Swcursor \
  devices/screen/Swconsole devices/keyboard/Devkbin devices/mouse/Devmouse devices/audio/Devaudio buses/lib_usb/Usbdesc buses/lib_usb/Hid buses/lib_usb/Usbbus buses/Kusb devices/web/Kweb \
  devices/screen/Devdraw devices/Devstub network/Etherusb network/Devether network/ip/Ip network/ip/Icmp network/ip/Udp network/ip/Tcp network/ip/Devip memory/Fault processes/Exec \
  syscalls/Usermem processes/Sysproc processes/Syssema files/Sysfile security/Auth syscalls/Systab \
  syscalls/arm/Syscall init/Main

# the bootdir, as kernel/conf/arm/pi's: boot.rc as /boot/boot (or a
# test's script: BOOTRC)
BIN = $(PRINCIPIA)/ROOT/arch/arm/bin
BOOTRC ?= $(PRINCIPIA)/kernel/init/user/boot/arm/boot.rc
RC ?= $(BIN)/rc
# (BOOTMORE: more of principia's programs, by their names: a check's)
BOOTDIR = boot=$(BOOTRC) rcmain=$(PRINCIPIA)/ROOT/rc/lib/rcmain rc=$(RC) \
  $(foreach p,echo bind fdisk dossrv mount ls $(BOOTMORE),$(p)=$(BIN)/$(p))
FS = $(B)/bootdir

# the devices' files' date: 9pi's (its conf compiled with
# -DKERNDATE=`date -n`: mini-mkbootdir finds it in 9pi's image, given
# principia's directory), so that their entries are 9pi's
KERNDATE ?= $(PRINCIPIA)

# the pixels (lib_graphics/Kdraw.mli): PIXEL=ocaml (the default), stage
# F's OCaml (lib_graphics/ocaml's Kdraw, over lib_memdraw and
# lib_memlayer: principia's libmemdraw and libmemlayer, which know
# nothing of a kernel); PIXEL=c, principia's C pixel libraries
# (lib_graphics/c), as before stage F
PIXEL ?= ocaml
# each its own build (the OCaml's build/pi1-ocaml...), the image
# relinked when PIXEL changes (the same file: mini-pi's, the checks')
# (and the compiler's, kernel.mk's COMPILER=ocaml: OCaml 4.14's objects
# are not ocaml-light's)
PIX = $(if $(filter ocaml,$(PIXEL)),-ocaml)$(if $(filter ocaml,$(COMPILER)),-ocaml4)
B ?= build/$(BOARD)$(PIX)
PIXEL_ML = $(if $(filter ocaml,$(PIXEL)),$(OCAML_PIXEL),lib_graphics/c/Kdraw)
OCAML_PIXEL = lib_graphics/Memdata $(addprefix lib_graphics/lib_memdraw/,Memchan Memimage Memgeneral Memdraw Memfont) \
  $(addprefix lib_graphics/lib_memlayer/,Memlayer Memshape) lib_graphics/ocaml/Kdraw

# principia's C pixel libraries (plan_9pi.md, decision 4), compiled by
# gcc with principia's headers (Plan 9 C: -fplan9-extensions, p9gcc.h's
# USED and SET) and linked in (lib_machine/kernel.mk's EXTRA_OBJS), with
# draw9.c (their libc, the kernel's d9_* interface, and hwdraw: 9pi's
# screen.c's, not libmemdraw's hooks.c) and drawglue.c (its OCaml
# primitives)
GFX = $(PRINCIPIA)/lib_graphics
MEMDRAW = alloc alphadraw arc chan cmap color compressed defont draw ellipse fillpoly init io line poly \
  replmul resolution string subfont transfer
MEMLAYER = $(basename $(notdir $(wildcard $(GFX)/libmemlayer/*.c)))
LIBDRAW = arith replclipr_geom chan resolution defont icossin icossin2 compressed misc
P9CFLAGS = $(CPU) -O2 -ffreestanding -fno-builtin -fno-pie -fno-stack-protector -fplan9-extensions -w \
  -include lib_graphics/c/p9gcc.h -I$(PRINCIPIA)/include/arch/arm $(P9INC) -I$(PRINCIPIA)/include/ALL
# the Pi4's: Plan 9's long is 32 bits (5c's, 7c's), gcc's (LP64) 64, and
# memdraw's pixel words are ulongs: principia's libc.h with an unsigned
# int ulong, before its own
P9INC = $(if $(filter pi4,$(BOARD)),-I$(B)/p9)
DRAWOBJS = $(MEMDRAW:%=$(B)/gfx/md_%.o) $(MEMLAYER:%=$(B)/gfx/ml_%.o) $(LIBDRAW:%=$(B)/gfx/ld_%.o) $(B)/gfx/draw9.o
EXTRA_OBJS = $(if $(filter ocaml,$(PIXEL)),,$(DRAWOBJS) $(B)/drawglue.o)

include ../lib_machine/kernel.mk

$(IMAGE): build/pixel-$(BOARD)
build/pixel-$(BOARD): FORCE
	mkdir -p build; echo $(PIXEL) | cmp -s - $@ || echo $(PIXEL) > $@

# the Pi4's processes AArch32's (lib_machine/pi4/board.h)
ifeq ($(BOARD),pi4)
CFLAGS += -DTF_USER_PSR=0x10
endif

SD = -drive file=$(PRINCIPIA)/qemu-sd.img,if=sd,format=raw,snapshot=on
USB = -device usb-kbd -device usb-mouse

$(B)/gfx: $(if $(P9INC),$(B)/p9/libc.h)
	mkdir -p $@
$(B)/p9/libc.h: $(PRINCIPIA)/include/ALL/libc.h
	mkdir -p $(B)/p9
	sed 's/^typedef unsigned long\tulong;/typedef unsigned int\tulong;/' $< > $@
$(B)/gfx/md_%.o: $(GFX)/libmemdraw/%.c lib_graphics/c/p9gcc.h | $(B)/gfx
	$(KCC) $(P9CFLAGS) -c $< -o $@
$(B)/gfx/ml_%.o: $(GFX)/libmemlayer/%.c lib_graphics/c/p9gcc.h | $(B)/gfx
	$(KCC) $(P9CFLAGS) -c $< -o $@
$(B)/gfx/ld_%.o: $(GFX)/libdraw/%.c lib_graphics/c/p9gcc.h | $(B)/gfx
	$(KCC) $(P9CFLAGS) -c $< -o $@
$(B)/gfx/draw9.o: lib_graphics/c/draw9.c lib_graphics/c/p9gcc.h | $(B)/gfx
	$(KCC) $(P9CFLAGS) -c $< -o $@
$(B)/drawglue.o: lib_graphics/c/drawglue.c | $(B)
	$(KCC) $(CFLAGS) -c $< -o $@

# the OCaml pixels' data: principia's colour map and default font
# claude: lib_graphics/Memdata.ml is in the repository (no principia
# needed); made again from principia's C, if that changes:
pixdata:
	../../_build/default/kernels/tools/Mkpixdata.exe $(PRINCIPIA) lib_graphics

# (remade when one of its files is: name=file's files)
MKBOOTDIR = ../../_build/default/kernels/tools/Mkbootdir.exe
$(FS): $(MKBOOTDIR) $(foreach x,$(BOOTDIR),$(lastword $(subst =, ,$(x)))) | $(B)
	$(MKBOOTDIR) $@ $(KERNDATE) $(BOOTDIR)

run: $(IMAGE)
	$(MINIQEMU) $(BOOT) $(SD)

qemu: $(IMAGE)
	$(QEMU) $(QEMU_BOOT) $(SD)

# a console as the Pi1's C 9pi's: QEMU's framebuffer warns, the C
# 9pi's as mini-9pi's (its mailbox's channel 1 writing back the fb's
# answer), not the console's; the Pi4's banner's two board lines made
# the Pi1's, and the SD card's address (QEMU 11's is random) its 4567
BOARD_SED = $(if $(filter pi4,$(BOARD)),-e 's/^board rev: 0xb03115 /board rev: 0x900021 /' \
  -e 's/^cpu0: 0MHz ARM Cortex-A72/cpu0: 0MHz ARM 1176JZF-S/' -e 's/^rca [0-9a-f]* ocr/rca 4567 ocr/') \
  $(if $(filter pi2,$(BOARD)),-e 's/^board rev: 0xa21041 /board rev: 0x900021 /' -e 's/^cpu0: 0MHz ARM Cortex-A7\( ([0-9] cores)\)\?$$/cpu0: 0MHz ARM 1176JZF-S/')
# (and with ix's programs the clock runs, from boot.rc's date: the
# minute of what a session wrote, which is the run's, is MM in the
# recorded consoles)
# (and mini-9pi's line after a "suicide", its trace, which 9pi has not: Syscall.traced)
# (and the boot's line of the memory, each kernel's own numbers: 9pi's
# "448M memory: 91M kernel data, 357M user, 1696M swap", mini-9pi's
# "512M memory: 64M video, 96M kernel data, 352M user, 0M swap" (16M
# and 400M on the board, whose firmware keeps 16 MB): N in the
# recorded consoles, the video's part left out)
unwarned = sed -e 's/^[0-9]*M memory: \([0-9]*M video, \)\?[0-9]*M kernel data, [0-9]*M user, [0-9]*M swap/NM memory: NM kernel data, NM user, NM swap/' -e '/^qemu-system-[a-z0-9]*: warning: Blocked re-entrant IO on MemoryRegion: bcm2835-fb/d' -e '/^[^ ]* [0-9]*: trace: lr=/d' -e 's/ Sep 26 00:[0-9][0-9] / Sep 26 00:MM /' $(BOARD_SED) $(1)

# the screen's sessions: a command, then the mouse moved (usb/kb's
# moves, accelerated as 9pi's mousetrack)
SCREEN_SESSION = "echo hello"
MOVE = --usb --move "200,-100;-60,40"
C9PI = qemu-system-arm -M raspi1ap -device loader,file=$(PRINCIPIA)/kernel/COMPILE/9/bcm/9pi,addr=0x8000,cpu-num=0,force-raw=on \
  $(SD) -serial null -serial mon:stdio -display none $(USB)

expected-screen: | $(B)
	$(SESSION_PY) --prompt "% " --timeout 120 --screendump $(B)/c-screen.ppm --out $(B)/c-screen.txt $(SCREEN_SESSION) -- $(C9PI)
	gzip -n -9 < $(B)/c-screen.ppm > tests/screen-c.ppm.gz
	$(SESSION_PY) --prompt "% " $(MOVE) --timeout 200 --screendump $(B)/c-move.ppm --out $(B)/c-move.txt $(SCREEN_SESSION) -- $(C9PI)
	gzip -n -9 < $(B)/c-move.ppm > tests/screen-move-c.ppm.gz

# the network (stage E): a usb-net (Etherusb, #l0, #I), a web server on
# the host (tests/www, 127.0.0.1:8123: 10.0.2.2's, QEMU's user network
# and mini-qemu's Usernet), ipconfig, ping, hget; the round trips'
# times masked (QEMU 11.1's raspi4b needs its build with slirp:
# configure --enable-slirp)
NET = -device usb-net,netdev=n0 -netdev user,id=n0
netmask = sed -e 's/rtt [0-9]* /rtt N /; s/avg rtt [0-9]* /avg rtt N /' $(1)
www = (cd tests/www && exec python3 -m http.server 8123 --bind 127.0.0.1 > /dev/null 2>&1) & echo $$! > $(B)/www.pid; sleep 1
wwwstop = kill $$(cat $(B)/www.pid)

RIO_SCREENS = boot.ppm $(foreach i,1 2 3 4 5 6 7 8 9 10,step$(i).ppm)

expected-rio: | $(B)
	rm -rf $(B)/rio-c
	tests/graphics.py $(B)/rio-c -- $(C9PI)
	cd $(B)/rio-c && md5sum $(RIO_SCREENS) > $(CURDIR)/tests/rio-c.md5
	$(call unwarned,$(B)/rio-c/console.txt) | tr -d '\r' > tests/rio-c.txt

# stage B's image (tests/boot-b.rc as /boot/boot): kernel-pi1-b.img,
# kernel-pi4-b.elf
IMAGE_B = $(basename $(IMAGE))-b$(suffix $(IMAGE))

# The sessions: each one an emulator and a kernel waited on, a core
# each, and none reads what another writes: side by side (check's
# $(MAKE) -j; one after the other they took 7 minutes, 14 for ix's
# slower kernel), then check compares what each wrote. One web server
# for the network's two.
run-mini-c:
	$(SESSION_PY) --prompt "% " --timeout 300 --out $(B)/mini-c.txt --lines tests/session-c.cmds -- $(MINIQEMU) $(BOOT) $(SD)
run-qemu-c:
	$(SESSION_PY) --prompt "% " --timeout 120 --out $(B)/qemu-c.txt --lines tests/session-c.cmds -- $(QEMU) $(QEMU_BOOT) $(SD)
run-mini-d:
	$(SESSION_PY) --prompt "% " --timeout 300 --out $(B)/mini-d.txt --lines tests/session-d.cmds -- $(MINIQEMU) $(BOOT) $(SD)
run-qemu-d:
	$(SESSION_PY) --prompt "% " --timeout 120 --out $(B)/qemu-d.txt --lines tests/session-d.cmds -- $(QEMU) $(QEMU_BOOT) $(SD)
run-mini-usb:
	$(SESSION_PY) --prompt "% " --usb --timeout 700 --out $(B)/mini-usb.txt --lines tests/session-usb.cmds -- $(MINIQEMU) $(BOOT) $(SD) $(USB)
run-qemu-usb:
	$(SESSION_PY) --prompt "% " --usb --timeout 300 --out $(B)/qemu-usb.txt --lines tests/session-usb.cmds -- $(QEMU) $(QEMU_BOOT) $(SD) $(USB)
run-mini-b:
	$(SESSION_PY) --prompt "% " --timeout 120 --out $(B)/mini-b.txt --lines tests/session-b.cmds -- $(MINIQEMU) $(BOOT_B)
run-qemu-b:
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-b.txt --lines tests/session-b.cmds -- $(QEMU) $(QEMU_BOOT_B)
run-mini-screen:
	$(SESSION_PY) --prompt "% " --timeout 300 --screendump $(B)/mini-screen.ppm --out $(B)/mini-screen.txt $(SCREEN_SESSION) -- $(MINIQEMU) $(BOOT) $(SD) $(USB)
run-qemu-screen:
	$(SESSION_PY) --prompt "% " --timeout 120 --screendump $(B)/qemu-screen.ppm --out $(B)/qemu-screen.txt $(SCREEN_SESSION) -- $(QEMU) $(QEMU_BOOT) $(SD) $(USB)
run-mini-move:
	$(SESSION_PY) --prompt "% " $(MOVE) --timeout 500 --screendump $(B)/mini-move.ppm --out $(B)/mini-move.txt $(SCREEN_SESSION) -- $(MINIQEMU) $(BOOT) $(SD) $(USB)
run-qemu-move:
	$(SESSION_PY) --prompt "% " $(MOVE) --timeout 200 --screendump $(B)/qemu-move.ppm --out $(B)/qemu-move.txt $(SCREEN_SESSION) -- $(QEMU) $(QEMU_BOOT) $(SD) $(USB)
run-rio-mini:
	tests/graphics.py --step 10 --expect tests/rio-c.md5 $(B)/rio-mini -- $(MINIQEMU) $(BOOT) $(SD) $(USB)
run-rio-qemu:
	tests/graphics.py --expect tests/rio-c.md5 $(B)/rio-qemu -- $(QEMU) $(QEMU_BOOT) $(SD) $(USB)
run-mini-net:
	$(SESSION_PY) --prompt "% " --timeout 400 --out $(B)/mini-net.txt --lines tests/session-net.cmds -- $(MINIQEMU) $(BOOT) $(SD) $(USB) $(NET)
run-qemu-net:
	$(SESSION_PY) --prompt "% " --timeout 300 --out $(B)/qemu-net.txt --lines tests/session-net.cmds -- $(QEMU) $(QEMU_BOOT) $(SD) $(USB) $(NET)
SESSIONS = run-mini-c run-qemu-c run-mini-d run-qemu-d run-mini-usb run-qemu-usb run-mini-b run-qemu-b run-mini-screen run-qemu-screen run-mini-move run-qemu-move run-rio-mini run-rio-qemu run-mini-net run-qemu-net
sessions: $(SESSIONS)
.PHONY: sessions $(SESSIONS)

check: $(IMAGE) $(IMAGE_B)
	rm -rf $(B)/rio-mini $(B)/rio-qemu
	$(www); $(MAKE) --no-print-directory -j$(words $(SESSIONS)) sessions; r=$$?; $(wwwstop); exit $$r
	$(call unwarned,$(B)/mini-c.txt) | diff - tests/session-c && echo "ok 9pi: stage C's session under mini-qemu"
	$(call unwarned,$(B)/qemu-c.txt) | diff - tests/session-c && echo "ok 9pi: stage C's session under QEMU"
	$(call unwarned,$(B)/mini-d.txt) | diff - tests/session-d && echo "ok 9pi: step D1's session under mini-qemu"
	$(call unwarned,$(B)/qemu-d.txt) | diff - tests/session-d && echo "ok 9pi: step D1's session under QEMU"
	$(call unwarned,$(B)/mini-usb.txt) | diff - tests/session-usb && echo "ok 9pi: a session typed on the USB keyboard under mini-qemu"
	$(call unwarned,$(B)/qemu-usb.txt) | diff - tests/session-usb && echo "ok 9pi: a session typed on the USB keyboard under QEMU"
	$(call unwarned,$(B)/mini-b.txt) | diff - tests/session-b && echo "ok 9pi: stage B's session under mini-qemu"
	$(call unwarned,$(B)/qemu-b.txt) | diff - tests/session-b && echo "ok 9pi: stage B's session under QEMU"
	gzip -dc tests/screen-c.ppm.gz | cmp - $(B)/mini-screen.ppm && gzip -dc tests/screen-c.ppm.gz | cmp - $(B)/qemu-screen.ppm \
	  && echo "ok 9pi: the screen as the C 9pi draws it, under mini-qemu and QEMU"
	gzip -dc tests/screen-move-c.ppm.gz | cmp - $(B)/mini-move.ppm && gzip -dc tests/screen-move-c.ppm.gz | cmp - $(B)/qemu-move.ppm \
	  && echo "ok 9pi: the screen after the USB mouse moved, as the C 9pi's, under mini-qemu and QEMU"
	cd $(B)/rio-mini && md5sum --quiet -c $(CURDIR)/tests/rio-c.md5
	cd $(B)/rio-qemu && md5sum --quiet -c $(CURDIR)/tests/rio-c.md5
	$(call unwarned,$(B)/rio-mini/console.txt) | tr -d '\r' | diff - tests/rio-c.txt
	$(call unwarned,$(B)/rio-qemu/console.txt) | tr -d '\r' | diff - tests/rio-c.txt \
	  && echo "ok 9pi: rio (its menu, a window swept out, a command in it), every screen and the console the C 9pi's, under mini-qemu and QEMU"
	$(call unwarned,$(B)/mini-net.txt) | $(call netmask) | diff - tests/session-net && echo "ok 9pi: the network (ipconfig, ping, hget from the host) under mini-qemu"
	$(call unwarned,$(B)/qemu-net.txt) | $(call netmask) | diff - tests/session-net && echo "ok 9pi: the network under QEMU"

# stage B's image: its own build directory, tests/boot-b.rc as /boot/boot
# (the rule in the outer make only: the inner one builds it as IMAGE)
ifneq ($(findstring -b.,$(IMAGE)),-b.)
$(IMAGE_B): FORCE
	$(MAKE) B=build/$(BOARD)$(PIX)-b IMAGE=$@ BOOTRC=tests/boot-b.rc $@
endif

BOOT_B = $(subst $(IMAGE),$(IMAGE_B),$(BOOT))
QEMU_BOOT_B = $(subst $(IMAGE),$(IMAGE_B),$(QEMU_BOOT))

# mini-9pi alone (plan_rio.md): make ix, kernel-pi1-ix.img, a kernel
# whose bootdir is ix's own programs, in OCaml by mini-ml, Plan 9's
# a.out (mini-mk O=5 OS=plan9: ix's tools, from ../../bin): mini-rc as
# rc (it runs conf/boot.rc, /boot/boot, then the prompt), utilities/'s
# echo, ls, cat, bind and mount, mini-ed as ed, tests/hello and
# tests/threads (mini-ml's threads and channels), Source's check
# (lib_core/commons/tests), mini-dossrv, mini-fdisk and hellodraw
# and hellomenu (lib_graphics/tests), mini-rio as rio and hellorio (windows), mini-colors as colors
# (apps/misc). No SD
# card, nothing of principia's in the bootdir (its date: KERNDATE_IX,
# the day mini-9pi was started; the pixels' tables are still
# principia's: mini-mkpixdata).
#   make ix          the image
#   make run-ix      under mini-qemu (../../mini-pi mini-9pi)
#   make check-ix    two sessions, under mini-qemu and QEMU, the console
#                    as recorded: tests/session-ix.cmds (hello, ed, a
#                    status: tests/session-ix), and stage B's own
#                    (tests/session-ix-b.cmds, its rc without -m: tests/session-ix-b)
IX = $(abspath ../..)
IX9 = $(IX)/_mk/5-plan9
IXDIRS = lib_core shell editors/ed utilities/files utilities/misc utilities/namespace utilities/time utilities/pipe utilities/compare utilities/process utilities/text utilities/byte utilities/calc/hoc utilities/calc/dc utilities/calc/bc utilities/text/awk kernels/9pi/tests/hello kernels/9pi/tests/hog kernels/9pi/tests/tone kernels/9pi/tests/threads lib_core/commons/tests kernels/9pi/filesystems/user/dossrv \
  kernels/9pi/devices/storage/user/fdisk kernels/9pi/buses/user/usbd lib_graphics/tests windows windows/tests apps/misc apps/music/play apps/music/rebirth games \
  languages/smalltalk languages/smalltalk/hosts/draw languages/scheme languages/pascal languages/prolog editors/drscheme apps/office apps/page editors/turbopascal/hosts/draw editors/emacs/draw \
  typesetting/troff typesetting/man networking browsers/lynx browsers/netscape
BOOTDIR_IX = boot=conf/boot.rc rc=$(IX9)/shell/mini-rc ed=$(IX9)/editors/ed/mini-ed hello=$(IX9)/kernels/9pi/tests/hello/hello hog=$(IX9)/kernels/9pi/tests/hog/hog threads=$(IX9)/kernels/9pi/tests/threads/threads sources=$(IX9)/lib_core/commons/tests/sources \
  echo=$(IX9)/utilities/misc/mini-echo ls=$(IX9)/utilities/files/mini-ls cat=$(IX9)/utilities/files/mini-cat \
  bind=$(IX9)/utilities/namespace/mini-bind mount=$(IX9)/utilities/namespace/mini-mount \
  dossrv=$(IX9)/kernels/9pi/filesystems/user/dossrv/mini-dossrv fdisk=$(IX9)/kernels/9pi/devices/storage/user/fdisk/mini-fdisk \
  hellodraw=$(IX9)/lib_graphics/tests/hellodraw hellomenu=$(IX9)/lib_graphics/tests/hellomenu \
  words=tests/words.txt
KERNDATE_IX = 1790380800
IMAGE_IX = $(basename $(IMAGE))-ix$(suffix $(IMAGE))
BOOT_IX = $(subst $(IMAGE),$(IMAGE_IX),$(BOOT))
QEMU_BOOT_IX = $(subst $(IMAGE),$(IMAGE_IX),$(QEMU_BOOT))
ix: | $(B)
	for d in $(IXDIRS); do (cd $(IX)/$$d && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null) || exit 1; done
	cd $(IX)/games && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 PLATFORM=software > /dev/null
	$(MAKE) B=build/$(BOARD)$(PIX)-ix IMAGE=$(IMAGE_IX) BOOTDIR="$(BOOTDIR_IX)" KERNDATE=$(KERNDATE_IX) $(IMAGE_IX)
# with a USB keyboard and mouse: the same image and mini-usbd in its
# bootdir (the driver is a program in Plan 9: buses/user/usbd, ix's
# own), for the checks that move a mouse (check-menu)
IMAGE_IXU = $(basename $(IMAGE))-ixu$(suffix $(IMAGE))
BOOT_IXU = $(subst $(IMAGE),$(IMAGE_IXU),$(BOOT))
QEMU_BOOT_IXU = $(subst $(IMAGE),$(IMAGE_IXU),$(QEMU_BOOT))
ix-usb: ix
	$(MAKE) B=build/$(BOARD)$(PIX)-ixu IMAGE=$(IMAGE_IXU) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXU)
# with the network's programs (plan_browser.md, stage 10): ix-usb's
# image and mini-curl in its bootdir. check-ix-net: the interface
# configured by echo into /net/ipifc's files (no ipconfig), then
# mini-curl, an ix program over the kernel's TCP (lib_networking's
# plan9/Tcp: /net/tcp's files), asks the host's web server (tests/www,
# 10.0.2.2:8123) for the two files of check's session-net; under QEMU
# (the roots a certificate is checked against: this machine's)
CA_PEM = /etc/ssl/certs/ca-certificates.crt
IMAGE_IXN = $(basename $(IMAGE))-ixn$(suffix $(IMAGE))
QEMU_BOOT_IXN = $(subst $(IMAGE),$(IMAGE_IXN),$(QEMU_BOOT))
ix-net: ix
	cd $(IX)/networking && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null
	cd $(IX)/browsers/lynx && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null
	$(MAKE) B=build/$(BOARD)$(PIX)-ixn IMAGE=$(IMAGE_IXN) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd curl=$(IX9)/networking/mini-curl wc=$(IX9)/utilities/misc/mini-wc timesync=$(IX9)/networking/mini-timesync lynx=$(IX9)/browsers/lynx/mini-lynx ca.pem=$(CA_PEM)" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXN)
run-qemu-ix-net:
	mkdir -p $(B); $(call www); \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 120 --out $(B)/qemu-ix-net.txt --lines tests/session-ix-net.cmds -- $(QEMU) $(QEMU_BOOT_IXN) $(USB) $(NET); \
	$(call wwwstop)
BOOT_IXN = $(subst $(IMAGE),$(IMAGE_IXN),$(BOOT))
# https:// from the Internet, by hand (not check's: it needs the
# Internet, and its bytes are the servers'): boot.rc has set the
# interface and the clock (mini-timesync), the secrets are the board's
# generator's (Rng), the roots /boot/ca.pem. tests/session-ix-tls.cmds;
# the console in $(B)/qemu-ix-tls.txt and mini-ix-tls.txt
run-qemu-ix-tls: ix-net
	mkdir -p $(B)
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 240 --out $(B)/qemu-ix-tls.txt --lines tests/session-ix-tls.cmds -- $(QEMU) $(QEMU_BOOT_IXN) $(USB) $(NET)
run-mini-ix-tls: ix-net
	mkdir -p $(B)
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 1800 --out $(B)/mini-ix-tls.txt --lines tests/session-ix-tls.cmds -- $(MINIQEMU) $(BOOT_IXN) $(USB) $(NET)
run-mini-ix-net:
	mkdir -p $(B); $(call www); \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 300 --out $(B)/mini-ix-net.txt --lines tests/session-ix-net.cmds -- $(MINIQEMU) $(BOOT_IXN) $(USB) $(NET); \
	$(call wwwstop)
check-ix-net: ix-net run-qemu-ix-net run-mini-ix-net
	$(call unwarned,$(B)/qemu-ix-net.txt) | diff - tests/session-ix-net && echo "ok 9pi: mini-curl over the kernel's TCP, from the host's web server, under QEMU"
	$(call unwarned,$(B)/mini-ix-net.txt) | diff - tests/session-ix-net && echo "ok 9pi: mini-curl under mini-qemu"
# a game for two computers (the playground's TinyTronscroll, over its
# Multiplayer and lib_networking/netcode): ix-usb's image and the game
# in its bootdir. check-tron: the game in the kernel plays with the
# same game on this machine (mini-ml's for Linux, games/arcade's: the
# two then sum the same bytes of their models), over UDP through
# QEMU's user network, once as the one that joins (10.0.2.2 is this
# machine: /net/udp's connect) and once as the host (the port
# forwarded to the guest: announce, and headers); then two guests, one
# that hosts and one that joins, joined by QEMU's socket network as
# two boards by a cable (each asks the other's Ethernet address: ARP
# between two mini-9pi's). Each says its ticks
# and whether the two games agree (the flag ticks=on); the guest's on
# its console, kept in $(B)/qemu-tron-*.txt. No recorded console: how
# many ticks are played in the time is the machine's.
IMAGE_IXT = $(basename $(IMAGE))-ixt$(suffix $(IMAGE))
QEMU_BOOT_IXT = $(subst $(IMAGE),$(IMAGE_IXT),$(QEMU_BOOT))
TRON = $(IX)/_mk/7/games/arcade/tinytronscroll
ix-tron: ix
	cd $(IX)/games/arcade && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null
	cd $(IX)/games/arcade && PATH=$(IX)/bin:$$PATH mini-mk O=7 > /dev/null
	$(MAKE) B=build/$(BOARD)$(PIX)-ixt IMAGE=$(IMAGE_IXT) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd tronscroll=$(IX9)/games/arcade/tinytronscroll" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXT)
check-tron: ix-tron
	mkdir -p $(B)
	tests/tron.sh $(B) $(TRON) join -- $(QEMU) $(QEMU_BOOT_IXT) $(USB) -device usb-net,netdev=n0 -netdev user,id=n0
	tests/tron.sh $(B) $(TRON) host -- $(QEMU) $(QEMU_BOOT_IXT) $(USB) -device usb-net,netdev=n0 -netdev user,id=n0,hostfwd=udp:127.0.0.1:7777-:7777
	tests/tron.sh $(B) $(TRON) pair -- $(QEMU) $(QEMU_BOOT_IXT) $(USB)
# the sound (plan_audio.md, stage 3): ix's image and tests/tone in its
# bootdir. check-audio: under mini-qemu alone (QEMU's Pi has no PWM),
# tests/session-audio.cmds: the tone written to /dev/audio, then again
# at half the volume; what the emulator's jack played (-audiodev wav,
# written when it ends) is tests/audio.py's to compare, sample by
# sample; the console as recorded (tests/session-audio). -ips 700: the
# emulator's board runs 30 million instructions a second of its own
# time unless told, a Pi 1 some 700; at 30 the first tone's writer was
# seen stopped a tenth of a second (by what, not looked into), the
# ring run empty and silence played in the tone's middle, as it should
IMAGE_IXA = $(basename $(IMAGE))-ixa$(suffix $(IMAGE))
BOOT_IXA = $(subst $(IMAGE),$(IMAGE_IXA),$(BOOT))
ix-audio: ix
	$(MAKE) B=build/$(BOARD)$(PIX)-ixa IMAGE=$(IMAGE_IXA) BOOTDIR="$(BOOTDIR_IX) tone=$(IX9)/kernels/9pi/tests/tone/tone" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXA)
check-audio: ix-audio
	rm -f $(B)/mini-audio.wav
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 300 --out $(B)/mini-audio.txt --lines tests/session-audio.cmds -- $(MINIQEMU) $(BOOT_IXA) -ips 700 -audiodev wav,path=$(B)/mini-audio.wav
	$(call unwarned,$(B)/mini-audio.txt) | diff - tests/session-audio && echo "ok 9pi: /dev/audio and /dev/volume, the console, under mini-qemu"
	tests/audio.py $(B)/mini-audio.wav
# a game's sound (plan_audio.md, stage 4), by hand (3 minutes: not
# check-all's): TinyMissileCommand's session "explosions" (95 frames,
# games/tests/audio.expected's) from the card, the platform that
# computes its pixels, its sound written a frame at a time to
# /dev/audio; mini-qemu's WAV against the same session's -dump-audio on
# Linux (dune's build), sample by sample. -ips 1000: at a Pi 1's 700
# the last explosion's frames are slower than the sound, and the ring
# runs empty once (the samples are then all there, 735 of them late)
GAME_AUDIO = -fixed-time 1000 -script space:1,up:2-30,a:32,s:33,d:34
check-audio-game: ix card
	mkdir -p $(B)
	rm -f $(B)/mini-game.wav
	../../_build/default/games/shmup/TinyMissileCommand.exe -dump-frame 95 $(B)/game.ppm -dump-audio $(B)/game-linux.wav $(GAME_AUDIO) seed=1
	printf "missile-soft -frames 95 -dump-audio /dev/audio $(GAME_AUDIO) 'seed=1'\nhello\nhello\n" > $(B)/game.cmds
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 600 --out $(B)/mini-game.txt --lines $(B)/game.cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD) -ips 1000 -audiodev wav,path=$(B)/mini-game.wav
	tests/audio.py $(B)/mini-game.wav --expect $(B)/game-linux.wav
# mini-play on the card (plan_audio.md, stage 5), by hand (3 minutes):
# a second of a MOD, of a MIDI file and of an MP3 (/lib/sounds), each
# played by play file; mini-qemu's WAV against mini-play's
# own output on Linux (dune's build) for the three, sample by sample,
# and /dev/audiostat after each (empty 0: the buffer never ran dry).
# -ips 1000, as check-audio-game
PLAY_SOUNDS = tune.mod=tiny_soundtracker.mod theme.mid=korobeiniki.mid mono.mp3=lsf_mono.mp3
check-audio-play: ix card
	mkdir -p $(B)
	rm -f $(B)/mini-play.wav $(B)/play.cmds
	for s in $(PLAY_SOUNDS); do \
	  ../../_build/default/apps/music/play/Play.exe -c -s 1 ../../lib_audio/tests/data/$${s#*=} > $(B)/play-$${s%=*}.pcm; \
	  printf "play -s 1 /lib/sounds/$${s%=*}\ncat /dev/audiostat\n" >> $(B)/play.cmds; done
	printf "hello\nhello\n" >> $(B)/play.cmds
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 900 --out $(B)/mini-play.txt --lines $(B)/play.cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD) -ips 1000 -audiodev wav,path=$(B)/mini-play.wav
	@! grep -a '^bufsize' $(B)/mini-play.txt | grep -v 'empty 0$$' || { echo "FAIL 9pi: mini-play: the buffer ran empty"; exit 1; }
	tests/audio.py $(B)/mini-play.wav --expect $(foreach s,$(PLAY_SOUNDS),$(B)/play-$(firstword $(subst =, ,$(s))).pcm)
# for a page (plan_web.md, stage 2; docs/m-ix.html): ix-usb's image
# built with WEB=1 (lib_machine/web/host.s: the bytes moved and filled
# by mini-qemu's board itself). For mini-qemu only: not QEMU, not a Pi.
# Its collector's young generation is 2M words (8 MB) where the Pi's is
# 256k, and the old one's work is done at 400% of what lives: on an
# emulator an instruction costs and memory does not. To rc's prompt
# under mini-qemu, 386 million instructions (ix-usb), 244 with
# WEB=1's moves, 125 with these (raspberry/tests/boot_bench.sh).
WEB_GC = s=2M,o=400
IMAGE_WEB = $(basename $(IMAGE))-web$(suffix $(IMAGE))
ix-web: ix
	$(MAKE) WEB=1 CAMLRUNPARAM=$(WEB_GC) B=build/$(BOARD)$(PIX)-web IMAGE=$(IMAGE_WEB) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd" KERNDATE=$(KERNDATE_IX) $(IMAGE_WEB)
# with neither usbd nor dossrv in its bootdir: the keyboard, the mouse
# and the card's FAT by the kernel itself (Kusb, Kdos: boot.rc falls
# back to them), for check-card's last session
IMAGE_IXK = $(basename $(IMAGE))-ixk$(suffix $(IMAGE))
BOOT_IXK = $(subst $(IMAGE),$(IMAGE_IXK),$(BOOT))
QEMU_BOOT_IXK = $(subst $(IMAGE),$(IMAGE_IXK),$(QEMU_BOOT))
ix-kernel: ix
	$(MAKE) B=build/$(BOARD)$(PIX)-ixk IMAGE=$(IMAGE_IXK) BOOTDIR="$(filter-out dossrv=%,$(BOOTDIR_IX))" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXK)
run-ix: ix
	$(MINIQEMU) $(BOOT_IX)
# (the sessions of a check all at once, each its own emulator, then
# their consoles compared: the card is given to each as a snapshot. And
# ix's own, of many lines: a line typed 0.3 s after a prompt, not 1 s)
IXQUIET = --quiet 0.3
# No page left (docs/plans/bugs/ix.md, 2026-10-10): six programs at
# once ask for more than the board has (tests/hog: up to 128 MB each
# of the 352 the kernel gives processes under QEMU, 192 when this was
# written: three were ended then, one now). The kernel ends those it cannot serve, by a
# note, and goes on: the shell answers after, a program runs. Which
# end is the scheduler's: the console is not compared, only that one
# was ended, that the lines after are there and that none is a panic.
check-hog: ix
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 120 --out $(B)/qemu-hog.txt --lines tests/session-hog.cmds -- $(QEMU) $(QEMU_BOOT_IX) || true
	@! grep -a panic $(B)/qemu-hog.txt && grep -a -q 'virtual memory' $(B)/qemu-hog.txt && grep -a -q '^still here' $(B)/qemu-hog.txt && grep -a -q '^hello from OCaml' $(B)/qemu-hog.txt \
	  && echo "ok 9pi: no page left: the processes ended ($$(grep -a -c 'virtual memory' $(B)/qemu-hog.txt) notes), the kernel goes on, under QEMU" \
	  || { echo "FAIL 9pi: no page left"; tail -5 $(B)/qemu-hog.txt; exit 1; }
# Several cores (docs/plans/plan_multicore.md): the Pi 2's kernel built
# so that the other cores run processes under an emulator too (SMP=1:
# the recorded sessions are one core's), under QEMU, which has the
# four. Four shells that compute, then four that start processes
# (pipes of three, fifty each), at once; then the threads and hello.
# Whose line comes first is the scheduler's: the lines are counted,
# not compared. (runtime.o says which kernel it is: made again before
# and after, the image kept aside.)
check-cores:
	rm -f build/pi2$(PIX)-ix/c/runtime.o
	$(MAKE) ix BOARD=pi2 SMP=1 > /dev/null
	cp kernel-pi2-ix.img build/kernel-pi2-smp.img
	rm -f build/pi2$(PIX)-ix/c/runtime.o
	$(MAKE) ix BOARD=pi2 > /dev/null
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 300 --out build/qemu-cores.txt --lines tests/session-cores.cmds -- $(QEMU) $(subst kernel-$(BOARD)-ix.img,build/kernel-pi2-smp.img,$(QEMU_BOOT_IX)) || true
	@o=build/qemu-cores.txt; ! grep -a 'panic\|kernel fault' $$o && grep -a -q '(4 cores)' $$o \
	  && [ $$(grep -a -c '^worked [abcd]' $$o) = 4 ] && [ $$(grep -a -c '^churned [abcd]' $$o) = 4 ] \
	  && grep -a -q '^done churn' $$o && grep -a -q '^200 threads ended' $$o && grep -a -q '^hello from OCaml' $$o \
	  && echo "ok 9pi: four cores: processes that compute and that start others at once, under QEMU" \
	  || { echo "FAIL 9pi: four cores"; tail -5 $$o; exit 1; }
check-ix: ix
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 120 --out $(B)/mini-ix.txt --lines tests/session-ix.cmds -- $(MINIQEMU) $(BOOT_IX) & \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 60 --out $(B)/qemu-ix.txt --lines tests/session-ix.cmds -- $(QEMU) $(QEMU_BOOT_IX) & \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 180 --out $(B)/mini-ix-b.txt --lines tests/session-ix-b.cmds -- $(MINIQEMU) $(BOOT_IX) & \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 60 --out $(B)/qemu-ix-b.txt --lines tests/session-ix-b.cmds -- $(QEMU) $(QEMU_BOOT_IX) & \
	wait
	$(call unwarned,$(B)/mini-ix.txt) | diff - tests/session-ix && echo "ok 9pi: ix's own programs (mini-rc, mini-ed, hello) under mini-qemu"
	$(call unwarned,$(B)/qemu-ix.txt) | diff - tests/session-ix && echo "ok 9pi: ix's own programs under QEMU"
	$(call unwarned,$(B)/mini-ix-b.txt) | diff - tests/session-ix-b && echo "ok 9pi: stage B's session with ix's own programs, under mini-qemu"
	$(call unwarned,$(B)/qemu-ix-b.txt) | diff - tests/session-ix-b && echo "ok 9pi: stage B's session with ix's own programs, under QEMU"

# The graphical checks of ix's own programs (plan_rio.md, stage 7): each
# a short session in the image of make ix-usb (hellodraw: of make ix),
# under mini-qemu and under QEMU, its screens compared with those
# recorded (mini-qemu's). tests/graphics.py drives them with QEMU's USB
# keyboard and mouse, by steps (tests/NAME.steps, tests/NAME.md5; not
# rio-NAME: tests/rio-c.md5 is the C rio's screens, make check's):
#
#   draw      hellodraw (../../lib_graphics/tests): the display opened, a
#             colour, a thick line, text in Plan 9's default font
#             (tests/hellodraw.ppm.gz: one screen, no steps)
#   menu      hellomenu (the same directory): the mouse, the keyboard, a
#             menu shown, an item chosen, a key typed, "exit"
#   win-new      mini-rio (../../windows): rio started at the console, its
#             menu, New (the cursor a cross), a rectangle swept out (seen
#             half-way), a command in the window (mini-rc's answer
#             there), hellorio in it (a program that draws), q, rc again
#   win-ops      a window moved, hidden and brought back by its name, made
#             another size, a command typed after each
#   win-border   a window's border as a handle: the cursor of a corner
#             (the mouse on it), the corner pulled with the left button
#             (seen half-way), the window pulled by its top with the right
#             one, its left side with the middle one, a command after each
#   win-scroll   24 lines written, the arrows (scrolling back), the three
#             buttons in the scroll bar, a command (the end again)
#   win-select  a word of the text swept with the left button (marked), the
#             middle button's menu: snarf, then send (the word typed to rc);
#             /dev/snarf read (cat), and written: sent again
#   win-utf8    a text that is not ASCII's (tests/words.txt, in /boot): shown (a
#             mark for the characters the font has not), a word of it
#             selected, pasted, two characters taken back
#   win-files  a window's other files and the double click: what is in
#             brackets, then a word, selected by two clicks; winid and
#             label read, label written (the hidden window's name in
#             the menu), text read; hellorio's own cursor (its key c)
#             while the mouse is in its window. make check-files, not
#             among check-windows' yet: recorded under QEMU, and not
#             run under mini-qemu (its clicks are 0.1 second apart)
#   win-wctl   a window that does not scroll (the middle menu's
#             noscroll: seq 1 30 stops when it is full, the down arrow
#             shows more), then its wctl file: scroll, read, resize,
#             move, new with a command, bottom and top, hide, unhide
#             and delete by -id; its files at /mnt/wsys and by $wsys
#             (mounted elsewhere); the sizes of /dev/screen and
#             /dev/window. With win-files in make check-files
#   colors-bare  mini-colors (../../apps/misc) on the bare screen:
#             a square pointed at, its menu's exit
#   colors-win   the same program in a window of mini-rio's, which is moved
#             and made another size: it draws again
#   tetris-bare  the playground's Tetris (../../games/puzzle, plan_playground.md)
#             on the bare screen: a session of 400 frames played at once
#             by a script of keys (-frames, -script), its last picture,
#             drawn by the program and given to the draw device whole
#             (tetris-soft: the platform that computes its pixels)
#   tetris-win   the same in a window of mini-rio's, which is made
#             another size: the picture is drawn again, at that size
#   kbd-bare  the keys held (#c/kbd: plan_playground.md, stage 4), by
#             hellokbd (../../lib_graphics/tests): keys pressed and
#             released, one held a second and a half, each change a line
#   kbd-win   the same in a window of mini-rio's, by the window's own kbd
#   draw-tetris  Tetris by the platform that asks the draw device for
#             each shape (lib_playground/platforms/draw: rectangles
#             filled, words as lines; the games' own, tetris), the same
#             session as tetris-bare
#   draw-wolf    TinyWolfenstein by it: the playground's scene of a walk
#             to a treasure (keys held by the script), 200 columns
#   drscheme-bare  mini-drscheme (../../editors/drscheme, plan_scheme.md's
#             stage 4) on the bare screen, by the mouse: Execute clicked
#             (120, three discs, the rocket's world run to its end), two
#             lines typed at the prompt (a list, car's error), Step
#             clicked and the stepper's Step twice. fps=off: no frames a
#             second written, the screen still when the program waits
#   drscheme-win   the same in a window of mini-rio's
#             (not in check-windows: make check-drscheme)
#   office-bare  mini-office (../../apps/office, plan_office.md's stage
#             5) on the bare screen: its start screen, Document
#             clicked, a line typed in its text. Under QEMU only
#             (make check-office): a page of text drawn stroke by
#             stroke is slow, its speed not measured yet
#
#   make check-windows   all of them, side by side (15 emulators, a core
#                        each): what one waits for is the longest
#   make check-draw, check-menu, check-rio, check-colors, check-tetris   a part of them
#   make check-quick     five of them under QEMU only, a minute
#   make expected-windows   their screens recorded again (under QEMU, seven minutes),
#                        side by side; expected-NAME: one of them
#
# A session that shows another screen than the one recorded stops
# there (graphics.py), after a minute's wait for it: what follows would
# be typed at the wrong place. The steps' pauses (GFX_PAUSE: after a
# key, after a button's change) are shorter than the C rio's check's
# (0.5 and 2 seconds); 0.2 a key lost one once under QEMU.
GFX_PAUSE = 0.3,1
# (not GFX: that is principia's lib_graphics, for the C pixels above)
GRAPHICS = tests/graphics.py --step 3 --pause $(GFX_PAUSE)
# (with the card: mini-rio and the programs of its windows are on its
# second partition, not in the kernel's image)
MENU_USB = -serial mon:stdio -display none $(USB) $(CARD_SD)
# (KUSB=1: the image without usbd, where the kernel finds and reads the
# keyboard and the mouse itself, Kusb: make check-windows-kernel)
MINI_USB = $(MINIQEMU) $(subst -nographic,,$(if $(KUSB),$(BOOT_IX),$(BOOT_IXU))) $(MENU_USB)
QEMU_USB = $(QEMU) $(subst -nographic,,$(if $(KUSB),$(QEMU_BOOT_IX),$(QEMU_BOOT_IXU))) $(MENU_USB)
DRAW = $(SESSION_PY) --prompt "% " --timeout 180 --out $(B)/$(1)-draw.txt --screendump $(B)/$(1)-draw.ppm hellodraw --
GSESSIONS = menu win-new win-ops win-border win-scroll win-select win-utf8 colors-bare colors-win tetris-bare tetris-win kbd-bare kbd-win draw-tetris draw-wolf

# a session (no build: the images are there), and what it wrote against what is recorded
run-draw-mini: ; $(call DRAW,mini) $(MINIQEMU) $(BOOT_IX)
run-draw-qemu: ; $(call DRAW,qemu) $(QEMU) $(QEMU_BOOT_IX)
run-%-mini: ; rm -rf $(B)/g-$*-mini; $(GRAPHICS) --steps tests/$*.steps --expect tests/$*.md5 $(B)/g-$*-mini -- $(MINI_USB)
run-%-qemu: ; rm -rf $(B)/g-$*-qemu; $(GRAPHICS) --steps tests/$*.steps --expect tests/$*.md5 $(B)/g-$*-qemu -- $(QEMU_USB)
cmp-draw:
	gzip -dc tests/hellodraw.ppm.gz | cmp - $(B)/mini-draw.ppm && echo "ok 9pi: draw: hellodraw's screen under mini-qemu"
	gzip -dc tests/hellodraw.ppm.gz | cmp - $(B)/qemu-draw.ppm && echo "ok 9pi: draw: the same screen under QEMU"
cmp-%:
	cd $(B)/g-$*-mini && md5sum --quiet -c $(CURDIR)/tests/$*.md5 && echo "ok 9pi: $*: its $$(wc -l < $(CURDIR)/tests/$*.md5) screens under mini-qemu"
	cd $(B)/g-$*-qemu && md5sum --quiet -c $(CURDIR)/tests/$*.md5 && echo "ok 9pi: $*: the same screens under QEMU"
# (recorded: the screens of a session without --expect, each one still for three steps.
# Under QEMU, whose screens are mini-qemu's (the checks hold them to it):
# a boot is 5 seconds there for 27, and a step may be 4 seconds where
# mini-qemu's had to be 8, its boot standing still for more than 9
# before its prompt: 12 seconds a screen, not 24; the 17 sessions,
# drscheme's two with them, are 7 minutes where 15 were 17 (the author: "this is
# slow, any way we can improve the speed of those tests?").
# old: under mini-qemu, 17 minutes for the 15 sessions:
#	$(subst --step 3,--step 8,$(GRAPHICS)) --steps tests/$*.steps $(B)/g-$*-mini -- $(MINI_USB))
expected-%: ix-usb card
	rm -rf $(B)/g-$*-qemu
	$(subst --step 3,--step 4,$(GRAPHICS)) --steps tests/$*.steps $(B)/g-$*-qemu -- $(QEMU_USB)
	cd $(B)/g-$*-qemu && md5sum boot.ppm $$(ls step*.ppm | sort -V) > $(CURDIR)/tests/$*.md5
expected-draw: ix
	$(call DRAW,mini) $(MINIQEMU) $(BOOT_IX)
	gzip -n -9 < $(B)/mini-draw.ppm > tests/hellodraw.ppm.gz
expected-windows: ix-usb card
	$(MAKE) --no-print-directory -j$(GJOBS) $(GSESSIONS:%=expected-%) expected-drscheme-bare expected-drscheme-win

# devices unplugged and plugged again while mini-usbd runs (stage 2 of
# plan_rio.md's USB): the mouse and the keyboard taken out (QMP's
# device_del, by their ids), others put in (device_add), rio started
# with them, its menu; with mini-usbd, then with the kernel's own USB.
# Under QEMU only: mini-qemu has no device_add yet.
QEMU_PLUG = $(QEMU) $(subst -nographic,,$(QEMU_BOOT_IXU)) -serial mon:stdio -display none -device usb-kbd,id=kbd -device usb-mouse,id=mouse $(CARD_SD)
expected-plug: ix-usb
	rm -rf $(B)/g-plug
	$(GRAPHICS) --steps tests/usb-plug.steps $(B)/g-plug -- $(QEMU_PLUG)
	cd $(B)/g-plug && md5sum boot.ppm $$(ls step*.ppm | sort -V) > $(CURDIR)/tests/usb-plug.md5
check-plug: ix-usb card
	rm -rf $(B)/g-plug
	$(GRAPHICS) --steps tests/usb-plug.steps --expect tests/usb-plug.md5 $(B)/g-plug -- $(QEMU_PLUG)
	cd $(B)/g-plug && md5sum --quiet -c $(CURDIR)/tests/usb-plug.md5 && echo "ok 9pi: plug: a keyboard and a mouse unplugged, plugged again, used ($$(wc -l < $(CURDIR)/tests/usb-plug.md5) screens under QEMU)"
	rm -rf $(B)/g-plug-kernel
	$(GRAPHICS) --steps tests/usb-plug.steps --expect tests/usb-plug.md5 $(B)/g-plug-kernel -- $(subst $(IMAGE_IXU),$(IMAGE_IX),$(QEMU_PLUG))
	cd $(B)/g-plug-kernel && md5sum --quiet -c $(CURDIR)/tests/usb-plug.md5 && echo "ok 9pi: plug: the same screens with the kernel's own USB (Kusb, its process that looks at the ports)"

# every build and every check of this directory, one after the other,
# stopped at the first that fails: "all the checks pass" is this
# target's exit status (plan_rio.md, 2026-10-06: three builds had been
# broken for a day, each by a change checked with the checks one
# remembered to run). Some 10 minutes. The graphical sessions are tried
# a second time when one fails: 16 emulators side by side lose a key
# or a screen on a busy machine (a load of 45 that day: win-utf8 failed
# once, and passed twice alone).
#   the two pixels (PIXEL=c, then the default again: one image file)
#   check                 the twin's: 9pi's console and screens
#   check-ix check-card   ix's programs; the card (dossrv, Kdos)
#   check-audio           /dev/audio: what mini-qemu's jack played
#   check-windows         the graphical sessions, with mini-usbd
#   check-windows-kernel  the same with the kernel's own USB (Kusb)
#   check-plug            devices unplugged and plugged (QEMU)
#   mini-mk check         the kernel built by ix's tools (the Pi4's)
check-all:
	$(MAKE) --no-print-directory PIXEL=c
	$(MAKE) --no-print-directory
	$(MAKE) --no-print-directory check
	$(MAKE) --no-print-directory check-ix
	$(MAKE) --no-print-directory check-audio
	$(MAKE) --no-print-directory check-card
	$(MAKE) --no-print-directory check-windows || { echo "check-windows: a second try, 4 emulators at once"; $(MAKE) --no-print-directory GJOBS=4 check-windows; }
	$(MAKE) --no-print-directory check-windows-kernel || { echo "check-windows-kernel: a second try, 4 emulators at once"; $(MAKE) --no-print-directory GJOBS=4 check-windows-kernel; }
	$(MAKE) --no-print-directory check-plug
	PATH=$(IX)/bin:$$PATH NPROC=8 mini-mk check
	@echo "ok 9pi: every build and every check"
.PHONY: check-all

# some of them, side by side: their sessions, then the comparisons (all said, -k)
# (GJOBS: how many emulators at once)
GJOBS ?= 16
gcheck = $(MAKE) --no-print-directory -j$(GJOBS) $(foreach s,$(1),run-$(s)-mini run-$(s)-qemu); $(MAKE) --no-print-directory -k $(foreach s,$(1),cmp-$(s))
check-draw: ix ; $(call gcheck,draw)
check-menu: ix-usb card ; $(call gcheck,menu)
check-rio: ix-usb card ; $(call gcheck,win-new win-ops win-border win-scroll win-select win-utf8)
check-files: ix-usb card ; $(call gcheck,win-files win-wctl)
check-colors: ix-usb card ; $(call gcheck,colors-bare colors-win)
check-tetris: ix-usb card ; $(call gcheck,tetris-bare tetris-win)
check-kbd: ix-usb card ; $(call gcheck,kbd-bare kbd-win)
check-games-draw: ix-usb card ; $(call gcheck,draw-tetris draw-wolf)
check-drscheme: ix-usb card ; $(call gcheck,drscheme-bare drscheme-win)
#   turbopascal-bare  mini-turbopascal (../../editors/turbopascal,
#             plan_pascal.md's stage 6) on the bare screen, 51 rows of 113
#             cells of Plan 9's font: F10's menu, Escape, PageDown,
#             Control-F9 (the queens on the user screen), a key, a
#             letter typed, F9's error in the red bar
#   turbopascal-win   the same in a window of mini-rio's: the menu, a
#             run, then the window made smaller from rio's menu (14
#             rows of 42), PageDown, F7 and F8 (the execution bar).
#             Under QEMU only (make check-turbopascal)
check-turbopascal: ix-usb card
	$(MAKE) --no-print-directory -j2 run-turbopascal-bare-qemu run-turbopascal-win-qemu; $(MAKE) --no-print-directory -k cmpq-turbopascal-bare cmpq-turbopascal-win
check-office: ix-usb card
	$(MAKE) --no-print-directory run-office-bare-qemu; $(MAKE) --no-print-directory cmpq-office-bare
# A few of them under QEMU only, a minute: what one runs while
# changing something (the menu, a window of mini-rio's, the keys held,
# a game by the draw device, mini-drscheme on the bare screen); the
# whole of it is check-windows and check-drscheme, with mini-qemu.
GQUICK = menu win-new kbd-bare draw-wolf drscheme-bare
check-quick: ix-usb card
	$(MAKE) --no-print-directory -j$(GJOBS) $(GQUICK:%=run-%-qemu); $(MAKE) --no-print-directory -k $(GQUICK:%=cmpq-%)
cmpq-%:
	cd $(B)/g-$*-qemu && md5sum --quiet -c $(CURDIR)/tests/$*.md5 && echo "ok 9pi: $*: its $$(wc -l < $(CURDIR)/tests/$*.md5) screens under QEMU"
check-windows: ix-usb card ; $(call gcheck,draw $(GSESSIONS))
# the same sessions, the same screens, with no usbd: the kernel's own USB (Kusb)
check-windows-kernel: ix card ; $(MAKE) --no-print-directory KUSB=1 GJOBS=$(GJOBS) gcheck-all
gcheck-all: ; $(call gcheck,$(GSESSIONS))
.PHONY: check-drscheme check-office check-turbopascal check-quick check-windows expected-windows cmp-draw run-draw-mini run-draw-qemu

# The SD card (plan_rio.md, stage 3): make card, build/card.img, by
# mini-mkcard (../tools): an MBR, a FAT16 with the Pi 1's and the Pi 2's
# firmware (../firmware), conf/config.txt and the images of make ix for
# the two boards (the firmware loads its board's), and a second
# partition, empty (the kernel's own file system's place: stage 6).
# Written to a real card: dd if=build/card.img of=/dev/sdX bs=1M.
#   make check-card  the card read by the host's tools (its partitions,
#                    the FAT checked, the kernel read back), then by
#                    principia's (fdisk, dossrv: tests/boot-card.rc as
#                    /boot/boot, tests/session-card.cmds) under
#                    mini-qemu and QEMU, the console as tests/session-card;
#                    then by ix's own: mini-dossrv (filesystems/user/dossrv) in
#                    the image of make ix, whose conf/boot.rc mounts the
#                    card (mini-fdisk, mini-dossrv: tests/session-card-ix.cmds,
#                    tests/session-card-ix), then the same files by the
#                    kernel itself (Kdos: bind '#Fdos' /mnt)
CARD = build/card.img
# (the kernel's image on the card changes size with every program in
# it: its size is not compared, nor the listing's columns, which it widens)
cardsize = sed -E -e 's/ +/ /g' -e 's/ [0-9]+ (Sep 26 (2026|00:MM) [a-z\/]*\/(MINI9PI1\.IMG|mini9pi1\.img))/ SIZE \1/'
MKCARD = ../../_build/default/kernels/tools/Mkcard.exe
FIRMWARE = ../firmware/pi1-pi2
CARD_SD = -drive file=$(CARD),if=sd,format=raw,snapshot=on
card: ix
	$(MAKE) BOARD=pi2 ix
	$(MAKE) $(CARD)
	@$(if $(filter card,$(MAKECMDGOALS)),$(cardhelp))
# what make card says last (not when card is another target's
# prerequisite): where the image is and how it gets on a card. The
# device is the reader's to find: a wrong one is a disk erased
define cardhelp
echo; echo "the card's image: $(abspath $(CARD)) ($(CARD_MB) MB)"; \
echo "to write it on an SD card (all of the card is replaced):"; \
if [ "$$(uname)" = Darwin ]; then \
  echo "  diskutil list                      # which disk is the card: diskN"; \
  echo "  diskutil unmountDisk /dev/diskN"; \
  echo "  sudo dd if=$(abspath $(CARD)) of=/dev/rdiskN bs=1m"; \
else \
  echo "  lsblk -d -o NAME,SIZE,MODEL,TRAN   # which disk is the card: sdX, or mmcblkN"; \
  echo "  sudo dd if=$(abspath $(CARD)) of=/dev/sdX bs=1M conv=fsync status=progress"; \
fi
endef
# the second partition: xv6's file system (mini-mkfs, lib_xv6fs's: the
# kernel's Kfs reads and writes it), the system's root (boot.rc: /root,
# and after the kernel's own directories at /), laid out as Plan 9's:
#   progs      the programs that are not in the kernel's image, a
#              directory for each kind, to browse them as the sources
#              are (the author: "/progs/apps/ /progs/games/
#              /progs/utilities/ so less category otherwise we can get
#              one folder for each program"; "we could have a /progs/system/
#              and put rio, free inside it";
#              "as soon as one directory contain more than 10 programs,
#              then we can further refine in extra subfolders", "but
#              let's try avoid having folders with just one program"),
#              each bound after /bin, which has them all (boot.rc,
#              by the card's /lib/namespace, written below):
#                system     the window system and what shows the
#                           system's state: rio, ps, free
#                apps       what a person opens: colors, stats, office, page
#                devtools   the editors and the languages that are run
#                           ("like we have for the book category" of
#                           principia-softwarica.org: its Developer
#                           tools): emacs, drscheme, turbopascal,
#                           squeak, scheme, pascal, prolog
#                games      tetris, wolfenstein, cameltry, breakout, tronscroll
#                           (for two boards: its network), and their
#                           -soft variants
#                net        mini-netscape and the networking programs
#                           ("we could have /progs/net/ and put the
#                           mini-netscape in it at some point"):
#                           netscape, lynx, curl, timesync
#                utilities  utilities/'s, in its directories (a
#                           directory with more than ten programs is
#                           cut further; none for one program: cmp,
#                           unmount and xd are in misc): files, text,
#                           pipe, process, calc, time (date and cal: with
#                           cal, misc would be eleven), misc
#                examples   hello, hellorio, hellokbd, tone (half a
#                           second for /dev/audio: tone > /dev/audio)
#              and, when they are on the card, toolchain: the
#              assembler, the linker, the compilers ("I was thinking of
#              /progs/toolchain actually for mini-asm, mini-ld, etc.";
#              plan_self_hosting.md)
#              (old: all of them in bin/arm, Plan 9's place)
#   rc/bin     the commands that are scripts (kill), bound after it too
#   usr/pad    a user's directory, where the shell starts
#   mnt/fat    where the card's first partition, the firmware's FAT, is
#              mounted
#   mnt/wsys   where a window's process mounts its window's files
#              (mini-rio's, as rio's), bound before /dev
#   lib        a language's files (scheme's queens.scm, pascal's
#              types.pas, which does not compile, prolog's
#              classics.pl: check-scheme, check-pascal,
#              check-prolog); and three small PDF files
#              for page (page /lib/pdf/tex.pdf: two pages of pdfTeX's;
#              docs/plans/done/plan_pdf.md, C2)
#              and the manual, /lib/man/1 (man troff: mini-man's
#              place when there is no /sys/man; ix's own pages,
#              docs/man, written in the new format), with troff's
#              page as a PDF file too (/lib/pdf/troff.pdf;
#              docs/plans/plan_typesetting.md, stage 8)
#              and six small files of sound for play (/lib/sounds:
#              a MOD, a MIDI file, an ABC tune, two MP3s, an MP2:
#              lib_audio/tests/data's; play /lib/sounds/tune.mod:
#              docs/plans/plan_audio.md, stage 5)
#              and the roots a certificate is checked against
#              (/lib/tls/ca.pem: this machine's, Tls_client's place on
#              a card), for https:// in netscape, lynx and curl
#   usr/pad/lib/documents  the store of documents (mini-office's Open and
#              Save), with two pictures for its Insert > Image...
#              (a PNG, a JPEG: docs/plans/plan_office.md, stage 7)
#   src        sources: for now five small programs, OCaml's hello.ml,
#              hellodraw.ml and hellorio.ml (three programs of the
#              card), C's hello.c, the assembler's hello.s: texts to
#              open (emacs /src/hello.ml)
#   tmp
CARD_apps = colors=$(IX9)/apps/misc/mini-colors stats=$(IX9)/apps/misc/mini-stats office=$(IX9)/apps/office/office page=$(IX9)/apps/page/pageview play=$(IX9)/apps/music/play/mini-play rebirth=$(IX9)/apps/music/rebirth/rebirth
CARD_system = rio=$(IX9)/windows/mini-rio ps=$(IX9)/utilities/process/mini-ps free=$(IX9)/utilities/process/mini-free
CARD_devtools = emacs=$(IX9)/editors/emacs/draw/emacs drscheme=$(IX9)/editors/drscheme/drscheme turbopascal=$(IX9)/editors/turbopascal/hosts/draw/turbopascal \
  squeak=$(IX9)/languages/smalltalk/hosts/draw/squeak scheme=$(IX9)/languages/scheme/mini-scheme pascal=$(IX9)/languages/pascal/mini-pascal \
  prolog=$(IX9)/languages/prolog/mini-prolog
CARD_games = tetris=$(IX9)/games/puzzle/tetris missilecommand=$(IX9)/games/shmup/tinymissilecommand missile-soft=$(IX9)/games/shmup-soft/tinymissilecommand wolfenstein=$(IX9)/games/fps/tinywolfenstein tetris-soft=$(IX9)/games/puzzle-soft/tetris \
  wolf-soft=$(IX9)/games/fps-soft/tinywolfenstein cameltry=$(IX9)/games/arcade/tinycameltry camel-soft=$(IX9)/games/arcade-soft/tinycameltry breakout=$(IX9)/games/arcade/tinybreakout break-soft=$(IX9)/games/arcade-soft/tinybreakout tronscroll=$(IX9)/games/arcade/tinytronscroll
CARD_utilities/files = pwd=$(IX9)/utilities/files/mini-pwd mkdir=$(IX9)/utilities/files/mini-mkdir rm=$(IX9)/utilities/files/mini-rm \
  cp=$(IX9)/utilities/files/mini-cp mv=$(IX9)/utilities/files/mini-mv touch=$(IX9)/utilities/files/mini-touch chmod=$(IX9)/utilities/files/mini-chmod \
  mtime=$(IX9)/utilities/files/mini-mtime walk=$(IX9)/utilities/files/mini-walk
CARD_utilities/text = grep=$(IX9)/utilities/text/mini-grep uniq=$(IX9)/utilities/text/mini-uniq tr=$(IX9)/utilities/text/mini-tr \
  sed=$(IX9)/utilities/text/mini-sed sort=$(IX9)/utilities/text/mini-sort awk=$(IX9)/utilities/text/awk/mini-awk
CARD_utilities/pipe = tee=$(IX9)/utilities/pipe/mini-tee tail=$(IX9)/utilities/pipe/mini-tail xargs=$(IX9)/utilities/pipe/mini-xargs
CARD_utilities/process = sleep=$(IX9)/utilities/process/mini-sleep spin=$(IX9)/utilities/process/mini-spin time=$(IX9)/utilities/process/mini-time
CARD_utilities/calc = hoc=$(IX9)/utilities/calc/hoc/mini-hoc dc=$(IX9)/utilities/calc/dc/mini-dc bc=$(IX9)/utilities/calc/bc/mini-bc
CARD_utilities/time = date=$(IX9)/utilities/time/mini-date cal=$(IX9)/utilities/time/mini-cal
CARD_utilities/misc = wc=$(IX9)/utilities/misc/mini-wc basename=$(IX9)/utilities/misc/mini-basename \
  cmp=$(IX9)/utilities/compare/mini-cmp unmount=$(IX9)/utilities/namespace/mini-unmount seq=$(IX9)/utilities/misc/mini-seq \
  cleanname=$(IX9)/utilities/misc/mini-cleanname du=$(IX9)/utilities/misc/mini-du xd=$(IX9)/utilities/byte/mini-xd test=$(IX9)/utilities/misc/mini-test
CARD_examples = hellorio=$(IX9)/windows/tests/hellorio hellokbd=$(IX9)/lib_graphics/tests/hellokbd hello=$(IX9)/kernels/9pi/tests/hello/hello tone=$(IX9)/kernels/9pi/tests/tone/tone
# the typesetter and the manual (docs/plans/plan_typesetting.md, stage 8)
CARD_typesetting = troff=$(IX9)/typesetting/troff/mini-troff man=$(IX9)/typesetting/man/mini-man
# the browsers and the network's programs (plan_browser.md, stage 10)
CARD_net = netscape=$(IX9)/browsers/netscape/netscape lynx=$(IX9)/browsers/lynx/mini-lynx curl=$(IX9)/networking/mini-curl timesync=$(IX9)/networking/mini-timesync
CARD_PROGS = system apps devtools games net utilities/files utilities/text utilities/pipe utilities/process utilities/calc utilities/time utilities/misc typesetting examples
CARD_BIN = $(foreach d,$(CARD_PROGS),$(CARD_$(d)))
card_progs = $(foreach d,$(CARD_PROGS),$(addprefix progs/$(d)/,$(CARD_$(d))))
MKFS = ../../_build/default/kernels/tools/Mkfs.exe
# the card's megabytes (a power of 2: QEMU's wish) and its second
# partition's, what the FAT's 32 and the first megabyte leave. It was 64
# and 31, and full at 43 programs (2026-10-07: a program of ix's is 0.7
# to 1.2 MB, its library linked whole); a real card is gigabytes.
CARD_MB = 128
CARD_FS_MB = 95
CARD_FS = build/card-fs.img
# its files and directories, at most: xv6's 200 were full at the
# manual's 93 pages (2026-10-14)
CARD_FS_INODES = 1024
# the manual's pages, ix's own (docs/man/1), named without their .md
# as Plan 9's are; not turbopascal-tty's, a name longer than the card's
# file system takes (14 letters), of a program not on the card
CARD_MAN = $(foreach f,$(filter-out %/turbopascal-tty.md,$(wildcard ../../docs/man/1/*.md)),lib/man/1/$(basename $(notdir $(f)))=$(f))
CARD_LIB = lib/scheme/queens.scm=../../languages/scheme/tests/queens.scm lib/pascal/types.pas=../../languages/pascal/tests/types.pas \
  lib/prolog/classics.pl=../../languages/prolog/tests/classics.pl \
  $(CARD_MAN) lib/pdf/troff.pdf=$(TROFF_PDF) \
  lib/pdf/tex.pdf=../../lib_graphics/pdf/tests/data/tex.pdf lib/pdf/shapes.pdf=../../lib_graphics/pdf/tests/data/shapes.pdf lib/pdf/standard.pdf=../../lib_graphics/pdf/tests/data/standard.pdf \
  lib/sounds/tune.mod=../../lib_audio/tests/data/tiny_soundtracker.mod lib/sounds/theme.mid=../../lib_audio/tests/data/korobeiniki.mid lib/sounds/theme.abc=../../lib_audio/tests/data/korobeiniki.abc \
  lib/sounds/mono.mp3=../../lib_audio/tests/data/lsf_mono.mp3 lib/sounds/stereo.mp3=../../lib_audio/tests/data/lame_encoded.mp3 lib/sounds/bell.mp2=../../lib_audio/tests/data/bell.mp2 \
  lib/tls/ca.pem=$(CA_PEM) \
  usr/pad/lib/documents/shapes.png=../../lib_graphics/pdf/tests/data/shapes-1.png usr/pad/lib/documents/aldrin.jpg=../../apps/office/pictures/aldrin.jpg
# a first /src: small programs in the languages ix is written in, to
# open with emacs for now (docs/plans/plan_self_hosting.md: ix's sources
# on the card, and ix built from them there, later)
CARD_SRC = src/hello.ml=tests/hello/Hello.ml src/hellodraw.ml=../../lib_graphics/tests/Hellodraw.ml src/hellorio.ml=../../windows/tests/Hellorio.ml \
  src/hello.c=../steps/step0/hello.c src/hello.s=../../linker/tests/golden/hello_plan9_arm.s
# the binds that make /bin of them, one for each directory: the card's
# /lib/namespace, lines of rc that boot.rc reads (Plan 9's file of that
# name is its own format, read by newns)
CARD_NS = build/card-namespace
# troff's own page as a PDF file, by the host's mini-troff: for page
# (page /lib/pdf/troff.pdf), and what the card's troff must write too,
# byte for byte (tests/session-card-typeset.cmds: cmp)
TROFF_PDF = build/troff.pdf
$(TROFF_PDF): ../../docs/man/1/troff.md ../../_build/default/typesetting/troff/Main.exe
	@mkdir -p build
	../../_build/default/typesetting/troff/Main.exe -T pdf ../../docs/man/1/troff.md > $@
$(CARD_NS): Makefile
	@mkdir -p build
	for d in $(CARD_PROGS); do echo "bind -a /root/progs/$$d /bin"; done > $@
$(CARD_FS): Makefile $(MKFS) $(CARD_NS) tests/card-motd.txt ../../utilities/process/kill.rc $(foreach p,$(CARD_LIB) $(CARD_SRC),$(lastword $(subst =, ,$(p)))) $(foreach p,$(CARD_BIN),$(lastword $(subst =, ,$(p))))
	$(MKFS) -m $(CARD_FS_MB) -i $(CARD_FS_INODES) $@ $(card_progs) lib/namespace=$(CARD_NS) rc/bin/kill=../../utilities/process/kill.rc usr/pad/readme=tests/card-motd.txt $(CARD_LIB) $(CARD_SRC) mnt/fat/ mnt/wsys/ tmp/
# version.txt: which card this is, a line that boot.rc says last on a
# board (not under an emulator: the recorded screens): mini-9pi's
# version (changes.txt's first), the commit (a + when the tree differs
# from it) and the minute this rule ran, which is when the kernel, a
# program, the firmware or config.txt last changed
CARD_VERSION = build/card-version.txt
$(CARD): $(MKCARD) $(CARD_FS) conf/config.txt kernel-pi1-ix.img kernel-pi2-ix.img $(wildcard $(FIRMWARE)/*)
	echo "mini-9pi $$(sed -n 's/^\* \([0-9.]*\) .*/\1/p' ../../changes.txt | head -1) ($$(git rev-parse --short=8 HEAD)$$(git diff --quiet HEAD || echo +)), card of $$(date '+%Y-%m-%d %H:%M')" > $(CARD_VERSION)
	$(MKCARD) -m $(CARD_MB) -date $(KERNDATE_IX) -fs $(CARD_FS) $@ bootcode.bin=$(FIRMWARE)/bootcode.bin start_cd.elf=$(FIRMWARE)/start_cd.elf \
	  fixup_cd.dat=$(FIRMWARE)/fixup_cd.dat config.txt=conf/config.txt version.txt=$(CARD_VERSION) mini9pi1.img=kernel-pi1-ix.img mini9pi2.img=kernel-pi2-ix.img
IMAGE_CARD = $(basename $(IMAGE))-card$(suffix $(IMAGE))
ifneq ($(findstring -card.,$(IMAGE)),-card.)
$(IMAGE_CARD): FORCE
	$(MAKE) B=build/$(BOARD)$(PIX)-card IMAGE=$@ BOOTRC=tests/boot-card.rc BOOTMORE=cat $@
endif
BOOT_CARD = $(subst $(IMAGE),$(IMAGE_CARD),$(BOOT))
QEMU_BOOT_CARD = $(subst $(IMAGE),$(IMAGE_CARD),$(QEMU_BOOT))
# ix's own sessions with the card, each a short one and all at once
# (docs/notes_performance.md, 3): the card as boot.rc leaves it and its
# FAT (mini-dossrv, then the kernel's device); utilities/'s programs on
# the root (files made, copied, renamed, dated, removed), on the FAT,
# the ones that read (date, wc, tee, cmp), the rest (seq, du, sleep,
# cleanname, unmount), what looks into a file (grep, tail, xd), the
# filters (sort, uniq, tr, sed), the processes (ps, time, kill), and
# what a script asks and builds (test, xargs), and what computes (hoc,
# awk, dc, bc), and what typesets (man, troff: a page for the terminal,
# written again in the new format, as a PDF file)
CARDS_IX = card-ix card-files card-fat card-text card-misc card-search card-filter card-proc card-script card-calc card-typeset
check-card: card $(IMAGE_CARD)
	/usr/sbin/sfdisk -l $(CARD) | grep -c 'FAT16\|Non-FS data' | grep -qx 2 && echo "ok card: its two partitions"
	dd if=$(CARD) of=$(B)/card-fat.img bs=512 skip=2048 count=65536 2> /dev/null
	/usr/sbin/fsck.vfat -n $(B)/card-fat.img > $(B)/card-fsck.txt 2>&1 && echo "ok card: its FAT, by fsck.vfat ($$(tail -1 $(B)/card-fsck.txt | sed 's/.*: //'))"
	mcopy -n -i $(B)/card-fat.img ::MINI9PI1.IMG $(B)/card-kernel.img && cmp $(B)/card-kernel.img kernel-pi1-ix.img && echo "ok card: the kernel read back by mcopy"
	$(MAKE) --no-print-directory ix-kernel > /dev/null
	$(SESSION_PY) --prompt "% " --timeout 180 --out $(B)/mini-card.txt --lines tests/session-card.cmds -- $(MINIQEMU) $(BOOT_CARD) $(CARD_SD) & \
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-card.txt --lines tests/session-card.cmds -- $(QEMU) $(QEMU_BOOT_CARD) $(CARD_SD) & \
	$(foreach s,$(CARDS_IX),$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 600 --out $(B)/mini-$(s).txt --lines tests/session-$(s).cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD) & \
	  $(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 240 --out $(B)/qemu-$(s).txt --lines tests/session-$(s).cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD) &) \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 180 --out $(B)/mini-card-ixk.txt --lines tests/session-card-ixk.cmds -- $(MINIQEMU) $(BOOT_IXK) $(CARD_SD) & \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 60 --out $(B)/qemu-card-ixk.txt --lines tests/session-card-ixk.cmds -- $(QEMU) $(QEMU_BOOT_IXK) $(CARD_SD) & \
	wait
	$(call unwarned,$(B)/mini-card.txt) | $(cardsize) > $(B)/mini-card.txt.masked; $(cardsize) tests/session-card | diff $(B)/mini-card.txt.masked - && echo "ok card: read and written by principia's fdisk and dossrv, on mini-9pi under mini-qemu"
	$(call unwarned,$(B)/qemu-card.txt) | $(cardsize) > $(B)/qemu-card.txt.masked; $(cardsize) tests/session-card | diff $(B)/qemu-card.txt.masked - && echo "ok card: the same under QEMU"
	@for s in $(CARDS_IX); do for e in mini qemu; do \
	  $(call unwarned,$(B)/$$e-$$s.txt) | $(cardsize) > $(B)/$$e-$$s.txt.masked; \
	  $(cardsize) tests/session-$$s | diff $(B)/$$e-$$s.txt.masked - && echo "ok card: with ix's own programs, tests/session-$$s under $$e" || exit 1; \
	done; done
	$(call unwarned,$(B)/mini-card-ixk.txt) | diff - tests/session-card-ixk && echo "ok card: /root by the kernel's own FAT (no dossrv in the image: boot.rc's bind '#Fdos'), read and written, under mini-qemu"
	$(call unwarned,$(B)/qemu-card-ixk.txt) | diff - tests/session-card-ixk && echo "ok card: the same under QEMU"

# The languages that are run, at the console (plan_scheme.md's and
# plan_pascal.md's stage 2, plan_prolog.md's stage 4): a session each, under mini-qemu and QEMU,
# the console as recorded (tests/session-card-scheme, -pascal). A line
# is typed at the program's own prompt too (session.py's --also:
# scheme's "> " and, inside an expression, "  "; GUESS.PAS's "Your guess? ";
# prolog's "?- " and, after an answer that may not be the last, " ? ").
#   make check-scheme   a file run (the eight queens, by lists), lines
#                       at the prompt, an error and its message, the
#                       stepper
#   make check-pascal   the disk's programs (the queens, one that asks
#                       a line), their P-code, a type error
#   make check-prolog   the classical programs by both machines (the
#                       second: -wam), goals at the prompt and ; for
#                       the next answer, the WAM's code, the errors
#   make expected-langs the three records made again (under QEMU)
langcheck = $(SESSION_PY) $(IXQUIET) --prompt "% " $(2) --timeout 900 --out $(B)/mini-card-$(1).txt --lines tests/session-card-$(1).cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD) & \
	$(SESSION_PY) $(IXQUIET) --prompt "% " $(2) --timeout 300 --out $(B)/qemu-card-$(1).txt --lines tests/session-card-$(1).cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD) & \
	wait; \
	$(call unwarned,$(B)/mini-card-$(1).txt) | diff - tests/session-card-$(1) && echo "ok card: $(1) at the console (tests/session-card-$(1)), under mini-qemu" && \
	$(call unwarned,$(B)/qemu-card-$(1).txt) | diff - tests/session-card-$(1) && echo "ok card: the same under QEMU"
check-scheme: card ; $(call langcheck,scheme,--also "> " --also "  ")
check-pascal: card ; $(call langcheck,pascal,--also "? ")
check-prolog: card ; $(call langcheck,prolog,--also "?- " --also " ? ")
expected-langs: card
	$(SESSION_PY) $(IXQUIET) --prompt "% " --also "> " --also "  " --timeout 300 --out $(B)/qemu-card-scheme.txt --lines tests/session-card-scheme.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(SESSION_PY) $(IXQUIET) --prompt "% " --also "? " --timeout 300 --out $(B)/qemu-card-pascal.txt --lines tests/session-card-pascal.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card-scheme.txt) > tests/session-card-scheme
	$(call unwarned,$(B)/qemu-card-pascal.txt) > tests/session-card-pascal
	$(SESSION_PY) $(IXQUIET) --prompt "% " --also "?- " --also " ? " --timeout 300 --out $(B)/qemu-card-prolog.txt --lines tests/session-card-prolog.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card-prolog.txt) > tests/session-card-prolog

FORCE:

clean:
	rm -rf build kernel-pi2*.img kernel-pi1.img kernel-pi1-b.img kernel-pi1-ix.img kernel-pi1-ixu.img kernel-pi1-ixa.img kernel-pi1-web.img kernel-pi1-card.img kernel-pi4.elf kernel-pi4-b.elf kernel-pi4-ix.elf kernel-pi4-card.elf kernel-pi4-ocaml4*.elf

.PHONY: all run qemu check ix ix-usb run-ix check-ix ix-audio check-audio check-audio-game check-audio-play check-draw expected-draw check-menu check-rio check-colors card check-card check-scheme check-pascal check-prolog expected-langs clean FORCE
