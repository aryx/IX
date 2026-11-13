# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-9pi (plan_9pi.md) is principia's Plan 9 kernel for the Pi1,
# written in OCaml. Its modules (ML below) run over kernels/lib_machine's
# machine, and lib_machine/kernel.mk builds the image. The image embeds
# 9pi's bootdir, which mini-mkbootdir (in ../tools) makes from the
# programs of ~/principia that 9pi links into its own image.
#
# The directories are those of principia's kernel/: core/ (the types),
# files/ (dev, chan, 9P), processes/, memory/, security/, syscalls/
# (the table, and the arch's entry and notes), console/,
# devices/{sys,storage,keyboard,mouse,screen}/, buses/ (USB) and init/.
# An arch's code is in its own arm/ directory (the Pi1's; syscalls/
# also has arm64/, the Pi4's Ureg, picked by ARCH), and its interface is
# in the directory above. lib_graphics/ has the pixels (PIXEL picks
# ocaml/, or c/, the glue to principia's C). conf/ has boot.rc (the
# bootdir's /boot/boot) and config.txt (the card's), and tests/ has the
# sessions and screens that make check compares.
#
#   make            builds kernel-pi1.img (with mini-ml: see COMPILER)
# The SD card is principia's qemu-sd.img. Its FAT, served by dossrv, is
# the root, and its writes are kept in memory (snapshot=on).
#
#   make run        runs it under mini-qemu (Ctrl-A x quits)
#   make qemu       runs it under QEMU
#   make check      runs stage C's session (raspberry/tests/9pi.py's,
#                   typed at the boot's rc: tests/session-c.cmds) under
#                   mini-qemu and QEMU, and compares the console with
#                   tests/session-c. That is the C 9pi's console under
#                   QEMU, except for hoc's pid: 40 there, where 9pi's is
#                   48 because of its usbd's processes (stage D).
#                   Then it runs step D1's session (the processes:
#                   sleep, a kill by note, plumber's threads and mount:
#                   tests/session-d), and a session typed on QEMU's USB
#                   keyboard (usbd, usb/kb, #Ι/kbin; the console is the
#                   C 9pi's byte for byte: tests/session-usb). Then it
#                   runs stage B's session (tests/boot-b.rc as
#                   /boot/boot, with no card: the namespace, the
#                   environment, pipes, processes; tests/session-b).
#                   Then it checks the screen (the console drawn as 9pi
#                   draws it, with the arrow cursor) after a session and
#                   after the USB mouse moved, under mini-qemu and QEMU,
#                   against mini-9pi's pixels (tests/screen*-mini.ppm.gz).
#                   Then it checks rio: tests/graphics.py runs the steps
#                   of raspberry/tests/9pi_graphics.py with the USB
#                   keyboard and mouse (the console, rio started, its
#                   menu, a window swept out, a command in it). Every
#                   screen must be mini-9pi's (tests/rio-mini.md5) and
#                   the console the C 9pi's (tests/rio-c.txt), under
#                   mini-qemu and QEMU. The screens are not compared
#                   with the C 9pi's (tests/screen*-c.ppm.gz and
#                   rio-c.md5, which are kept), because mini-9pi's
#                   screen is 1024 by 768 where 9pi's is 640 by 480, and
#                   its memory line is its own.
#   make expected-mini    records mini-9pi's screens under QEMU
#                         (tests/*-mini.*)
#   make expected-screen  records the C 9pi's screens under QEMU
#                         (tests/*-c.ppm.gz)
#   make expected-rio     records the C 9pi's rio screens (their md5s)
#                         and its console

# (The mkfiles' recipes are in rc, run by mini-rc: see mkfiles/mkconfig.)
export MKSHELL = mini-rc
MAKEFLAGS += --no-builtin-rules

PRINCIPIA ?= $(HOME)/principia
# The modules, in link order, in principia's kernel/ directories. The
# modules of the kernel's arch (ARCH is arm for the Pi1, arm64 for the
# Pi4) are in its directory, and their interfaces in the directory
# above. The programs are arm programs on both boards (principia's,
# compiled by 5c, run as AArch32 at EL0 on the Pi4), so
# syscalls/arm/Syscall is their ABI on both. The Pi4 uses the Pi1's
# EMMC and DWC2 drivers, because QEMU's raspi4b has those devices.
ARCH = $(if $(filter pi4,$(BOARD)),arm64,arm)
ML = syscalls/$(ARCH)/Ureg core/Errors core/Types files/Dev processes/Proc files/Kchan processes/Kproc devices/sys/Devroot security/Rng console/Devcons \
  devices/sys/Devenv devices/sys/Devsys devices/sys/Devarch devices/sys/Devdup devices/sys/Devsrv devices/sys/Devpipe \
  devices/sys/Devproc devices/storage/arm/Emmc devices/storage/Devsd filesystems/lib_fat/Fat filesystems/Kdos filesystems/lib_xv6fs/Xv6fs filesystems/Kfs files/P9 files/P9_wire devices/sys/Devmnt \
  buses/Usb buses/arm/Usbdwc buses/Devusb devices/keyboard/Latin1 devices/keyboard/Kbd $(PIXEL_ML) devices/screen/Swcursor \
  devices/screen/Swconsole devices/keyboard/Devkbin devices/mouse/Devmouse devices/audio/Devaudio buses/lib_usb/Usbdesc buses/lib_usb/Hid buses/lib_usb/Usbbus buses/Kusb devices/web/Kweb \
  devices/screen/Devdraw devices/Devstub network/Etherusb network/Devether network/ip/Ip network/ip/Icmp network/ip/Udp network/ip/Tcp network/ip/Devip memory/Fault memory/Sysseg processes/Exec \
  ../../lib_executable/Symbols ../../lib_executable/Frames syscalls/Usermem processes/Sysproc processes/Syssema files/Sysfile security/Auth syscalls/Systab \
  syscalls/arm/Syscall init/Main

# The bootdir, as in kernel/conf/arm/pi: boot.rc becomes /boot/boot (or
# a test's script does, through BOOTRC).
BIN = $(PRINCIPIA)/ROOT/arch/arm/bin
BOOTRC ?= $(PRINCIPIA)/kernel/init/user/boot/arm/boot.rc
RC ?= $(BIN)/rc
# (BOOTMORE names more of principia's programs, which a check adds.)
BOOTDIR = boot=$(BOOTRC) rcmain=$(PRINCIPIA)/ROOT/rc/lib/rcmain rc=$(RC) \
  $(foreach p,echo bind fdisk dossrv mount ls $(BOOTMORE),$(p)=$(BIN)/$(p))
FS = $(B)/bootdir

# The date of the devices' files is 9pi's, so that their entries are
# the same as 9pi's. 9pi's conf is compiled with -DKERNDATE=`date -n`,
# and mini-mkbootdir finds that date in 9pi's image when it is given
# principia's directory.
KERNDATE ?= $(PRINCIPIA)

# The pixels (lib_graphics/Kdraw.mli). PIXEL=ocaml, the default, is
# stage F's OCaml: lib_graphics/ocaml's Kdraw, over lib_memdraw and
# lib_memlayer, which are principia's libmemdraw and libmemlayer and
# know nothing of a kernel. PIXEL=c uses principia's C pixel libraries
# (lib_graphics/c), as before stage F.
PIXEL ?= ocaml
# The compiler. On the Pi 1 it is ix's own tools (kernel.mk's
# COMPILER=ix: mini-ml for the OCaml and mini-cc for the C, run by the
# mkfile), so that ix's kernel runs code from ix's compiler at every
# boot. Its code runs 11% more instructions than ocaml-light's at
# session-c, leaving aside the boot's clearing of the bss (2026-10-29).
# make COMPILER=light builds with ocaml-light, into an image of its own
# (kernel-pi1-light.img). With the same file for both, switching would
# leave it stale, because an ix image is newer than ocaml-light's
# kernel.elf.
BOARD ?= pi1
# (The Pi 2 used ix's tools too from 9f9e8389, until the build on its
# card under QEMU, with its four cores, stopped in a run of k. It went
# back to ocaml-light on 2026-10-29: see docs/plans/bugs/ix.md.)
COMPILER ?= $(if $(filter pi1,$(BOARD)),ix,light)
ifeq ($(COMPILER),light)
ifneq ($(filter pi1,$(BOARD)),)
IMAGE ?= kernel-$(BOARD)-light.img
endif
endif
# What the Makefile makes goes in BUILD, outside the sources, as dune's
# _build and mk's _mk do, so that dune need not be told to skip it.
# Each board and variant has its own directory (pi1-ocaml...), and the
# image is relinked when PIXEL changes, because it is the same file for
# both (the one mini-pi and the checks use). The compiler gets its own
# directory too (kernel.mk's COMPILER=ocaml), because OCaml 4.14's
# objects are not ocaml-light's.
PIX = $(if $(filter ocaml,$(PIXEL)),-ocaml)$(if $(filter ocaml,$(COMPILER)),-ocaml4)
BUILD ?= ../../_make/9pi
B ?= $(BUILD)/$(BOARD)$(PIX)
PIXEL_ML = $(if $(filter ocaml,$(PIXEL)),$(OCAML_PIXEL),lib_graphics/c/Kdraw)
OCAML_PIXEL = lib_graphics/Memdata $(addprefix lib_graphics/lib_memdraw/,Memchan Memimage Memgeneral Memdraw Memfont) \
  $(addprefix lib_graphics/lib_memlayer/,Memlayer Memshape) lib_graphics/ocaml/Kdraw

# Principia's C pixel libraries (plan_9pi.md, decision 4). gcc compiles
# them with principia's headers (they are Plan 9 C, hence
# -fplan9-extensions and p9gcc.h's USED and SET), and they are linked
# in through lib_machine/kernel.mk's EXTRA_OBJS. With them come draw9.c
# (their libc, the kernel's d9_* interface, and hwdraw, as in 9pi's
# screen.c rather than libmemdraw's hooks.c) and drawglue.c (the OCaml
# primitives).
GFX = $(PRINCIPIA)/lib_graphics
MEMDRAW = alloc alphadraw arc chan cmap color compressed defont draw ellipse fillpoly init io line poly \
  replmul resolution string subfont transfer
