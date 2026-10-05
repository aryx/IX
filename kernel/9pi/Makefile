# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-9pi (plan_9pi.md): principia's Plan 9 kernel for the Pi1, in
# OCaml. Its modules (ML below) over kernel/lib's machine (lib/kernel.mk
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
ML = syscalls/$(ARCH)/Ureg core/Errors core/Types files/Dev processes/Proc files/Chan devices/sys/Devroot console/Devcons \
  devices/sys/Devenv devices/sys/Devsys devices/sys/Devarch devices/sys/Devdup devices/sys/Devsrv devices/sys/Devpipe \
  devices/sys/Devproc devices/storage/arm/Emmc devices/storage/Devsd files/P9 files/P9_wire devices/sys/Devmnt \
  buses/Usb buses/arm/Usbdwc buses/Devusb devices/keyboard/Kbd $(PIXEL_ML) devices/screen/Swcursor \
  devices/screen/Swconsole devices/keyboard/Devkbin devices/mouse/Devmouse devices/screen/Devdraw \
  devices/Devstub network/Etherusb network/Devether network/ip/Ip network/ip/Icmp network/ip/Tcp network/ip/Devip memory/Fault processes/Exec \
  syscalls/Usermem processes/Sysproc processes/Syssema files/Sysfile security/Auth syscalls/Systab \
  syscalls/arm/Syscall init/Main

# the bootdir, as kernel/conf/arm/pi's: boot.rc as /boot/boot (or a
# test's script: BOOTRC)
BIN = $(PRINCIPIA)/ROOT/arch/arm/bin
BOOTRC ?= $(PRINCIPIA)/kernel/init/user/boot/arm/boot.rc
RC ?= $(BIN)/rc
BOOTDIR = boot=$(BOOTRC) rcmain=$(PRINCIPIA)/ROOT/rc/lib/rcmain rc=$(RC) \
  $(foreach p,echo bind fdisk dossrv mount ls,$(p)=$(BIN)/$(p))
FS = $(B)/bootdir

# the devices' files' date: 9pi's (its conf compiled with
# -DKERNDATE=`date -n`: conf/kerndate.py finds it in 9pi's image), so that
# their entries are 9pi's
KERNDATE ?= $(shell conf/kerndate.py $(PRINCIPIA))

# the pixels (lib_graphics/Draw.mli): PIXEL=ocaml (the default), stage
# F's OCaml (lib_graphics/ocaml); PIXEL=c, principia's C pixel libraries
# (lib_graphics/c), as before stage F
PIXEL ?= ocaml
# each its own build (the OCaml's build/pi1-ocaml...), the image
# relinked when PIXEL changes (the same file: mini-pi's, the checks')
PIX = $(if $(filter ocaml,$(PIXEL)),-ocaml)
B ?= build/$(BOARD)$(PIX)
PIXEL_ML = $(if $(filter ocaml,$(PIXEL)),$(OCAML_PIXEL),lib_graphics/c/Draw)
OCAML_PIXEL = $(B)/gen/Memdata $(addprefix lib_graphics/ocaml/,Memchan Memimage Memdraw Memlayer Memfont Memshape Draw)

# principia's C pixel libraries (plan_9pi.md, decision 4), compiled by
# gcc with principia's headers (Plan 9 C: -fplan9-extensions, p9gcc.h's
# USED and SET) and linked in (lib/kernel.mk's EXTRA_OBJS), with
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

include ../lib/kernel.mk

$(IMAGE): build/pixel-$(BOARD)
build/pixel-$(BOARD): FORCE
	mkdir -p build; echo $(PIXEL) | cmp -s - $@ || echo $(PIXEL) > $@

# the Pi4's processes AArch32's (lib/pi4/board.h)
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
	$(CROSS)gcc $(P9CFLAGS) -c $< -o $@
$(B)/gfx/ml_%.o: $(GFX)/libmemlayer/%.c lib_graphics/c/p9gcc.h | $(B)/gfx
	$(CROSS)gcc $(P9CFLAGS) -c $< -o $@
$(B)/gfx/ld_%.o: $(GFX)/libdraw/%.c lib_graphics/c/p9gcc.h | $(B)/gfx
	$(CROSS)gcc $(P9CFLAGS) -c $< -o $@
$(B)/gfx/draw9.o: lib_graphics/c/draw9.c lib_graphics/c/p9gcc.h | $(B)/gfx
	$(CROSS)gcc $(P9CFLAGS) -c $< -o $@
$(B)/drawglue.o: lib_graphics/c/drawglue.c | $(B)
	$(CROSS)gcc $(CFLAGS) -c $< -o $@

