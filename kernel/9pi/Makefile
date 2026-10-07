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
ML = syscalls/$(ARCH)/Ureg core/Errors core/Types files/Dev processes/Proc files/Kchan processes/Kproc devices/sys/Devroot console/Devcons \
  devices/sys/Devenv devices/sys/Devsys devices/sys/Devarch devices/sys/Devdup devices/sys/Devsrv devices/sys/Devpipe \
  devices/sys/Devproc devices/storage/arm/Emmc devices/storage/Devsd filesystems/lib_fat/Fat filesystems/Kdos filesystems/lib_xv6fs/Xv6fs filesystems/Kfs files/P9 files/P9_wire devices/sys/Devmnt \
  buses/Usb buses/arm/Usbdwc buses/Devusb devices/keyboard/Latin1 devices/keyboard/Kbd $(PIXEL_ML) devices/screen/Swcursor \
  devices/screen/Swconsole devices/keyboard/Devkbin devices/mouse/Devmouse buses/lib_usb/Usbdesc buses/lib_usb/Hid buses/lib_usb/Usbbus buses/Kusb \
  devices/screen/Devdraw devices/Devstub network/Etherusb network/Devether network/ip/Ip network/ip/Icmp network/ip/Tcp network/ip/Devip memory/Fault processes/Exec \
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
# -DKERNDATE=`date -n`: conf/kerndate.py finds it in 9pi's image), so that
# their entries are 9pi's
KERNDATE ?= $(shell conf/kerndate.py $(PRINCIPIA))

# the pixels (lib_graphics/Kdraw.mli): PIXEL=ocaml (the default), stage
# F's OCaml (lib_graphics/ocaml's Kdraw, over lib_memdraw and
# lib_memlayer: principia's libmemdraw and libmemlayer, which know
# nothing of a kernel); PIXEL=c, principia's C pixel libraries
# (lib_graphics/c), as before stage F
PIXEL ?= ocaml
# each its own build (the OCaml's build/pi1-ocaml...), the image
# relinked when PIXEL changes (the same file: mini-pi's, the checks')
PIX = $(if $(filter ocaml,$(PIXEL)),-ocaml)
B ?= build/$(BOARD)$(PIX)
PIXEL_ML = $(if $(filter ocaml,$(PIXEL)),$(OCAML_PIXEL),lib_graphics/c/Kdraw)
OCAML_PIXEL = $(B)/gen/Memdata $(addprefix lib_graphics/lib_memdraw/,Memchan Memimage Memdraw Memfont) \
  $(addprefix lib_graphics/lib_memlayer/,Memlayer Memshape) lib_graphics/ocaml/Kdraw

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
# echo, ls, cat, bind and mount, mini-ed as ed, tests/hello and
# tests/threads (mini-ml's threads and channels), Source's check
# (lib_core/commons/tests), mini-dossrv, mini-fdisk and hellodraw
# and hellomenu (lib_graphics/tests), mini-rio as rio and hellorio (windows), mini-colors as colors
# (applications/misc). No SD
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
IXDIRS = lib_core shell editor utilities/files utilities/misc utilities/namespace kernel/9pi/tests/hello kernel/9pi/tests/threads lib_core/commons/tests kernel/9pi/filesystems/user/dossrv \
  kernel/9pi/devices/storage/user/fdisk kernel/9pi/buses/user/usbd lib_graphics/tests windows windows/tests applications/misc
BOOTDIR_IX = boot=conf/boot.rc rc=$(IX9)/shell/mini-rc ed=$(IX9)/editor/mini-ed hello=$(IX9)/kernel/9pi/tests/hello/hello threads=$(IX9)/kernel/9pi/tests/threads/threads sources=$(IX9)/lib_core/commons/tests/sources \
  echo=$(IX9)/utilities/misc/mini-echo ls=$(IX9)/utilities/files/mini-ls cat=$(IX9)/utilities/files/mini-cat \
  bind=$(IX9)/utilities/namespace/mini-bind mount=$(IX9)/utilities/namespace/mini-mount \
  dossrv=$(IX9)/kernel/9pi/filesystems/user/dossrv/mini-dossrv fdisk=$(IX9)/kernel/9pi/devices/storage/user/fdisk/mini-fdisk \
  hellodraw=$(IX9)/lib_graphics/tests/hellodraw hellomenu=$(IX9)/lib_graphics/tests/hellomenu \
  words=tests/words.txt
