# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-xv6 (plan_kernel.md): one kernel, two boards (BOARD=pi1, the
# default, or pi4). Its OCaml modules (ML below) over kernels/lib_machine's
# (the machine: lib_machine/kernel.mk builds the image, from the board's
# lib_machine/pi1/ or lib_machine/pi4/, the processes' kernel side, the C library, the
# DWC2's primitives, the OCaml Machine, Screen, Page, Arch, Mmu), and
# fs.img, the xv6 port's own (its user programs, as built in $(XV6)),
# embedded. The Pi1's a raw image loaded at 0x8000 (kernel-pi1.img),
# the Pi4's an ELF (kernel-pi4.elf).
#
# ocaml-light for the board: ../ocaml-light.sh arm, arm64 builds it in
# $(OCL) (from ~/ocaml-light, untouched).
#
#   make [BOARD=pi4]      the image
#   make BOARD=pi4 COMPILER=ocaml
#                         the Pi4's image by the switch's OCaml 4.14
#                         (kernel-pi4-ocaml4.elf; ../ocaml.sh first: its
#                         runtime's sources); run, qemu, check the same
#   make run              under mini-qemu (Ctrl-A x quits)
#   make qemu             under QEMU
#   make check            a shell session under mini-qemu and QEMU, the
#                         same as the xv6 port's C kernel's
#                         (expected-$(BOARD)); usertests under QEMU
#   make usertests-mini   usertests under mini-qemu (slow)
#   make expected         the session on the C kernel

# no built-in rules (kernel.mk's comment: ~/xv6's fs.img once deleted)
MAKEFLAGS += --no-builtin-rules

XV6 ?= $(HOME)/xv6
# (Usbhost is kernels/lib_machine's: not every kernel wants it)
ML = Types Proc Fs File ../lib_machine/Usbhost Exec Syscall Main

# the xv6 port's file system: its user programs, usertests among them;
# its C kernel, the reference
ifeq ($(BOARD),pi4)
FS = $(XV6)/forks/arm64-pi4/fs.img
C_KERNEL = -cpu cortex-a72 -M raspi4b -kernel $(XV6)/forks/arm64-pi4/kernel/kernel -m 2G -smp 4 -nographic
else
FS = $(XV6)/forks/arm-pi1/user/fs.img
C_KERNEL = -M raspi1ap -nographic -kernel $(XV6)/forks/arm-pi1/kernel-qemu.img
endif

include ../lib_machine/kernel.mk

# the xv6 port's image: a source, never a target
$(FS): ;

run: $(IMAGE)
	$(MINIQEMU) $(BOOT)

qemu: $(IMAGE)
	$(QEMU) $(QEMU_BOOT)

# the session: what sh is typed (session.py waits for each prompt), no
# '>' (xv6 arm-pi1's C kernel panics on O_TRUNC: plan_kernel.md), no
# concurrent output (stressfs's interleaves with the timer); compared
# from init's first line on
SESSION = ls "cat README" "echo hello world" "mkdir d" "ls d" "ln README d/r" "ls d" "wc d/r" "rm d/r" \
  "grep xv6 README" forktest "cat nosuch" "sh -c"
# (xv6 arm64-pi4's other cores say "hart N starting" whenever they
# start: not the session's)
from_init = sed -n '/init: starting sh/,$$p' $(1) | grep -v '^hart [0-9] starting$$'

# the Pi1's screen too: xv6 arm-pi1's C kernel draws its console there
# (arm64-pi4's does not)
expected: | $(B)
	$(SESSION_PY) --timeout 300 --out $(B)/c.txt $(if $(filter pi1,$(BOARD)),--screendump $(B)/c.ppm) $(SESSION) -- $(QEMU) $(C_KERNEL)
	$(call from_init,$(B)/c.txt) > expected-$(BOARD)
	$(if $(filter pi1,$(BOARD)),gzip -n -9 < $(B)/c.ppm > expected-$(BOARD).ppm.gz)

# the USB keyboard and mouse (kernels/lib_machine's Usbhost): a session typed on the
# keyboard, the mouse moved; its text what the same lines typed on the
# serial line print (expected-$(BOARD)'s ls, then its echo)
USB = -device usb-kbd -device usb-mouse
USB_SESSION = ls "echo hello world"
$(B)/usb-expected.txt: expected-$(BOARD) | $(B)
	sed -n '1,/^\$$ cat README$$/p' $< | sed '$$d' > $@
	sed -n '/^\$$ echo hello world$$/,/^hello world$$/p' $< >> $@
	echo '$$ ' >> $@

# the session, and the screen after it: the console on the framebuffer
# (Screen.ml), the same under mini-qemu and QEMU, and on the Pi1 the
# same as xv6 arm-pi1's C kernel's (expected-pi1.ppm.gz)
# (the sessions: each an emulator and a kernel waited on, a core each:
# side by side, check's $(MAKE) -j, then check compares what they wrote)
run-mini:
	$(SESSION_PY) --timeout 300 --out $(B)/mini.txt --screendump $(B)/mini.ppm $(SESSION) -- $(MINIQEMU) $(BOOT)
run-qemu:
	$(SESSION_PY) --timeout 60 --out $(B)/qemu.txt --screendump $(B)/qemu.ppm $(SESSION) -- $(QEMU) $(QEMU_BOOT)