# the OCaml pixels' data: principia's colour map and default font
$(B)/gen/Memdata.ml: conf/mkpixdata.py | $(B)
	conf/mkpixdata.py $(PRINCIPIA) $(B)/gen
$(B)/gen/Memdata.mli: $(B)/gen/Memdata.ml ;

# (remade when one of its files is: name=file's files)
MKBOOTDIR = ../../_build/default/kernel/tools/Mkbootdir.exe
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
  -e 's/^cpu0: 0MHz ARM Cortex-A72/cpu0: 0MHz ARM 1176JZF-S/' -e 's/^rca [0-9a-f]* ocr/rca 4567 ocr/')
unwarned = sed -e '/^qemu-system-[a-z0-9]*: warning: Blocked re-entrant IO on MemoryRegion: bcm2835-fb/d' $(BOARD_SED) $(1)

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
# echo, ls, cat, bind and mount, mini-ed as ed, tests/hello. No SD
# card, nothing of principia's in the bootdir (its date: KERNDATE_IX,
# the day mini-9pi was started; the pixels' tables are still
# principia's: conf/mkpixdata.py).
#   make ix          the image
#   make run-ix      under mini-qemu (../../mini-pi mini-9pi)
#   make check-ix    two sessions, under mini-qemu and QEMU, the console
#                    as recorded: tests/session-ix.cmds (hello, ed, a
#                    status: tests/session-ix), and stage B's own
#                    (tests/session-ix-b.cmds, its rc without -m: tests/session-ix-b)
IX = $(abspath ../..)
IX9 = $(IX)/_mk/5-plan9
IXDIRS = lib_core shell editor utilities/files utilities/misc utilities/namespace kernel/9pi/tests/hello
BOOTDIR_IX = boot=conf/boot.rc rc=$(IX9)/shell/mini-rc ed=$(IX9)/editor/mini-ed hello=$(IX9)/kernel/9pi/tests/hello/hello \
  echo=$(IX9)/utilities/misc/mini-echo ls=$(IX9)/utilities/files/mini-ls cat=$(IX9)/utilities/files/mini-cat \
  bind=$(IX9)/utilities/namespace/mini-bind mount=$(IX9)/utilities/namespace/mini-mount
KERNDATE_IX = 1790380800
IMAGE_IX = $(basename $(IMAGE))-ix$(suffix $(IMAGE))
BOOT_IX = $(subst $(IMAGE),$(IMAGE_IX),$(BOOT))
QEMU_BOOT_IX = $(subst $(IMAGE),$(IMAGE_IX),$(QEMU_BOOT))
ix: | $(B)
	for d in $(IXDIRS); do (cd $(IX)/$$d && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null) || exit 1; done
	$(MAKE) B=build/$(BOARD)$(PIX)-ix IMAGE=$(IMAGE_IX) BOOTDIR="$(BOOTDIR_IX)" KERNDATE=$(KERNDATE_IX) $(IMAGE_IX)
run-ix: ix
	$(MINIQEMU) $(BOOT_IX)
check-ix: ix
	$(SESSION_PY) --prompt "% " --timeout 120 --out $(B)/mini-ix.txt --lines tests/session-ix.cmds -- $(MINIQEMU) $(BOOT_IX)
	$(call unwarned,$(B)/mini-ix.txt) | diff - tests/session-ix && echo "ok 9pi: ix's own programs (mini-rc, mini-ed, hello) under mini-qemu"
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-ix.txt --lines tests/session-ix.cmds -- $(QEMU) $(QEMU_BOOT_IX)
	$(call unwarned,$(B)/qemu-ix.txt) | diff - tests/session-ix && echo "ok 9pi: ix's own programs under QEMU"
	$(SESSION_PY) --prompt "% " --timeout 180 --out $(B)/mini-ix-b.txt --lines tests/session-ix-b.cmds -- $(MINIQEMU) $(BOOT_IX)
	$(call unwarned,$(B)/mini-ix-b.txt) | diff - tests/session-ix-b && echo "ok 9pi: stage B's session with ix's own programs, under mini-qemu"
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-ix-b.txt --lines tests/session-ix-b.cmds -- $(QEMU) $(QEMU_BOOT_IX)
	$(call unwarned,$(B)/qemu-ix-b.txt) | diff - tests/session-ix-b && echo "ok 9pi: stage B's session with ix's own programs, under QEMU"

FORCE:

clean:
	rm -rf build kernel-pi1.img kernel-pi1-b.img kernel-pi1-ix.img kernel-pi4.elf kernel-pi4-b.elf kernel-pi4-ix.elf

.PHONY: all run qemu check ix run-ix check-ix clean FORCE