KERNDATE_IX = 1790380800
IMAGE_IX = $(basename $(IMAGE))-ix$(suffix $(IMAGE))
BOOT_IX = $(subst $(IMAGE),$(IMAGE_IX),$(BOOT))
QEMU_BOOT_IX = $(subst $(IMAGE),$(IMAGE_IX),$(QEMU_BOOT))
ix: | $(B)
	for d in $(IXDIRS); do (cd $(IX)/$$d && PATH=$(IX)/bin:$$PATH mini-mk O=5 OS=plan9 > /dev/null) || exit 1; done
	$(MAKE) B=build/$(BOARD)$(PIX)-ix IMAGE=$(IMAGE_IX) BOOTDIR="$(BOOTDIR_IX)" KERNDATE=$(KERNDATE_IX) $(IMAGE_IX)
# with a USB keyboard and mouse: the same image and mini-usbd in its
# bootdir (the driver is a program in Plan 9: buses/user/usbd, ix's
# own), for the checks that move a mouse (check-menu)
IMAGE_IXU = $(basename $(IMAGE))-ixu$(suffix $(IMAGE))
BOOT_IXU = $(subst $(IMAGE),$(IMAGE_IXU),$(BOOT))
QEMU_BOOT_IXU = $(subst $(IMAGE),$(IMAGE_IXU),$(QEMU_BOOT))
ix-usb: ix
	$(MAKE) B=build/$(BOARD)$(PIX)-ixu IMAGE=$(IMAGE_IXU) BOOTDIR="$(BOOTDIR_IX) usbd=$(IX9)/kernel/9pi/buses/user/usbd/mini-usbd" KERNDATE=$(KERNDATE_IX) $(IMAGE_IXU)
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
check-ix: ix
	$(SESSION_PY) --prompt "% " --timeout 120 --out $(B)/mini-ix.txt --lines tests/session-ix.cmds -- $(MINIQEMU) $(BOOT_IX)
	$(call unwarned,$(B)/mini-ix.txt) | diff - tests/session-ix && echo "ok 9pi: ix's own programs (mini-rc, mini-ed, hello) under mini-qemu"
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-ix.txt --lines tests/session-ix.cmds -- $(QEMU) $(QEMU_BOOT_IX)
	$(call unwarned,$(B)/qemu-ix.txt) | diff - tests/session-ix && echo "ok 9pi: ix's own programs under QEMU"
	$(SESSION_PY) --prompt "% " --timeout 180 --out $(B)/mini-ix-b.txt --lines tests/session-ix-b.cmds -- $(MINIQEMU) $(BOOT_IX)
	$(call unwarned,$(B)/mini-ix-b.txt) | diff - tests/session-ix-b && echo "ok 9pi: stage B's session with ix's own programs, under mini-qemu"
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-ix-b.txt --lines tests/session-ix-b.cmds -- $(QEMU) $(QEMU_BOOT_IX)
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
#   win-scroll   24 lines written, the arrows (scrolling back), the three
#             buttons in the scroll bar, a command (the end again)
#   win-select  a word of the text swept with the left button (marked), the
#             middle button's menu: snarf, then send (the word typed to rc);
#             /dev/snarf read (cat), and written: sent again
#   win-utf8    a text that is not ASCII's (tests/words.txt, in /boot): shown (a
#             mark for the characters the font has not), a word of it
#             selected, pasted, two characters taken back
#   colors-bare  mini-colors (../../applications/misc) on the bare screen:
#             a square pointed at, its menu's exit
#   colors-win   the same program in a window of mini-rio's, which is moved
#             and made another size: it draws again
#
#   make check-windows   all of them, side by side (14 emulators, a core
#                        each): what one waits for is the longest
#   make check-draw, check-menu, check-rio, check-colors   a part of them
#   make expected-windows   their screens recorded again (mini-qemu's),
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
GSESSIONS = menu win-new win-ops win-scroll win-select win-utf8 colors-bare colors-win

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
# (recorded: the screens of a session without --expect, each one still for three steps)
expected-%: ix-usb card
	rm -rf $(B)/g-$*-mini
	$(GRAPHICS) --steps tests/$*.steps $(B)/g-$*-mini -- $(MINI_USB)
	cd $(B)/g-$*-mini && md5sum boot.ppm $$(ls step*.ppm | sort -V) > $(CURDIR)/tests/$*.md5
expected-draw: ix
	$(call DRAW,mini) $(MINIQEMU) $(BOOT_IX)
	gzip -n -9 < $(B)/mini-draw.ppm > tests/hellodraw.ppm.gz