run-mini-usb:
	$(SESSION_PY) --timeout 300 --usb --move "200,-100;-60,40" --out $(B)/mini-usb.txt --screendump $(B)/mini-usb.ppm \
	  $(USB_SESSION) -- $(MINIQEMU) $(BOOT) $(USB)
run-qemu-usb:
	$(SESSION_PY) --timeout 120 --usb --move "200,-100;-60,40" --out $(B)/qemu-usb.txt --screendump $(B)/qemu-usb.ppm \
	  $(USB_SESSION) -- $(QEMU) $(QEMU_BOOT) $(USB)
run-usertests:
	$(SESSION_PY) --until "ALL TESTS PASSED" --timeout 300 --out $(B)/usertests.txt usertests -- $(QEMU) $(QEMU_BOOT)
SESSIONS = run-mini run-qemu run-mini-usb run-qemu-usb run-usertests
sessions: $(SESSIONS)
.PHONY: sessions $(SESSIONS)

check: $(IMAGE) $(B)/usb-expected.txt
	$(MAKE) --no-print-directory -j$(words $(SESSIONS)) sessions
	$(call from_init,$(B)/mini.txt) | diff - expected-$(BOARD) && echo "ok xv6 $(BOARD): a session under mini-qemu, as xv6's"
	$(call from_init,$(B)/qemu.txt) | diff - expected-$(BOARD) && echo "ok xv6 $(BOARD): a session under QEMU, as xv6's"
	cmp $(B)/mini.ppm $(B)/qemu.ppm && echo "ok xv6 $(BOARD): the screen under mini-qemu, as under QEMU"
	$(if $(wildcard expected-$(BOARD).ppm.gz),gzip -dc expected-$(BOARD).ppm.gz | cmp - $(B)/qemu.ppm && echo "ok xv6 $(BOARD): the screen as xv6's C kernel draws it")
	$(call from_init,$(B)/mini-usb.txt) | diff - $(B)/usb-expected.txt && $(call from_init,$(B)/qemu-usb.txt) | diff - $(B)/usb-expected.txt \
	  && echo "ok xv6 $(BOARD): a session typed on the USB keyboard, under mini-qemu and QEMU"
	cmp $(B)/mini-usb.ppm $(B)/qemu-usb.ppm && echo "ok xv6 $(BOARD): the screen after the USB mouse moved, under mini-qemu as under QEMU"
	echo "ok xv6 $(BOARD): usertests under QEMU"

# IX'S EXTENSION TO XV6'S FORMAT, checked (Fs.ml: files larger than
# xv6's 314 KB): an image made by mini-mkfs (../9pi/filesystems/
# lib_xv6fs's code, which has the same extension) with xv6's programs
# (taken out of xv6's own image) and a text of 1.3 MB; this kernel with
# it as its disk; "wc big" there says what wc says here. Then the file
# is made again by this kernel itself (cat big > copy: its own blocks
# of numbers), and counted.
LARGE = $(B)/large
XV6TEST = ../../_build/default/kernels/9pi/filesystems/lib_xv6fs/tests/Xv6test.exe
MKFS = ../../_build/default/kernels/tools/Mkfs.exe
check-large:
	rm -rf $(LARGE); mkdir -p $(LARGE)
	cp $(FS) $(LARGE)/xv6.img
	for f in init sh wc cat ls; do $(XV6TEST) $(LARGE)/xv6.img cat /$$f > $(LARGE)/$$f || exit 1; done
	seq 1 200000 > $(LARGE)/big
	$(MKFS) -m 6 $(LARGE)/fs.img $(foreach f,init sh wc cat ls big,$(f)=$(LARGE)/$(f))
	$(MAKE) --no-print-directory FS=$(abspath $(LARGE)/fs.img) B=$(LARGE)/build IMAGE=$(LARGE)/kernel$(suffix $(IMAGE))
	$(SESSION_PY) --timeout 600 --out $(LARGE)/mini.txt "wc big" "cat big > copy" "wc copy" -- $(MINIQEMU) $(subst $(IMAGE),$(LARGE)/kernel$(suffix $(IMAGE)),$(BOOT))
	grep -q "^$$(wc -l < $(LARGE)/big) $$(wc -w < $(LARGE)/big) $$(wc -c < $(LARGE)/big) big" $(LARGE)/mini.txt \
	  && echo "ok xv6 $(BOARD): a file of $$(wc -c < $(LARGE)/big) bytes made by mini-mkfs, read whole (ix's extension: xv6's limit is 314 KB)"
	grep -q "^$$(wc -l < $(LARGE)/big) $$(wc -w < $(LARGE)/big) $$(wc -c < $(LARGE)/big) copy" $(LARGE)/mini.txt \
	  && echo "ok xv6 $(BOARD): the same written by this kernel, and read back"

usertests-mini: $(IMAGE)
	$(SESSION_PY) --until "ALL TESTS PASSED" --timeout 7200 --out $(B)/usertests-mini.txt usertests -- \
	  $(MINIQEMU) $(BOOT) && echo "ok xv6 $(BOARD): usertests under mini-qemu"

clean:
	rm -rf build kernel-pi1.img kernel-pi4.elf kernel-pi4-ocaml4.elf

.PHONY: all run qemu check usertests-mini expected clean