MEMLAYER = $(basename $(notdir $(wildcard $(GFX)/libmemlayer/*.c)))
LIBDRAW = arith replclipr_geom chan resolution defont icossin icossin2 compressed misc
P9CFLAGS = $(CPU) -O2 -ffreestanding -fno-builtin -fno-pie -fno-stack-protector -fplan9-extensions -w \
  -include lib_graphics/c/p9gcc.h -I$(PRINCIPIA)/include/arch/arm $(P9INC) -I$(PRINCIPIA)/include/ALL
# For the Pi4: Plan 9's long is 32 bits (in 5c and 7c), while gcc's
# (LP64) is 64, and memdraw's pixel words are ulongs. So a copy of
# principia's libc.h with ulong as an unsigned int comes before its own.
P9INC = $(if $(filter pi4,$(BOARD)),-I$(B)/p9)
DRAWOBJS = $(MEMDRAW:%=$(B)/gfx/md_%.o) $(MEMLAYER:%=$(B)/gfx/ml_%.o) $(LIBDRAW:%=$(B)/gfx/ld_%.o) $(B)/gfx/draw9.o
EXTRA_OBJS = $(if $(filter ocaml,$(PIXEL)),,$(DRAWOBJS) $(B)/drawglue.o)

include ../lib_machine/kernel.mk

$(IMAGE): $(BUILD)/pixel-$(BOARD)
$(BUILD)/pixel-$(BOARD): FORCE
	mkdir -p $(BUILD); echo $(PIXEL) | cmp -s - $@ || echo $(PIXEL) > $@

# The Pi4's processes run as AArch32 (lib_machine/pi4/board.h).
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

# The OCaml pixels' data: principia's colour map and default font.
# lib_graphics/Memdata.ml is in the repository, so principia is not
# needed. This target makes it again from principia's C, if that
# changes.
pixdata:
	../../_build/default/kernels/tools/Mkpixdata.exe $(PRINCIPIA) lib_graphics

# (The bootdir is made again when one of its files changes: the file
# of each name=file.)
MKBOOTDIR = ../../_build/default/kernels/tools/Mkbootdir.exe
$(FS): $(MKBOOTDIR) $(foreach x,$(BOOTDIR),$(lastword $(subst =, ,$(x)))) | $(B)
	$(MKBOOTDIR) $@ $(KERNDATE) $(BOOTDIR)

run: $(IMAGE)
	$(MINIQEMU) $(BOOT) $(SD)

qemu: $(IMAGE)
	$(QEMU) $(QEMU_BOOT) $(SD)

# A console made the same as the Pi1's C 9pi's. QEMU's framebuffer
# warns, for the C 9pi as for mini-9pi (its mailbox's channel 1 writes
# back the fb's answer), and the warning is not part of the console.
# The two board lines of the Pi4's banner become the Pi1's, and the SD
# card's address (random in QEMU 11) becomes 4567.
BOARD_SED = $(if $(filter pi4,$(BOARD)),-e 's/^board rev: 0xb03115 /board rev: 0x900021 /' \
  -e 's/^cpu0: 0MHz ARM Cortex-A72/cpu0: 0MHz ARM 1176JZF-S/' -e 's/^rca [0-9a-f]* ocr/rca 4567 ocr/') \
  $(if $(filter pi2,$(BOARD)),-e 's/^board rev: 0xa21041 /board rev: 0x900021 /' -e 's/^cpu0: 0MHz ARM Cortex-A7\( ([0-9] cores)\)\?$$/cpu0: 0MHz ARM 1176JZF-S/')
# (Also, with ix's programs the clock runs from boot.rc's date, so the
# minute of what a session wrote is the run's own, and it is MM in the
# recorded consoles.)
# (Also, mini-9pi writes a trace line after a "suicide", which 9pi does
# not: see Syscall.traced.)
# (Also, the boot's memory line has each kernel's own numbers. 9pi's is
# "448M memory: 91M kernel data, 357M user, 1696M swap", and mini-9pi's
# is "512M memory: 64M video, 96M kernel data, 352M user, 0M swap"
# (16M and 400M on the board, whose firmware keeps 16 MB). The numbers
# are N in the recorded consoles, and the video's part is left out.)
unwarned = sed -e 's/^[0-9]*M memory: \([0-9]*M video, \)\?[0-9]*M kernel data, [0-9]*M user, [0-9]*M swap/NM memory: NM kernel data, NM user, NM swap/' -e '/^qemu-system-[a-z0-9]*: warning: Blocked re-entrant IO on MemoryRegion: bcm2835-fb/d' -e '/^[^ ]* [0-9]*: trace: /d' -e 's/ Sep 26 00:[0-9][0-9] / Sep 26 00:MM /' $(BOARD_SED) $(1)

# The screen's sessions: a command, then the mouse moved (by usb/kb's
# moves, accelerated as 9pi's mousetrack does).
SCREEN_SESSION = "echo hello"
MOVE = --usb --move "200,-100;-60,40"
C9PI = qemu-system-arm -M raspi1ap -device loader,file=$(PRINCIPIA)/kernel/COMPILE/9/bcm/9pi,addr=0x8000,cpu-num=0,force-raw=on \
  $(SD) -serial null -serial mon:stdio -display none $(USB)

expected-screen: | $(B)
	$(SESSION_PY) --prompt "% " --timeout 120 --screendump $(B)/c-screen.ppm --out $(B)/c-screen.txt $(SCREEN_SESSION) -- $(C9PI)
	gzip -n -9 < $(B)/c-screen.ppm > tests/screen-c.ppm.gz
	$(SESSION_PY) --prompt "% " $(MOVE) --timeout 200 --screendump $(B)/c-move.ppm --out $(B)/c-move.txt $(SCREEN_SESSION) -- $(C9PI)
	gzip -n -9 < $(B)/c-move.ppm > tests/screen-move-c.ppm.gz

# The network (stage E): a usb-net device (Etherusb, #l0, #I), a web
# server on the host (tests/www on 127.0.0.1:8123, which the guest sees
# as 10.0.2.2 through QEMU's user network and mini-qemu's Usernet),
# then ipconfig, ping and hget. The round trips' times are masked.
# (QEMU 11.1's raspi4b needs a QEMU built with slirp: configure
# --enable-slirp.)
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

# mini-9pi's own screens, the ones make check compares, recorded under
# QEMU: rio's (their md5s), and the console's after a session and after
# the mouse moved.
expected-mini: $(IMAGE) | $(B)
	rm -rf $(B)/rio-ref
	tests/graphics.py $(B)/rio-ref -- $(QEMU) $(QEMU_BOOT) $(SD) $(USB)
	cd $(B)/rio-ref && md5sum $(RIO_SCREENS) > $(CURDIR)/tests/rio-mini.md5
	$(MAKE) --no-print-directory run-qemu-screen run-qemu-move
	gzip -n -9 < $(B)/qemu-screen.ppm > tests/screen-mini.ppm.gz
	gzip -n -9 < $(B)/qemu-move.ppm > tests/screen-move-mini.ppm.gz

# Stage B's image, with tests/boot-b.rc as /boot/boot: kernel-pi1-b.img
# or kernel-pi4-b.elf.
IMAGE_B = $(basename $(IMAGE))-b$(suffix $(IMAGE))

# The sessions. Each one is an emulator and a kernel that we wait on,
# using a core, and none reads what another writes. So they run side by
# side (check's $(MAKE) -j), and then check compares what each wrote.
# One after the other they took 7 minutes, and 14 for ix's slower
# kernel. The network's two sessions share one web server.
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
	tests/graphics.py --step 10 --expect tests/rio-mini.md5 $(B)/rio-mini -- $(MINIQEMU) $(BOOT) $(SD) $(USB)
run-rio-qemu:
	tests/graphics.py --expect tests/rio-mini.md5 $(B)/rio-qemu -- $(QEMU) $(QEMU_BOOT) $(SD) $(USB)
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
	gzip -dc tests/screen-mini.ppm.gz | cmp - $(B)/mini-screen.ppm && gzip -dc tests/screen-mini.ppm.gz | cmp - $(B)/qemu-screen.ppm \
	  && echo "ok 9pi: the screen as recorded, under mini-qemu and QEMU"
	gzip -dc tests/screen-move-mini.ppm.gz | cmp - $(B)/mini-move.ppm && gzip -dc tests/screen-move-mini.ppm.gz | cmp - $(B)/qemu-move.ppm \
	  && echo "ok 9pi: the screen after the USB mouse moved, as recorded, under mini-qemu and QEMU"
	cd $(B)/rio-mini && md5sum --quiet -c $(CURDIR)/tests/rio-mini.md5
	cd $(B)/rio-qemu && md5sum --quiet -c $(CURDIR)/tests/rio-mini.md5
	$(call unwarned,$(B)/rio-mini/console.txt) | tr -d '\r' | diff - tests/rio-c.txt
	$(call unwarned,$(B)/rio-qemu/console.txt) | tr -d '\r' | diff - tests/rio-c.txt \
	  && echo "ok 9pi: rio (its menu, a window swept out, a command in it), every screen as recorded and the console the C 9pi's, under mini-qemu and QEMU"
	$(call unwarned,$(B)/mini-net.txt) | $(call netmask) | diff - tests/session-net && echo "ok 9pi: the network (ipconfig, ping, hget from the host) under mini-qemu"
	$(call unwarned,$(B)/qemu-net.txt) | $(call netmask) | diff - tests/session-net && echo "ok 9pi: the network under QEMU"

# Stage B's image has its own build directory, and tests/boot-b.rc as
# /boot/boot. (The rule is in the outer make only, because the inner
# one builds it as IMAGE.)
ifneq ($(findstring -b.,$(IMAGE)),-b.)
$(IMAGE_B): FORCE
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-b IMAGE=$@ BOOTRC=tests/boot-b.rc $@
endif

BOOT_B = $(subst $(IMAGE),$(IMAGE_B),$(BOOT))
QEMU_BOOT_B = $(subst $(IMAGE),$(IMAGE_B),$(QEMU_BOOT))

# mini-9pi alone (plan_rio.md). make ix builds kernel-pi1-ix.img, a
# kernel whose bootdir has ix's own programs, compiled from OCaml by
# mini-ml into Plan 9's a.out (mini-mk O=5 OS=plan9, with ix's tools
# from ../../bin). They are:
#   - mini-rc as rc (it runs conf/boot.rc as /boot/boot, then prompts)
#   - utilities/'s echo, ls, cat, bind and mount
#   - mini-ed as ed
#   - tests/hello, tests/hog (it holds memory), and tests/threads
#     (mini-ml's threads and channels)
#   - Source's check, as sources (lib_core/commons/tests)
#   - mini-dossrv and mini-fdisk
#   - hellodraw and hellomenu (lib_graphics/tests)
#   - tests/words.txt as words
# (mini-rio and the programs of its windows are not there: they are on
# the card's second partition, which other targets use: see MENU_USB.)
# There is no SD card, and nothing of principia's in the bootdir. Its
# date is KERNDATE_IX, the day mini-9pi was started. The pixels' tables
# are still principia's (see mini-mkpixdata).
#   make ix          builds the image
#   make run-ix      runs it under mini-qemu (../../mini-pi mini-9pi)
#   make check-ix    runs two sessions under mini-qemu and QEMU, and
#                    compares the console with the recorded one:
#                    tests/session-ix.cmds (hello, ed, a status:
#                    tests/session-ix), and stage B's own session
#                    (tests/session-ix-b.cmds, with rc run without -m:
#                    tests/session-ix-b)
IX = $(abspath ../..)
IX9 = $(IX)/_mk/5-plan9
IXDIRS = shell editors/ed utilities/files utilities/misc utilities/namespace utilities/time utilities/pipe utilities/compare utilities/process utilities/text utilities/byte utilities/archive utilities/calc/hoc utilities/calc/dc utilities/calc/bc utilities/text/awk kernels/9pi/tests/hello kernels/9pi/tests/hog kernels/9pi/tests/tone kernels/9pi/tests/threads lib_core/commons/tests kernels/9pi/filesystems/user/dossrv \
  kernels/9pi/devices/storage/user/fdisk kernels/9pi/buses/user/usbd lib_graphics/tests windows/rio windows/rio/tests windows/desktop apps/misc apps/files profilers/misc apps/media/play apps/music/rebirth games \
  languages/smalltalk languages/smalltalk/hosts/draw languages/scheme languages/pascal languages/prolog languages/tiger editors/drscheme apps/office apps/page editors/turbopascal/hosts/draw editors/emacs/draw \
  typesetting/man networking browsers/lynx browsers/netscape apps/maps assembler linker linker/tools languages/dotnet languages/ml languages/c builder generators/lex generators/yacc
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
# (The libraries are built first, in their order, by the top mkfile's
# libs target, because a program's mkfile takes their archives as they
# are.)
ix: | $(B)
	cd $(IX) && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 libs > /dev/null
	for d in $(IXDIRS); do (cd $(IX)/$$d && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null) || exit 1; done
	cd $(IX)/games && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 PLATFORM=software > /dev/null
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-ix IMAGE=$(IMAGE_IX) BOOTDIR="$(BOOTDIR_IX)" KERNDATE=$(KERNDATE_IX) $(IMAGE_IX)
# With a USB keyboard and mouse: the same image, with mini-usbd in its
# bootdir (in Plan 9 the driver is a program; ix's own is
# buses/user/usbd). It is for the checks that move a mouse (check-menu).
IMAGE_IXU = $(basename $(IMAGE))-ixu$(suffix $(IMAGE))
BOOT_IXU = $(subst $(IMAGE),$(IMAGE_IXU),$(BOOT))
QEMU_BOOT_IXU = $(subst $(IMAGE),$(IMAGE_IXU),$(QEMU_BOOT))
ix-usb: ix
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-ixu IMAGE=$(IMAGE_IXU) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXU)
# With the network's programs (plan_browser.md, stage 10): ix-usb's
# image, with mini-curl, wc, timesync, lynx and ca.pem in its bootdir.
# In check-ix-net, echo into /net/ipifc's files configures the interface
# (there is no ipconfig). Then mini-curl, an ix program over the
# kernel's TCP (lib_networking's plan9/Tcp, which uses /net/tcp's
# files), asks the host's web server (tests/www, 10.0.2.2:8123) for the
# two files of check's session-net, under QEMU and under mini-qemu.
# (CA_PEM is the roots a certificate is checked against: this
# machine's, from Debian's file or macOS's, so that a card can be made
# on macOS too.)
CA_PEM = $(firstword $(wildcard /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem))
IMAGE_IXN = $(basename $(IMAGE))-ixn$(suffix $(IMAGE))
QEMU_BOOT_IXN = $(subst $(IMAGE),$(IMAGE_IXN),$(QEMU_BOOT))
ix-net: ix
	cd $(IX)/networking && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null
	cd $(IX)/browsers/lynx && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-ixn IMAGE=$(IMAGE_IXN) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd curl=$(IX9)/networking/mini-curl wc=$(IX9)/utilities/misc/mini-wc timesync=$(IX9)/networking/mini-timesync lynx=$(IX9)/browsers/lynx/mini-lynx ca.pem=$(CA_PEM)" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXN)
run-qemu-ix-net:
	mkdir -p $(B); $(call www); \
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 120 --out $(B)/qemu-ix-net.txt --lines tests/session-ix-net.cmds -- $(QEMU) $(QEMU_BOOT_IXN) $(USB) $(NET); \
	$(call wwwstop)
BOOT_IXN = $(subst $(IMAGE),$(IMAGE_IXN),$(BOOT))
# https:// from the Internet, run by hand. It is not part of check,
# because it needs the Internet and the bytes it gets are the servers'.
# boot.rc has set the interface and the clock (mini-timesync), the
# secrets come from the board's generator (Rng), and the roots are
# /boot/ca.pem. The session is tests/session-ix-tls.cmds, and the
# console goes in $(B)/qemu-ix-tls.txt and mini-ix-tls.txt.
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
# A game for two computers (the playground's TinyTronscroll, over its
# Multiplayer and lib_playground/netcode): ix-usb's image with the game
# in its bootdir. In check-tron, the game in the kernel plays with the
# same game on this machine (mini-ml's build for Linux, from
# games/arcade; the two then sum the same bytes of their models), over
# UDP through QEMU's user network. It plays once as the one that joins
# (10.0.2.2 is this machine: /net/udp's connect) and once as the host
# (the port is forwarded to the guest: announce, and headers). Then two
# guests, one that hosts and one that joins, are joined by QEMU's
# socket network, as two boards would be by a cable (each asks for the
# other's Ethernet address: ARP between two mini-9pi's). Each game says
# its ticks and whether the two games agree (the flag ticks=on); the
# guest says it on its console, kept in $(B)/qemu-tron-*.txt. There is
# no recorded console, because how many ticks are played in the time
# depends on the machine.
IMAGE_IXT = $(basename $(IMAGE))-ixt$(suffix $(IMAGE))
QEMU_BOOT_IXT = $(subst $(IMAGE),$(IMAGE_IXT),$(QEMU_BOOT))
TRON = $(IX)/_mk/7/games/arcade/tinytronscroll
ix-tron: ix
	cd $(IX)/games/arcade && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null
	cd $(IX) && PATH=$(IX)/bin:$$PATH mini-mk O=7 libs > /dev/null
	cd $(IX)/games/arcade && PATH=$(IX)/bin:$$PATH mini-mk O=7 > /dev/null
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-ixt IMAGE=$(IMAGE_IXT) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd tronscroll=$(IX9)/games/arcade/tinytronscroll" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXT)
check-tron: ix-tron
	mkdir -p $(B)
	tests/tron.sh $(B) $(TRON) join -- $(QEMU) $(QEMU_BOOT_IXT) $(USB) -device usb-net,netdev=n0 -netdev user,id=n0
	tests/tron.sh $(B) $(TRON) host -- $(QEMU) $(QEMU_BOOT_IXT) $(USB) -device usb-net,netdev=n0 -netdev user,id=n0,hostfwd=udp:127.0.0.1:7777-:7777
	tests/tron.sh $(B) $(TRON) pair -- $(QEMU) $(QEMU_BOOT_IXT) $(USB)
# The sound (plan_audio.md, stage 3): ix's image with tests/tone in its
# bootdir. check-audio runs under mini-qemu alone, because QEMU's Pi
# has no PWM. Its session, tests/session-audio.cmds, writes the tone to
# /dev/audio, then again at half the volume. tests/audio.py compares
# what the emulator's jack played (-audiodev wav, written when the
# emulator ends) sample by sample, and the console must be as recorded
# (tests/session-audio). Why -ips 700: unless told, the emulator's
# board runs 30 million instructions a second of its own time, and a
# Pi 1 runs some 700. At 30, the first tone's writer was seen stopped
# for a tenth of a second (by what, we did not look into), so the ring
# ran empty and silence played in the tone's middle, as it should.
IMAGE_IXA = $(basename $(IMAGE))-ixa$(suffix $(IMAGE))
BOOT_IXA = $(subst $(IMAGE),$(IMAGE_IXA),$(BOOT))
ix-audio: ix
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-ixa IMAGE=$(IMAGE_IXA) BOOTDIR="$(BOOTDIR_IX) tone=$(IX9)/kernels/9pi/tests/tone/tone" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXA)
check-audio: ix-audio
	rm -f $(B)/mini-audio.wav
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 300 --out $(B)/mini-audio.txt --lines tests/session-audio.cmds -- $(MINIQEMU) $(BOOT_IXA) -ips 700 -audiodev wav,path=$(B)/mini-audio.wav
	$(call unwarned,$(B)/mini-audio.txt) | diff - tests/session-audio && echo "ok 9pi: /dev/audio and /dev/volume, the console, under mini-qemu"
	tests/audio.py $(B)/mini-audio.wav
# A game's sound (plan_audio.md, stage 4), run by hand: it takes 3
# minutes, so it is not in check-all. TinyMissileCommand runs the
# session "explosions" (95 frames, from games/tests/audio.expected)
# from the card, and writes its sound a frame at a time to /dev/audio.
# Its check compares mini-qemu's WAV, sample by sample, with the same
# session's -dump-audio on Linux (dune's build). Why -ips 1000: at a
# Pi 1's 700, the last explosion's frames are slower than the sound,
# and the ring runs empty once (all the samples are then there, but
# 735 of them are late).
GAME_AUDIO = -fixed-time 1000 -script space:1,up:2-30,a:32,s:33,d:34
check-audio-game: ix card
	mkdir -p $(B)
	rm -f $(B)/mini-game.wav
	../../_build/default/games/shmup/TinyMissileCommand.exe -dump-frame 95 $(B)/game.ppm -dump-audio $(B)/game-linux.wav $(GAME_AUDIO) seed=1
	printf "missilecommand -frames 95 -dump-audio /dev/audio $(GAME_AUDIO) 'seed=1'\nhello\nhello\n" > $(B)/game.cmds
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 600 --out $(B)/mini-game.txt --lines $(B)/game.cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD) -ips 1000 -audiodev wav,path=$(B)/mini-game.wav
	tests/audio.py $(B)/mini-game.wav --expect $(B)/game-linux.wav
# mini-play on the card (plan_audio.md, stage 5), run by hand (it takes
# 3 minutes). play file plays a second each of a MOD, a MIDI file and
# an MP3 (in /lib/sounds). The check compares mini-qemu's WAV, sample
# by sample, with mini-play's own output on Linux (dune's build) for
# the three, and reads /dev/audiostat after each one ("empty 0" means
# the buffer never ran dry). It uses -ips 1000, as check-audio-game does.
PLAY_SOUNDS = tune.mod=tiny_soundtracker.mod theme.mid=korobeiniki.mid mono.mp3=lsf_mono.mp3
check-audio-play: ix card
	mkdir -p $(B)
	rm -f $(B)/mini-play.wav $(B)/play.cmds
	for s in $(PLAY_SOUNDS); do \
	  ../../_build/default/apps/media/play/Play.exe -c -s 1 ../../lib_audio/tests/data/$${s#*=} > $(B)/play-$${s%=*}.pcm; \
	  printf "play -s 1 /lib/sounds/$${s%=*}\ncat /dev/audiostat\n" >> $(B)/play.cmds; done
	printf "hello\nhello\n" >> $(B)/play.cmds
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 900 --out $(B)/mini-play.txt --lines $(B)/play.cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD) -ips 1000 -audiodev wav,path=$(B)/mini-play.wav
	@! grep -a '^bufsize' $(B)/mini-play.txt | grep -v 'empty 0$$' || { echo "FAIL 9pi: mini-play: the buffer ran empty"; exit 1; }
	tests/audio.py $(B)/mini-play.wav --expect $(foreach s,$(PLAY_SOUNDS),$(B)/play-$(firstword $(subst =, ,$(s))).pcm)
# The image for a web page (plan_web.md, stage 2; docs/m-ix.html):
# ix-usb's image built with WEB=1 (lib_machine/web/host.s, where
# mini-qemu's board itself moves and fills the bytes). It is for
# mini-qemu only, not for QEMU nor a Pi. Its collector's young
# generation is 2M words (8 MB) where the Pi's is 256k, and the old
# one's work is done at 400% of what lives, because on an emulator an
# instruction costs and memory does not. Reaching rc's prompt under
# mini-qemu takes 386 million instructions with ix-usb, 244 with
# WEB=1's moves, and 125 with these settings too
# (raspberry/tests/boot_bench.sh).
WEB_GC = s=2M,o=400
# (It is built by ocaml-light, because mkkernel has no WEB.)
IMAGE_WEB = $(basename $(IMAGE))-web$(suffix $(IMAGE))
ix-web: ix
	$(MAKE) COMPILER=light WEB=1 CAMLRUNPARAM=$(WEB_GC) B=$(BUILD)/$(BOARD)$(PIX)-web IMAGE=$(IMAGE_WEB) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernels/9pi/buses/user/usbd/mini-usbd" KERNDATE=$(KERNDATE_IX) $(IMAGE_WEB)
# An image with neither usbd nor dossrv in its bootdir, so that the
# kernel itself handles the keyboard, the mouse and the card's FAT
# (Kusb and Kdos, which boot.rc falls back to). It is for check-card's
# last session.
IMAGE_IXK = $(basename $(IMAGE))-ixk$(suffix $(IMAGE))
BOOT_IXK = $(subst $(IMAGE),$(IMAGE_IXK),$(BOOT))
QEMU_BOOT_IXK = $(subst $(IMAGE),$(IMAGE_IXK),$(QEMU_BOOT))
ix-kernel: ix
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-ixk IMAGE=$(IMAGE_IXK) BOOTDIR="$(filter-out dossrv=%,$(BOOTDIR_IX))" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXK)
run-ix: ix
	$(MINIQEMU) $(BOOT_IX)
# (A check runs its sessions all at once, each in its own emulator, and
# then compares their consoles; each one gets the card as a snapshot.
# ix's own sessions have many lines, so a line is typed 0.3 s after a
# prompt, not 1 s.)
IXQUIET = --quiet 0.3
# No page left (docs/plans/bugs/ix.md, 2026-10-10). Six programs at
# once ask for more than the board has (tests/hog asks for up to 128 MB
# each, of the 352 MB that the kernel gives processes under QEMU; it
# was 192 MB when this was written, and three programs were ended then,
# one now). The kernel ends those it cannot serve, by a note, and goes
# on: the shell answers afterwards, and a program runs. Which ones end
# is up to the scheduler, so the console is not compared. The check
# only looks that one was ended, that the lines after it are there,
# and that none is a panic.
check-hog: ix
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 120 --out $(B)/qemu-hog.txt --lines tests/session-hog.cmds -- $(QEMU) $(QEMU_BOOT_IX) || true
	@! grep -a panic $(B)/qemu-hog.txt && grep -a -q 'virtual memory' $(B)/qemu-hog.txt && grep -a -q '^still here' $(B)/qemu-hog.txt && grep -a -q '^hello from OCaml' $(B)/qemu-hog.txt \
	  && echo "ok 9pi: no page left: the processes ended ($$(grep -a -c 'virtual memory' $(B)/qemu-hog.txt) notes), the kernel goes on, under QEMU" \
	  || { echo "FAIL 9pi: no page left"; tail -5 $(B)/qemu-hog.txt; exit 1; }
# Several cores (docs/plans/plan_multicore.md). The Pi 2's kernel is
# built so that the other cores run processes under an emulator too
# (SMP=1; the recorded sessions use one core), and it runs under QEMU,
# which has the four cores. Four shells that compute run at once, then
# four that start processes (pipes of three, fifty each); then the
# threads and hello. Whose line comes first is up to the scheduler, so
# the lines are counted, not compared. (runtime.o says which kernel it
# is, so it is made again before and after, and the image is kept
# aside.)
check-cores:
	rm -f $(BUILD)/pi2$(PIX)-ix/c/runtime.o
	$(MAKE) ix BOARD=pi2 SMP=1 > /dev/null
	cp kernel-pi2-ix.img $(BUILD)/kernel-pi2-smp.img
	rm -f $(BUILD)/pi2$(PIX)-ix/c/runtime.o
	$(MAKE) ix BOARD=pi2 > /dev/null
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 300 --out $(BUILD)/qemu-cores.txt --lines tests/session-cores.cmds -- $(QEMU) $(subst kernel-$(BOARD)-ix.img,$(BUILD)/kernel-pi2-smp.img,$(QEMU_BOOT_IX)) || true
	@o=$(BUILD)/qemu-cores.txt; ! grep -a 'panic\|kernel fault' $$o && grep -a -q '(4 cores)' $$o \
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

# The graphical checks of ix's own programs (plan_rio.md, stage 7).
# Each one is a short session in the image of make ix-usb (or of make
# ix, for hellodraw), run under mini-qemu and under QEMU, and its
# screens are compared with the recorded ones (mini-qemu's).
# tests/graphics.py drives them with QEMU's USB keyboard and mouse, by
# steps (tests/NAME.steps, tests/NAME.md5). The names are not rio-NAME,
# because tests/rio-mini.md5 holds make check's rio screens and
# rio-c.md5 the C rio's.
#
#   draw      hellodraw (../../lib_graphics/tests): the display opened, a
#             colour, a thick line, text in Plan 9's default font
#             (tests/hellodraw.ppm.gz: one screen, no steps)
#   menu      hellomenu (the same directory): the mouse, the keyboard, a
#             menu shown, an item chosen, a key typed, "exit"
#   win-new      mini-rio (../../windows/rio): rio started at the console,
#             its menu, New (the cursor becomes a cross), a rectangle
#             swept out (seen half-way), a command in the window (with
#             mini-rc's answer there), hellorio in it (a program that
#             draws), q, and rc again
#   win-ops      a window moved, hidden and brought back by its name, and
#             made another size, with a command typed after each
#   win-border   a window's border used as a handle: the corner cursor
#             (with the mouse on the corner), the corner pulled with the
#             left button (seen half-way), the window pulled by its top
#             with the right button and by its left side with the middle
#             one, with a command after each
#   win-scroll   24 lines written, the arrows (scrolling back), the three
#             buttons in the scroll bar, and a command (which shows the
#             end again)
#   win-select  a word of the text swept with the left button (and
#             marked), the middle button's menu: snarf, then send (which
#             types the word to rc); /dev/snarf read (cat), then written
#             and sent again
#   win-utf8    a text that is not ASCII (tests/words.txt, in /boot):
#             shown (with a mark for the characters the font lacks), a
#             word of it selected and pasted, and two characters taken
#             back
#   win-files  a window's other files, and the double click: what is in
#             brackets, then a word, selected by two clicks; winid and
#             label read, label written (it becomes the hidden window's
#             name in the menu), text read; hellorio's own cursor (its
#             key c) while the mouse is in its window. It runs by make
#             check-files and is not yet among check-windows' sessions:
#             it is recorded under QEMU and not run under mini-qemu
#             (whose clicks are 0.1 second apart)
#   win-wctl   a window that does not scroll (the middle menu's
#             noscroll: seq 1 30 stops when the window is full, and the
#             down arrow shows more), then its wctl file: scroll, read,
#             resize, move, new with a command, bottom and top, hide,
#             unhide and delete by -id; its files at /mnt/wsys and by
#             $wsys (mounted elsewhere); the sizes of /dev/screen and
#             /dev/window. It runs with win-files in make check-files
#   win-script   rio -i: windows made by a script at the places -at gives
#             (a command that ends takes its window with it, unless -hold
#             keeps it), /dev/wsys, wctl's exit, and back at the console.
#             It runs with win-files in make check-files
#   win-layers   a desk (colors), a panel (hellorio, along the bottom), a
#             popup (hellorio) and rc: the keys stay in rc whatever is
#             pressed, a press elsewhere hides the popup, Delete cannot
#             point at the panel, and -max leaves the panel its room. It
#             runs with win-files in make check-files
#   win-panel   the panel along the bottom (with no clock, which would
#             change the screens): a press on a window's button brings
#             it to the front, hides it, brings it back; a window that
#             ends loses its button. It runs with win-files in make
#             check-files
#   win-menu   the start menu: shown and hidden by the start button, and
#             hidden by a press elsewhere; a group opened by the mouse, a
#             program opened from it, Exit. It runs with win-files in
#             make check-files
#   win-open   mini-files under rio: a file opened by Enter is in a new
#             window, and the files window stays as it is. It runs with
#             win-files in make check-files
#   win-desk   the desk: its wallpaper and icons, one icon selected by a
#             click and opened by a double click; rio's menu is still on
#             the right button.
#   win-expose   expose from the panel's button: three windows shrunk, one
#             of them hidden; a click brings each one to the front, and
#             the hidden one back. It runs with win-files in make
#             check-files
#   colors-bare  mini-colors (../../apps/misc) on the bare screen: a
#             square pointed at, and its menu's exit
#   colors-win   the same program in a window of mini-rio's, which is
#             moved and made another size, and the program draws again
#   tetris-bare  the playground's Tetris (../../games/puzzle,
#             plan_playground.md) on the bare screen: a session of 400
#             frames played at once by a script of keys (-frames,
#             -script), and its last picture, which the program draws
#             itself and gives whole to the draw device
#   tetris-win   the same in a window of mini-rio's, which is made
#             another size: the picture is drawn again, at that size
#   kbd-bare  the keys held (#c/kbd: plan_playground.md, stage 4), read
#             by hellokbd (../../lib_graphics/tests): keys pressed and
#             released, one held for a second and a half, and a line for
#             each change
#   kbd-win   the same in a window of mini-rio's, through the window's
#             own kbd
#   draw-tetris  Tetris by the platform that asks the draw device for
#             each shape (lib_playground/platforms/draw: filled
#             rectangles, words as lines; the games' own program,
#             tetris), with the same session as tetris-bare
#   draw-wolf    TinyWolfenstein by the same platform: the playground's
#             scene of a walk to a treasure (keys held by the script),
#             200 columns wide
#   drscheme-bare  mini-drscheme (../../editors/drscheme, plan_scheme.md's
#             stage 4) on the bare screen, driven by the mouse: Execute
#             clicked (120, three discs, the rocket's world run to its
#             end), two lines typed at the prompt (a list, and car's
#             error), Step clicked and the stepper's Step twice. With
#             fps=off, no frames a second are written, so the screen is
#             still when the program waits
#   drscheme-win   the same in a window of mini-rio's
#             (not in check-windows, but in make check-drscheme)
#   office-bare  mini-office (../../apps/office, plan_office.md's stage
#             5) on the bare screen: its start screen, Document clicked,
#             and a line typed in its text. It runs under QEMU only
#             (make check-office), because a page of text drawn stroke
#             by stroke is slow, and its speed is not measured yet
#
#   make check-windows   runs all of them side by side (draw and the 15
#                        of GSESSIONS, each under mini-qemu and QEMU,
#                        GJOBS=16 emulators at once), so we wait about
#                        as long as the longest
#   make check-draw, check-menu, check-rio, check-colors, check-tetris
#                        run a part of them
#   make check-quick     runs five of them under QEMU only, in a minute
#   make expected-windows   records their screens again, side by side
#                        (under QEMU, in seven minutes); expected-NAME
#                        records one of them
#
# A session that shows another screen than the recorded one stops there
# (graphics.py), after waiting a minute for it, because what follows
# would be typed at the wrong place. The steps' pauses (GFX_PAUSE: after
# a key, and after a button's change) are shorter than those of the C
# rio's check (0.5 and 2 seconds). With 0.2 for a key, a key was lost
# once under QEMU.
GFX_PAUSE = 0.3,1
# (It is not named GFX, which is principia's lib_graphics, for the C
# pixels above.)
GRAPHICS = tests/graphics.py --step 3 --pause $(GFX_PAUSE)
# (With the card, because mini-rio and the programs of its windows are
# on its second partition, not in the kernel's image.)
MENU_USB = -serial mon:stdio -display none $(USB) $(CARD_SD)
# (KUSB=1 uses the image without usbd, where the kernel finds and reads
# the keyboard and the mouse itself, through Kusb: make
# check-windows-kernel.)
MINI_USB = $(MINIQEMU) $(subst -nographic,,$(if $(KUSB),$(BOOT_IX),$(BOOT_IXU))) $(MENU_USB)
QEMU_USB = $(QEMU) $(subst -nographic,,$(if $(KUSB),$(QEMU_BOOT_IX),$(QEMU_BOOT_IXU))) $(MENU_USB)
DRAW = $(SESSION_PY) --prompt "% " --timeout 180 --out $(B)/$(1)-draw.txt --screendump $(B)/$(1)-draw.ppm hellodraw --
GSESSIONS = menu win-new win-ops win-border win-scroll win-select win-utf8 colors-bare colors-win tetris-bare tetris-win kbd-bare kbd-win draw-tetris draw-wolf

# A session (with no build: the images are there already), and the
# comparison of what it wrote with what is recorded.
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
# (Recording runs a session without --expect, and a screen is recorded
# when it stays still for three steps. It runs under QEMU, whose
# screens are mini-qemu's, since the checks hold them to that. A boot
# takes 5 seconds there instead of 27, and a step may be 4 seconds
# where mini-qemu's had to be 8, because its boot stood still for more
# than 9 seconds before its prompt. So a screen takes 12 seconds, not
# 24, and the 17 sessions, drscheme's two among them, take 7 minutes,
# where 15 sessions took 17 under mini-qemu (the author: "this is slow,
# any way we can improve the speed of those tests?"). Under mini-qemu,
# the recording would be:
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

# Devices unplugged and plugged again while mini-usbd runs (stage 2 of
# plan_rio.md's USB). The mouse and the keyboard are taken out (QMP's
# device_del, by their ids), others are put in (device_add), and rio is
# started with them and shows its menu. This runs with mini-usbd, then
# with the kernel's own USB. It runs under QEMU only, because mini-qemu
# has no device_add yet.
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

# Every build and every check of this directory, one after the other,
# stopping at the first that fails, so that this target's exit status
# says whether all the checks pass (plan_rio.md, 2026-10-06: three
# builds had been broken for a day, each by a change checked only with
# the checks someone remembered to run). It takes some 10 minutes. The
# graphical sessions are tried a second time when one fails, because 16
# emulators side by side lose a key or a screen on a busy machine (with
# a load of 45 that day, win-utf8 failed once, and passed twice alone).
#   the two pixels (PIXEL=c, then the default again, in one image file)
#   check                 the twin's checks: 9pi's console and screens
#   check-ix check-card   ix's programs, and the card (dossrv, Kdos)
#   check-audio           /dev/audio: what mini-qemu's jack played
#   check-windows         the graphical sessions, with mini-usbd
#   check-windows-kernel  the same with the kernel's own USB (Kusb)
#   check-plug            devices unplugged and plugged (under QEMU)
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

# Some of the graphical checks, side by side: their sessions, then the
# comparisons (with -k, so that every result is said).
# (GJOBS is how many emulators run at once.)
GJOBS ?= 16
gcheck = $(MAKE) --no-print-directory -j$(GJOBS) $(foreach s,$(1),run-$(s)-mini run-$(s)-qemu); $(MAKE) --no-print-directory -k $(foreach s,$(1),cmp-$(s))
check-draw: ix ; $(call gcheck,draw)
check-menu: ix-usb card ; $(call gcheck,menu)
check-rio: ix-usb card ; $(call gcheck,win-new win-ops win-border win-scroll win-select win-utf8)
check-files: ix-usb card ; $(call gcheck,win-files win-wctl win-script win-layers win-panel win-menu win-open win-desk win-expose)
check-colors: ix-usb card ; $(call gcheck,colors-bare colors-win)
check-tetris: ix-usb card ; $(call gcheck,tetris-bare tetris-win)
check-kbd: ix-usb card ; $(call gcheck,kbd-bare kbd-win)
check-games-draw: ix-usb card ; $(call gcheck,draw-tetris draw-wolf)
check-drscheme: ix-usb card ; $(call gcheck,drscheme-bare drscheme-win)
#   turbopascal-bare  mini-turbopascal (../../editors/turbopascal,
#             plan_pascal.md's stage 6) on the bare screen, 51 rows of
#             113 cells in Plan 9's font: F10's menu, Escape, PageDown,
#             Control-F9 (the queens on the user screen), a key, a
#             letter typed, and F9's error in the red bar
#   turbopascal-win   the same in a window of mini-rio's: the menu, a
#             run, then the window made smaller from rio's menu (14
#             rows of 42), PageDown, F7 and F8 (the execution bar).
#             Both run under QEMU only (make check-turbopascal)
check-turbopascal: ix-usb card
	$(MAKE) --no-print-directory -j2 run-turbopascal-bare-qemu run-turbopascal-win-qemu; $(MAKE) --no-print-directory -k cmpq-turbopascal-bare cmpq-turbopascal-win
check-office: ix-usb card
	$(MAKE) --no-print-directory run-office-bare-qemu; $(MAKE) --no-print-directory cmpq-office-bare
# A few of them, under QEMU only, in a minute: what one runs while
# changing something (the menu, a window of mini-rio's, the keys held,
# a game by the draw device, mini-drscheme on the bare screen). The
# whole set is check-windows and check-drscheme, with mini-qemu too.
GQUICK = menu win-new kbd-bare draw-wolf drscheme-bare
check-quick: ix-usb card
	$(MAKE) --no-print-directory -j$(GJOBS) $(GQUICK:%=run-%-qemu); $(MAKE) --no-print-directory -k $(GQUICK:%=cmpq-%)
cmpq-%:
	cd $(B)/g-$*-qemu && md5sum --quiet -c $(CURDIR)/tests/$*.md5 && echo "ok 9pi: $*: its $$(wc -l < $(CURDIR)/tests/$*.md5) screens under QEMU"
check-windows: ix-usb card ; $(call gcheck,draw $(GSESSIONS))
# The same sessions and the same screens with no usbd, using the
# kernel's own USB (Kusb).
check-windows-kernel: ix card ; $(MAKE) --no-print-directory KUSB=1 GJOBS=$(GJOBS) gcheck-all
gcheck-all: ; $(call gcheck,$(GSESSIONS))
.PHONY: check-drscheme check-office check-turbopascal check-quick check-windows expected-windows cmp-draw run-draw-mini run-draw-qemu

# The SD card (plan_rio.md, stage 3). make card makes $(BUILD)/card.img
# with mini-mkcard (../tools). The card has an MBR, a FAT16 with the
# Pi 1's and the Pi 2's firmware (../firmware), conf/config.txt and the
# images of make ix for the two boards (the firmware loads its own
# board's), and a second partition with xv6's file system (CARD_FS,
# below). To write it to a real card:
# dd if=$(BUILD)/card.img of=/dev/sdX bs=1M.
#   make check-card  reads the card with the host's tools (its
#                    partitions, the FAT checked, the kernel read back),
#                    then with principia's (fdisk, dossrv:
#                    tests/boot-card.rc as /boot/boot,
#                    tests/session-card.cmds) under mini-qemu and QEMU,
#                    with the console as in tests/session-card. Then it
#                    reads it with ix's own: mini-dossrv
#                    (filesystems/user/dossrv) in the image of make ix,
#                    whose conf/boot.rc mounts the card (mini-fdisk,
#                    mini-dossrv: tests/session-card-ix.cmds,
#                    tests/session-card-ix). Then the kernel itself
#                    reads the same files (Kdos: bind '#Fdos' /mnt).
CARD = $(BUILD)/card.img
# (The kernel's image on the card changes size with every program in
# it. So its size is not compared, nor are the listing's columns, which
# it widens.)
cardsize = sed -E -e 's/ +/ /g' -e 's/ [0-9]+ (Sep 26 (2026|00:MM) [a-z\/]*\/(MINI9PI1\.IMG|mini9pi1\.img))/ SIZE \1/'
MKCARD = ../../_build/default/kernels/tools/Mkcard.exe
FIRMWARE = ../firmware/pi1-pi2
CARD_SD = -drive file=$(CARD),if=sd,format=raw,snapshot=on
card: ix
	$(MAKE) BOARD=pi2 ix
	$(MAKE) $(CARD)
	@$(if $(filter card,$(MAKECMDGOALS)),$(cardhelp))
# The card to build ix on (docs/plans/plan_self_hosting.md). It has the
# same programs, ix's sources in /src (the repository except docs/:
# 4,900 files, 18 MB), the whole toolchain in /progs/toolchain, and room
# for what a build makes (346 MB for mini-9pi's programs). It is 1 GB,
# while the everyday card stays 256 MB and is flashed 4 times faster.
card-self: ix
	$(MAKE) BOARD=pi2 ix
	rm -f $(BUILD)/card-self-fs.img
	$(MAKE) SELF=1 $(BUILD)/card-self.img
# ix built by ix on that card, on the Pi 2 under QEMU (with one core:
# boot.rc's NPROC). Each file it makes is compared with Linux's from
# the same sources (tests/self.sh, tests/self.rc; $(BUILD)/self/).
# self-quick builds a part of lib_core (its C library, the runtime,
# three units) and two programs linked with them, one in C and one in
# OCaml, and runs them (tests/self/). It takes 4 minutes, where self
# takes 3 hours.
self self-quick: card-self
	cd ../.. && dune build ./kernels/9pi/filesystems/lib_xv6fs/tests/Xv6test.exe
	$(MAKE) --no-print-directory BOARD=pi2 SELFQ=$(if $(filter self-quick,$@),-q) self-run
.PHONY: self self-quick self-run
self-run:
	tests/self.sh $(SELFQ) $(BUILD)/card-self.img $(BUILD)/self -- $(QEMU) $(QEMU_BOOT_IX)
# What make card says last (but not when card is another target's
# prerequisite): where the image is and how to put it on a card. The
# reader must find the device, because a wrong one means a disk erased.
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
# The second partition holds xv6's file system (made by mini-mkfs, from
# lib_xv6fs; the kernel's Kfs reads and writes it). It is the system's
# root (boot.rc binds it at /root, and at / after the kernel's own
# directories), laid out as Plan 9's is:
#   progs      the programs that are not in the kernel's image, in a
#              directory for each kind, so that one browses them as one
#              browses the sources (the author: "/progs/apps/ /progs/games/
#              /progs/utilities/ so less category otherwise we can get
#              one folder for each program"; "we could have a /progs/system/
#              and put rio, free inside it";
#              "as soon as one directory contain more than 10 programs,
#              then we can further refine in extra subfolders", "but
#              let's try avoid having folders with just one program").
#              Each directory is bound after /bin, which then has them
#              all (boot.rc does it through the card's /lib/namespace,
#              written below):
#                system     the window system, its desktop and what
#                           shows the system's state: rio, panel,
#                           startmenu, desk, settings, expose, ps, free
#                apps       what a person opens: colors, files, open,
#                           stats, office, page, play, rebirth
#                devtools   the editors and the languages that are run
#                           ("like we have for the book category" of
#                           principia-softwarica.org, its Developer
#                           tools): emacs, drscheme, turbopascal,
#                           squeak, scheme, pascal, prolog, dotnet,
#                           tiger
#                games      tetris, missilecommand, wolfenstein, doom,
#                           quake, virtua, cameltry, breakout,
#                           tronscroll (which plays on two boards, over
#                           the network)
#                net        mini-netscape and the networking programs
#                           ("we could have /progs/net/ and put the
#                           mini-netscape in it at some point"):
#                           netscape, maps, lynx, curl, timesync
#                utilities  the programs of utilities/, in its
#                           directories. A directory with more than ten
#                           programs is cut further, and there is none
#                           for a single program, so cmp, unmount and
#                           xd are in misc. The directories are files,
#                           text, pipe, process, calc, time (date and
#                           cal, because with cal misc would have
#                           eleven), archive (tar, gzip, gunzip) and
#                           misc
#                typesetting  troff and man
#                examples   hello, hellorio, hellokbd, tone (which
#                           writes half a second of sound: tone >
#                           /dev/audio)
#              and, when they are on the card, toolchain: the
#              assembler, the linker, the compilers ("I was thinking of
#              /progs/toolchain actually for mini-asm, mini-ld, etc.";
#              plan_self_hosting.md)
#   rc/bin     the commands that are scripts (kill, window, desktop),
#              also bound after /bin
#   usr/pad    a user's directory, where the shell starts
#   mnt/fat    where the card's first partition, the firmware's FAT, is
#              mounted
#   mnt/wsys   where a window's process mounts its window's files
#              (mini-rio's, as with rio), bound before /dev
#   lib        the namespace (/lib/namespace) and the desktop's tables,
#              icons and start script (/lib/desktop). Then the files of
#              the languages: scheme's queens.scm, pascal's types.pas
#              (which does not compile) and prolog's classics.pl, for
#              check-scheme, check-pascal and check-prolog; the
#              survey's .NET assemblies in
#              /lib/dotnet and Tiger's programs in /lib/tiger, for
#              check-dotnet; mini-analyze's .NET road in /lib/analyze,
#              with its C report and a program for it, bugs.c
#              (plan_dotnet_languages.md, stage 8).
#              Then three small PDF files for page (page
#              /lib/pdf/tex.pdf shows two pages from pdfTeX;
#              docs/plans/done/plan_pdf.md, C2).
#              Then the manual, /lib/man/1 (man troff looks there when
#              there is no /sys/man; these are ix's own pages from
#              docs/man, written in the new format), with troff's page
#              as a PDF file too (/lib/pdf/troff.pdf;
#              docs/plans/done/plan_typesetting.md, stage 8).
#              Then a book of principia's, when it is there: its
#              Kernel, 1083 pages, 3 MB (page /lib/pdf/kernel.pdf is
#              what mini-page is most used for; BOOKS= names the clone).
#              Then a small video, /lib/videos/ball.mpg.
#              Then six small sound files for play (/lib/sounds: a MOD,
#              a MIDI file, an ABC tune, two MP3s and an MP2, from
#              lib_audio/tests/data; play /lib/sounds/tune.mod;
#              docs/plans/plan_audio.md, stage 5).
#              Then the roots a certificate is checked against
#              (/lib/tls/ca.pem, this machine's, where Tls_client looks
#              on a card), for https:// in netscape, lynx and curl.
#              Then doom's WAD (/lib/doom/freedoom.wad, Freedoom's
#              E1M1, from games/fps/doom/data;
#              docs/plans/done/plan_doom.md).
#              Then quake's level (/lib/quake/e0m1.bsp, with its
#              palette.lmp and colormap.lmp, and its models and sounds
#              in progs/ and sound/: LibreQuake's lq_e0m1, from
#              games/fps/quake/data; docs/plans/done/plan_quake.md).
#   usr/pad/lib/documents  the store of documents (mini-office's Open
#              and Save), with two pictures for its Insert > Image...
#              (a PNG and a JPEG: docs/plans/done/plan_office.md,
#              stage 7)
#   src        sources: for now five small programs, OCaml's hello.ml,
#              hellodraw.ml and hellorio.ml (three programs of the
#              card), C's hello.c and the assembler's hello.s, as texts
#              to open (emacs /src/hello.ml)
#   tmp
CARD_apps = colors=$(IX9)/apps/misc/mini-colors files=$(IX9)/apps/files/files open=$(IX9)/apps/files/open stats=$(IX9)/profilers/misc/mini-stats office=$(IX9)/apps/office/office page=$(IX9)/apps/page/pageview play=$(IX9)/apps/media/play/mini-play rebirth=$(IX9)/apps/music/rebirth/rebirth
CARD_system = rio=$(IX9)/windows/rio/mini-rio panel=$(IX9)/windows/desktop/panel startmenu=$(IX9)/windows/desktop/startmenu desk=$(IX9)/windows/desktop/desk settings=$(IX9)/windows/desktop/settings expose=$(IX9)/windows/desktop/expose ps=$(IX9)/utilities/process/mini-ps free=$(IX9)/utilities/process/mini-free
CARD_devtools = emacs=$(IX9)/editors/emacs/draw/emacs drscheme=$(IX9)/editors/drscheme/drscheme turbopascal=$(IX9)/editors/turbopascal/hosts/draw/turbopascal \
  squeak=$(IX9)/languages/smalltalk/hosts/draw/squeak scheme=$(IX9)/languages/scheme/mini-scheme pascal=$(IX9)/languages/pascal/mini-pascal \
  prolog=$(IX9)/languages/prolog/mini-prolog dotnet=$(IX9)/languages/dotnet/mini-dotnet tiger=$(IX9)/languages/tiger/mini-tiger
# (The games have no -soft variant, for the playground's software
# platform: it is slower, and the games draw by software already.)
CARD_games = tetris=$(IX9)/games/puzzle/tetris missilecommand=$(IX9)/games/shmup/tinymissilecommand wolfenstein=$(IX9)/games/fps/tinywolfenstein \
  doom=$(IX9)/games/fps/doom/mini-doom quake=$(IX9)/games/fps/quake/mini-quake virtua=$(IX9)/games/racing/virtua/mini-virtuaracing \
  cameltry=$(IX9)/games/arcade/tinycameltry breakout=$(IX9)/games/arcade/tinybreakout tronscroll=$(IX9)/games/arcade/tinytronscroll
CARD_utilities/files = pwd=$(IX9)/utilities/files/mini-pwd mkdir=$(IX9)/utilities/files/mini-mkdir rm=$(IX9)/utilities/files/mini-rm \
  cp=$(IX9)/utilities/files/mini-cp mv=$(IX9)/utilities/files/mini-mv touch=$(IX9)/utilities/files/mini-touch chmod=$(IX9)/utilities/files/mini-chmod \
  mtime=$(IX9)/utilities/files/mini-mtime walk=$(IX9)/utilities/files/mini-walk
CARD_utilities/text = grep=$(IX9)/utilities/text/mini-grep uniq=$(IX9)/utilities/text/mini-uniq tr=$(IX9)/utilities/text/mini-tr \
  sed=$(IX9)/utilities/text/mini-sed sort=$(IX9)/utilities/text/mini-sort awk=$(IX9)/utilities/text/awk/mini-awk
CARD_utilities/pipe = tee=$(IX9)/utilities/pipe/mini-tee tail=$(IX9)/utilities/pipe/mini-tail xargs=$(IX9)/utilities/pipe/mini-xargs
CARD_utilities/process = sleep=$(IX9)/utilities/process/mini-sleep spin=$(IX9)/utilities/process/mini-spin time=$(IX9)/utilities/process/mini-time
CARD_utilities/calc = hoc=$(IX9)/utilities/calc/hoc/mini-hoc dc=$(IX9)/utilities/calc/dc/mini-dc bc=$(IX9)/utilities/calc/bc/mini-bc
CARD_utilities/time = date=$(IX9)/utilities/time/mini-date cal=$(IX9)/utilities/time/mini-cal
CARD_utilities/archive = tar=$(IX9)/utilities/archive/mini-tar gzip=$(IX9)/utilities/archive/mini-gzip gunzip=$(IX9)/utilities/archive/mini-gunzip
CARD_utilities/misc = wc=$(IX9)/utilities/misc/mini-wc basename=$(IX9)/utilities/misc/mini-basename \
  cmp=$(IX9)/utilities/compare/mini-cmp unmount=$(IX9)/utilities/namespace/mini-unmount seq=$(IX9)/utilities/misc/mini-seq \
  cleanname=$(IX9)/utilities/misc/mini-cleanname du=$(IX9)/utilities/misc/mini-du xd=$(IX9)/utilities/byte/mini-xd test=$(IX9)/utilities/misc/mini-test
CARD_examples = hellorio=$(IX9)/windows/rio/tests/hellorio hellokbd=$(IX9)/lib_graphics/tests/hellokbd hello=$(IX9)/kernels/9pi/tests/hello/hello tone=$(IX9)/kernels/9pi/tests/tone/tone
# the typesetter and the manual (docs/plans/done/plan_typesetting.md, stage 8)
CARD_typesetting = troff=$(IX9)/typesetting/troff/mini-troff man=$(IX9)/typesetting/man/mini-man
# the assembler and the linker, to build ix on the card
# (docs/plans/plan_self_hosting.md, stage 1)
CARD_toolchain = asm=$(IX9)/assembler/mini-asm ld=$(IX9)/linker/mini-ld
# the browsers and the network's programs (plan_browser.md, stage 10)
CARD_net = netscape=$(IX9)/browsers/netscape/netscape maps=$(IX9)/apps/maps/mini-maps lynx=$(IX9)/browsers/lynx/mini-lynx curl=$(IX9)/networking/mini-curl timesync=$(IX9)/networking/mini-timesync
CARD_PROGS = system apps devtools toolchain games net utilities/files utilities/text utilities/pipe utilities/process utilities/calc utilities/time utilities/archive utilities/misc typesetting examples
CARD_BIN = $(foreach d,$(CARD_PROGS),$(CARD_$(d)))
card_progs = $(foreach d,$(CARD_PROGS),$(addprefix progs/$(d)/,$(CARD_$(d))))
MKFS = ../../_build/default/kernels/tools/Mkfs.exe
# The card's size in megabytes (a power of 2, as QEMU wants) and its
# second partition's, which is what the FAT's 32 MB and the first
# megabyte leave. It was 64 and 31, which were full at 43 programs
# (2026-10-07: a program of ix's is 0.7 to 1.2 MB, because its library
# is linked whole); a real card has gigabytes. Then it was 128 and 95,
# full at 95.7 MB of files with mini-analyze's .NET road (2026-11-02;
# its runtime is 2.3 MB). Now it is 256, which takes twice the time to
# write.
CARD_MB = 256
CARD_FS_MB = 223
CARD_FS = $(BUILD)/card-fs.img
# How many files and directories it can have at most. xv6's 200 were
# full when the manual reached 93 pages (2026-10-14).
CARD_FS_INODES = 1024
# (Principia's book is on the card if the clone is there, and not
# otherwise.)
BOOKS ?= $(HOME)/github/principia-softwarica
CARD_BOOK = $(if $(wildcard $(BOOKS)/kernel/Kernel-12.pdf),lib/pdf/kernel.pdf=$(BOOKS)/kernel/Kernel-12.pdf)
# The manual's pages, ix's own (docs/man/1), named without their .md,
# as Plan 9's are. turbopascal-tty's page is left out, because its
# program is not on the card.
CARD_MAN = $(foreach f,$(filter-out %/turbopascal-tty.md,$(wildcard ../../docs/man/1/*.md)),lib/man/1/$(basename $(notdir $(f)))=$(f))
# Quake's models and sounds, which it reads beside its level. Without
# them its monsters were neither drawn nor heard. (Its music, in
# Vorbis, is off on Plan 9.)
QUAKE_DATA = ../../games/fps/quake/data
CARD_QUAKE = $(foreach f,$(wildcard $(QUAKE_DATA)/progs/*.mdl $(QUAKE_DATA)/sound/*/*.wav),lib/quake/$(f:$(QUAKE_DATA)/%=%)=$(f))
CARD_LIB = lib/desktop/apps=../../windows/desktop/apps.table lib/desktop/desk=../../windows/desktop/desk.table $(foreach f,$(wildcard ../../windows/desktop/icons/*.txt),lib/desktop/icons/$(notdir $(f))=$(f)) rc/bin/window=../../windows/rio/window.rc rc/bin/desktop=../../windows/desktop/desktop.rc lib/desktop/start=../../windows/desktop/start.rc \
  lib/scheme/queens.scm=../../languages/scheme/tests/queens.scm lib/pascal/types.pas=../../languages/pascal/tests/types.pas \
  lib/prolog/classics.pl=../../languages/prolog/tests/classics.pl \
  $(foreach p,hello fib queens shapes exceptions strings vec generic collections closures,lib/dotnet/$(p).dll=../../languages/dotnet/survey/programs/$(p).dll) \
  lib/dotnet/unhandled.dll=../../languages/dotnet/tests/programs/unhandled.dll \
  $(foreach p,queens sieve exceptions merge,lib/tiger/$(p).tig=../../languages/tiger/tests/programs/$(p).tig) \
  $(foreach f,$(ANALYZE_DLLS),lib/analyze/$(notdir $(f))=$(f)) lib/analyze/bugs.c=../../analyzers/tests/c/bugs/bugs.c \
  $(CARD_MAN) lib/pdf/troff.pdf=$(TROFF_PDF) \
  $(CARD_BOOK) \
  lib/pdf/tex.pdf=../../lib_graphics/pdf/tests/data/tex.pdf lib/pdf/shapes.pdf=../../lib_graphics/pdf/tests/data/shapes.pdf lib/pdf/standard.pdf=../../lib_graphics/pdf/tests/data/standard.pdf \
  lib/videos/ball.mpg=../../lib_graphics/videos/tests/clips/ball_and_square.mpg lib/sounds/tune.mod=../../lib_audio/tests/data/tiny_soundtracker.mod lib/sounds/theme.mid=../../lib_audio/tests/data/korobeiniki.mid lib/sounds/theme.abc=../../lib_audio/tests/data/korobeiniki.abc \
  lib/sounds/mono.mp3=../../lib_audio/tests/data/lsf_mono.mp3 lib/sounds/stereo.mp3=../../lib_audio/tests/data/lame_encoded.mp3 lib/sounds/bell.mp2=../../lib_audio/tests/data/bell.mp2 \
  lib/tls/ca.pem=$(CA_PEM) \
  lib/doom/freedoom.wad=../../games/fps/doom/data/freedoom.wad \
  lib/quake/e0m1.bsp=../../games/fps/quake/data/e0m1.bsp lib/quake/palette.lmp=../../games/fps/quake/data/palette.lmp \
  lib/quake/colormap.lmp=../../games/fps/quake/data/colormap.lmp $(CARD_QUAKE) \
  usr/pad/lib/documents/shapes.png=../../lib_graphics/pdf/tests/data/shapes-1.png usr/pad/lib/documents/aldrin.jpg=../../apps/office/pictures/aldrin.jpg
# A first /src: small programs in the languages ix is written in, to
# open with emacs for now. Later, ix's sources will be on the card, and
# ix built from them there (docs/plans/plan_self_hosting.md).
CARD_SRC = src/hello.ml=tests/hello/Hello.ml src/hellodraw.ml=../../lib_graphics/tests/Hellodraw.ml src/hellorio.ml=../../windows/rio/tests/Hellorio.ml \
  src/hello.c=../steps/step0/hello.c src/hello.s=../../linker/tests/golden/hello_plan9_arm.s
ifdef SELF
CARD = $(BUILD)/card-self.img
CARD_FS = $(BUILD)/card-self-fs.img
CARD_MB = 1024
CARD_FS_MB = 991
CARD_FS_INODES = 16384
CARD_toolchain += ml=$(IX9)/languages/ml/mini-ml cc=$(IX9)/languages/c/mini-cc mk=$(IX9)/builder/mini-mk ar=$(IX9)/linker/tools/mini-ar \
  lex=$(IX9)/generators/lex/mini-lex yacc=$(IX9)/generators/yacc/mini-yacc
# (The files are not prerequisites, because some are names that match
# this Makefile's patterns, such as expected-%. card-self makes its file
# system again each time instead.)
# (Only files: the symbolic links in git are copied, except bin, which
# is a link to a directory. /src is the repository, as in tiny-kernel's
# image, instead of the everyday card's five small examples. Without
# git, as in Docker's image, it has the files that tests/ix_files.sh
# finds.)
IX_FILES = git ls-files -co --exclude-standard 2>/dev/null || tests/ix_files.sh
CARD_IX := $(foreach f,$(shell cd ../.. && { $(IX_FILES); } | grep -v '^docs/\|^_' | while read f; do [ -f "$$f" ] && echo "$$f"; done),src/$(f)=../../$(f))
CARD_SRC =
endif
# The binds that make /bin out of these directories, one for each: the
# card's /lib/namespace, lines of rc that boot.rc reads. (Plan 9's file
# of that name has its own format, which newns reads.)
CARD_NS = $(BUILD)/card-namespace
# troff's own page as a PDF file, made by the host's mini-troff. It is
# for page (page /lib/pdf/troff.pdf), and it is also what the card's
# troff must write, byte for byte (tests/session-card-typeset.cmds
# compares them with cmp).
TROFF_PDF = $(BUILD)/troff.pdf
$(TROFF_PDF): ../../docs/man/1/troff.md ../../_build/default/typesetting/troff/Main.exe
	@mkdir -p $(BUILD)
	../../_build/default/typesetting/troff/Main.exe -T pdf ../../docs/man/1/troff.md > $@
# mini-analyze's .NET road and its C report, built by
# analyzers/dotnet/tests/run.sh -build. make card puts them on the
# card, where mini-dotnet runs them on the board:
#   dotnet /lib/analyze/report.dll -fingerprint /lib/analyze/bugs.c
ANALYZE_DLLS = $(BUILD)/analyze/analyze_rt.dll $(BUILD)/analyze/fingerprint.dll $(BUILD)/analyze/report.dll
$(ANALYZE_DLLS) &: ../../_build/default/languages/ml/Main.exe ../../_build/default/languages/datalog/Main.exe \
  ../../_build/default/languages/c/Main.exe $(wildcard ../../analyzers/*/*.ml ../../analyzers/dotnet/*.c ../../analyzers/datalog/*.dl ../../analyzers/datalog/points_to/*.dl)
	cd ../.. && WORK=$(abspath $(BUILD))/analyze analyzers/dotnet/tests/run.sh -build
$(CARD_NS): Makefile
	@mkdir -p $(BUILD)
	for d in $(CARD_PROGS); do echo "bind -a /root/progs/$$d /bin"; done > $@
$(CARD_FS): Makefile $(MKFS) $(CARD_NS) tests/card-motd.txt ../../utilities/process/kill.rc $(foreach p,$(CARD_LIB) $(CARD_SRC),$(lastword $(subst =, ,$(p)))) $(foreach p,$(CARD_BIN),$(lastword $(subst =, ,$(p))))
	$(MKFS) -m $(CARD_FS_MB) -i $(CARD_FS_INODES) $@ $(card_progs) lib/namespace=$(CARD_NS) rc/bin/kill=../../utilities/process/kill.rc usr/pad/readme=tests/card-motd.txt $(CARD_LIB) $(CARD_SRC) $(CARD_IX) mnt/fat/ mnt/wsys/ tmp/
# version.txt says which card this is, in a line that boot.rc prints
# last on a board (but not under an emulator, because of the recorded
# screens). It has mini-9pi's version (the first in changes.txt), the
# commit (with a + when the tree differs from it), and the minute this
# rule ran, which is when the kernel, a program, the firmware or
# config.txt last changed.
CARD_VERSION = $(BUILD)/card-version.txt
$(CARD): $(MKCARD) $(CARD_FS) conf/config.txt kernel-pi1-ix.img kernel-pi2-ix.img $(wildcard $(FIRMWARE)/*)
	echo "mini-9pi $$(sed -n 's/^\* \([0-9.]*\) .*/\1/p' ../../changes.txt | head -1) ($$(git rev-parse --short=8 HEAD 2>/dev/null || echo no git)$$(git diff --quiet HEAD 2>/dev/null; [ $$? = 1 ] && echo +)), card of $$(date '+%Y-%m-%d %H:%M')" > $(CARD_VERSION)
	$(MKCARD) -m $(CARD_MB) -date $(KERNDATE_IX) -fs $(CARD_FS) $@ bootcode.bin=$(FIRMWARE)/bootcode.bin start_cd.elf=$(FIRMWARE)/start_cd.elf \
	  fixup_cd.dat=$(FIRMWARE)/fixup_cd.dat config.txt=conf/config.txt version.txt=$(CARD_VERSION) mini9pi1.img=kernel-pi1-ix.img mini9pi2.img=kernel-pi2-ix.img
IMAGE_CARD = $(basename $(IMAGE))-card$(suffix $(IMAGE))
ifneq ($(findstring -card.,$(IMAGE)),-card.)
$(IMAGE_CARD): FORCE
	$(MAKE) B=$(BUILD)/$(BOARD)$(PIX)-card IMAGE=$@ BOOTRC=tests/boot-card.rc BOOTMORE=cat $@
endif
BOOT_CARD = $(subst $(IMAGE),$(IMAGE_CARD),$(BOOT))
QEMU_BOOT_CARD = $(subst $(IMAGE),$(IMAGE_CARD),$(QEMU_BOOT))
# ix's own sessions with the card, each a short one, all run at once
# (docs/notes/notes_performance.md, 3). They check:
#   - the card as boot.rc leaves it, and its FAT (through mini-dossrv,
#     then through the kernel's device)
#   - utilities/'s programs on the root (files made, copied, renamed,
#     dated, removed), and on the FAT
#   - the programs that read (date, wc, tee, cmp)
#   - the rest (seq, du, sleep, cleanname, unmount)
#   - the ones that look into a file (grep, tail, xd)
#   - the filters (sort, uniq, tr, sed)
#   - the processes (ps, time, kill)
#   - what a script asks and builds with (test, xargs)
#   - the ones that compute (hoc, awk, dc, bc)
#   - the ones that typeset (man, troff: a page for the terminal, the
#     page written again in the new format, and as a PDF file)
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

# The languages that are run, at the console (stage 2 of plan_scheme.md
# and plan_pascal.md, stage 4 of plan_prolog.md). Each has a session,
# run under mini-qemu and QEMU, and its console must be as recorded
# (tests/session-card-scheme, -pascal, ...). A line is also typed at the
# program's own prompt (session.py's --also): scheme's "> " and, inside
# an expression, "  "; GUESS.PAS's "Your guess? "; prolog's "?- " and,
# after an answer that may not be the last, " ? ".
#   make check-scheme   a file run (the eight queens, with lists), lines
#                       at the prompt, an error and its message, the
#                       stepper
#   make check-pascal   the disk's programs (the queens, and one that
#                       asks for a line), their P-code, a type error
#   make check-prolog   the classical programs run by both machines (the
#                       second with -wam), goals at the prompt and ; for
#                       the next answer, the WAM's code, the errors
#   make check-dotnet   Microsoft's assemblies run (the survey's), one
#                       listed (-S), an exception no one catches, three
#                       run with -jit (their code in segments:
#                       segattach, segflush); a Tiger program compiled by
#                       tiger and run (plan_dotnet.md's stages 4 and 10)
#   make expected-langs records the four consoles again (under QEMU)
langcheck = $(SESSION_PY) $(IXQUIET) --prompt "% " $(2) --timeout 900 --out $(B)/mini-card-$(1).txt --lines tests/session-card-$(1).cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD) & \
	$(SESSION_PY) $(IXQUIET) --prompt "% " $(2) --timeout 300 --out $(B)/qemu-card-$(1).txt --lines tests/session-card-$(1).cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD) & \
	wait; \
	$(call unwarned,$(B)/mini-card-$(1).txt) | diff - tests/session-card-$(1) && echo "ok card: $(1) at the console (tests/session-card-$(1)), under mini-qemu" && \
	$(call unwarned,$(B)/qemu-card-$(1).txt) | diff - tests/session-card-$(1) && echo "ok card: the same under QEMU"
check-scheme: card ; $(call langcheck,scheme,--also "> " --also "  ")
check-pascal: card ; $(call langcheck,pascal,--also "? ")
check-prolog: card ; $(call langcheck,prolog,--also "?- " --also " ? ")
check-dotnet: card ; $(call langcheck,dotnet)
# mini-analyze's .NET road on the card (plan_dotnet_languages.md, stage
# 8): mini-dotnet makes its C report of /lib/analyze/bugs.c under QEMU,
# and each line of the native mini-analyze's report must be in it. It
# takes 90 s, with the card made and booted.
check-analyze: card
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 3000 --out $(B)/qemu-card-analyze.txt --lines tests/session-card-analyze.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	cd ../../analyzers/tests/c/bugs && ../../../../_build/default/analyzers/Main.exe -r ../../../../analyzers/datalog -fingerprint bugs.c > $(abspath $(B))/analyze-native.txt
	tr -d '\r' < $(B)/qemu-card-analyze.txt | grep -Fxv -f - $(B)/analyze-native.txt > $(B)/analyze-missing.txt; \
	  if [ -s $(B)/analyze-missing.txt ]; then echo "FAIL card: mini-analyze's .NET road, lines not said:"; cat $(B)/analyze-missing.txt; exit 1; \
	  else echo "ok card: mini-analyze's .NET road, its $$(wc -l < $(B)/analyze-native.txt) lines the native's"; fi
expected-langs: card
	$(SESSION_PY) $(IXQUIET) --prompt "% " --also "> " --also "  " --timeout 300 --out $(B)/qemu-card-scheme.txt --lines tests/session-card-scheme.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(SESSION_PY) $(IXQUIET) --prompt "% " --also "? " --timeout 300 --out $(B)/qemu-card-pascal.txt --lines tests/session-card-pascal.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card-scheme.txt) > tests/session-card-scheme
	$(call unwarned,$(B)/qemu-card-pascal.txt) > tests/session-card-pascal
	$(SESSION_PY) $(IXQUIET) --prompt "% " --also "?- " --also " ? " --timeout 300 --out $(B)/qemu-card-prolog.txt --lines tests/session-card-prolog.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card-prolog.txt) > tests/session-card-prolog
	$(SESSION_PY) $(IXQUIET) --prompt "% " --timeout 300 --out $(B)/qemu-card-dotnet.txt --lines tests/session-card-dotnet.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card-dotnet.txt) > tests/session-card-dotnet

FORCE:

clean:
	rm -rf $(BUILD) kernel-pi2*.img kernel-pi1.img kernel-pi1-b.img kernel-pi1-ix.img kernel-pi1-ixu.img kernel-pi1-ixa.img kernel-pi1-web.img kernel-pi1-card.img kernel-pi1-light*.img kernel-pi4.elf kernel-pi4-b.elf kernel-pi4-ix.elf kernel-pi4-card.elf kernel-pi4-ocaml4*.elf

.PHONY: all run qemu check ix ix-usb run-ix check-ix ix-audio check-audio check-audio-game check-audio-play check-draw expected-draw check-menu check-rio check-colors card check-card check-scheme check-pascal check-prolog check-dotnet check-analyze expected-langs clean FORCE