expected-windows: ix-usb card
	$(MAKE) --no-print-directory -j8 $(GSESSIONS:%=expected-%)

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
#   check-windows         the graphical sessions, with mini-usbd
#   check-windows-kernel  the same with the kernel's own USB (Kusb)
#   check-plug            devices unplugged and plugged (QEMU)
#   mini-mk check         the kernel built by ix's tools (the Pi4's)
check-all:
	$(MAKE) --no-print-directory PIXEL=c
	$(MAKE) --no-print-directory
	$(MAKE) --no-print-directory check
	$(MAKE) --no-print-directory check-ix
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
check-rio: ix-usb card ; $(call gcheck,win-new win-ops win-scroll win-select win-utf8)
check-colors: ix-usb card ; $(call gcheck,colors-bare colors-win)
check-windows: ix-usb card ; $(call gcheck,draw $(GSESSIONS))
# the same sessions, the same screens, with no usbd: the kernel's own USB (Kusb)
check-windows-kernel: ix card ; $(MAKE) --no-print-directory KUSB=1 GJOBS=$(GJOBS) gcheck-all
gcheck-all: ; $(call gcheck,$(GSESSIONS))
.PHONY: check-windows expected-windows cmp-draw run-draw-mini run-draw-qemu

# The SD card (plan_rio.md, stage 3): make card, build/card.img, by
# mini-mkcard (../tools): an MBR, a FAT16 with the Pi 1's firmware
# (../firmware), conf/config.txt and the image of make ix, and a second
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
cardsize = sed -E -e 's/ +/ /g' -e 's/ [0-9]+ (Sep 26 2026 [a-z\/]*\/(MINI9PI1\.IMG|mini9pi1\.img))/ SIZE \1/'
MKCARD = ../../_build/default/kernel/tools/Mkcard.exe
FIRMWARE = ../firmware/pi1
CARD_SD = -drive file=$(CARD),if=sd,format=raw,snapshot=on
card: ix
	$(MAKE) $(CARD)
# the second partition: xv6's file system (mini-mkfs, lib_xv6fs's: the
# kernel's Kfs reads and writes it), the system's root (boot.rc: /root,
# and after the kernel's own directories at /), laid out as Plan 9's:
#   bin/arm    the programs that are not in the kernel's image (the
#              window system and what runs in it: mini-rio, hellorio,
#              mini-colors; hello; utilities/'s pwd, mkdir, rm, cp,
#              mv, touch and chmod), bound after /bin
#   usr/pad    a user's directory, where the shell starts
#   mnt/fat    where the card's first partition, the firmware's FAT, is
#              mounted
#   tmp
CARD_BIN = rio=$(IX9)/windows/mini-rio hellorio=$(IX9)/windows/tests/hellorio colors=$(IX9)/applications/misc/mini-colors \
  hello=$(IX9)/kernel/9pi/tests/hello/hello \
  pwd=$(IX9)/utilities/files/mini-pwd mkdir=$(IX9)/utilities/files/mini-mkdir rm=$(IX9)/utilities/files/mini-rm cp=$(IX9)/utilities/files/mini-cp \
  mv=$(IX9)/utilities/files/mini-mv touch=$(IX9)/utilities/files/mini-touch chmod=$(IX9)/utilities/files/mini-chmod
MKFS = ../../_build/default/kernel/tools/Mkfs.exe
CARD_FS = build/card-fs.img
$(CARD_FS): Makefile $(MKFS) tests/card-motd.txt $(foreach p,$(CARD_BIN),$(lastword $(subst =, ,$(p))))
	$(MKFS) -m 31 $@ $(addprefix bin/arm/,$(CARD_BIN)) usr/pad/readme=tests/card-motd.txt mnt/fat/ tmp/
$(CARD): $(MKCARD) $(CARD_FS) conf/config.txt kernel-pi1-ix.img $(wildcard $(FIRMWARE)/*)
	$(MKCARD) -date $(KERNDATE_IX) -fs $(CARD_FS) $@ bootcode.bin=$(FIRMWARE)/bootcode.bin start_cd.elf=$(FIRMWARE)/start_cd.elf \
	  fixup_cd.dat=$(FIRMWARE)/fixup_cd.dat config.txt=conf/config.txt mini9pi1.img=kernel-pi1-ix.img
IMAGE_CARD = $(basename $(IMAGE))-card$(suffix $(IMAGE))
ifneq ($(findstring -card.,$(IMAGE)),-card.)
$(IMAGE_CARD): FORCE
	$(MAKE) B=build/$(BOARD)$(PIX)-card IMAGE=$@ BOOTRC=tests/boot-card.rc BOOTMORE=cat $@
endif
BOOT_CARD = $(subst $(IMAGE),$(IMAGE_CARD),$(BOOT))
QEMU_BOOT_CARD = $(subst $(IMAGE),$(IMAGE_CARD),$(QEMU_BOOT))
check-card: card $(IMAGE_CARD)
	/usr/sbin/sfdisk -l $(CARD) | grep -c 'FAT16\|Non-FS data' | grep -qx 2 && echo "ok card: its two partitions"
	dd if=$(CARD) of=$(B)/card-fat.img bs=512 skip=2048 count=65536 2> /dev/null
	/usr/sbin/fsck.vfat -n $(B)/card-fat.img > $(B)/card-fsck.txt 2>&1 && echo "ok card: its FAT, by fsck.vfat ($$(tail -1 $(B)/card-fsck.txt | sed 's/.*: //'))"
	mcopy -n -i $(B)/card-fat.img ::MINI9PI1.IMG $(B)/card-kernel.img && cmp $(B)/card-kernel.img kernel-pi1-ix.img && echo "ok card: the kernel read back by mcopy"
	$(SESSION_PY) --prompt "% " --timeout 180 --out $(B)/mini-card.txt --lines tests/session-card.cmds -- $(MINIQEMU) $(BOOT_CARD) $(CARD_SD)
	$(call unwarned,$(B)/mini-card.txt) | $(cardsize) > $(B)/mini-card.txt.masked; $(cardsize) tests/session-card | diff $(B)/mini-card.txt.masked - && echo "ok card: read and written by principia's fdisk and dossrv, on mini-9pi under mini-qemu"
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-card.txt --lines tests/session-card.cmds -- $(QEMU) $(QEMU_BOOT_CARD) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card.txt) | $(cardsize) > $(B)/qemu-card.txt.masked; $(cardsize) tests/session-card | diff $(B)/qemu-card.txt.masked - && echo "ok card: the same under QEMU"
	$(SESSION_PY) --prompt "% " --timeout 360 --out $(B)/mini-card-ix.txt --lines tests/session-card-ix.cmds -- $(MINIQEMU) $(BOOT_IX) $(CARD_SD)
	$(call unwarned,$(B)/mini-card-ix.txt) | $(cardsize) > $(B)/mini-card-ix.txt.masked; $(cardsize) tests/session-card-ix | diff $(B)/mini-card-ix.txt.masked - && echo "ok card: read by mini-dossrv, on mini-9pi with ix's own programs, under mini-qemu"
	$(SESSION_PY) --prompt "% " --timeout 120 --out $(B)/qemu-card-ix.txt --lines tests/session-card-ix.cmds -- $(QEMU) $(QEMU_BOOT_IX) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card-ix.txt) | $(cardsize) > $(B)/qemu-card-ix.txt.masked; $(cardsize) tests/session-card-ix | diff $(B)/qemu-card-ix.txt.masked - && echo "ok card: the same under QEMU"
	$(MAKE) --no-print-directory ix-kernel > /dev/null
	$(SESSION_PY) --prompt "% " --timeout 180 --out $(B)/mini-card-ixk.txt --lines tests/session-card-ixk.cmds -- $(MINIQEMU) $(BOOT_IXK) $(CARD_SD)
	$(call unwarned,$(B)/mini-card-ixk.txt) | diff - tests/session-card-ixk && echo "ok card: /root by the kernel's own FAT (no dossrv in the image: boot.rc's bind '#Fdos'), read and written, under mini-qemu"
	$(SESSION_PY) --prompt "% " --timeout 60 --out $(B)/qemu-card-ixk.txt --lines tests/session-card-ixk.cmds -- $(QEMU) $(QEMU_BOOT_IXK) $(CARD_SD)
	$(call unwarned,$(B)/qemu-card-ixk.txt) | diff - tests/session-card-ixk && echo "ok card: the same under QEMU"

FORCE:

clean:
	rm -rf build kernel-pi1.img kernel-pi1-b.img kernel-pi1-ix.img kernel-pi1-ixu.img kernel-pi1-card.img kernel-pi4.elf kernel-pi4-b.elf kernel-pi4-ix.elf kernel-pi4-card.elf

.PHONY: all run qemu check ix ix-usb run-ix check-ix check-draw expected-draw check-menu check-rio check-colors card check-card clean FORCE
