# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The kernels' shared build (plan_9pi.md, decision 1): included by
# kernel/xv6's and kernel/9pi's Makefiles, which set first
#   ML      their OCaml modules, in order (after kernel/lib's: LIB_ML),
#           each maybe in a directory (kernel/9pi's: files/Chan); one in
#           an arch's directory (devices/storage/arm/Emmc) has its
#           interface in the directory above (devices/storage/Emmc.mli:
#           the portable code's contract, as lib/Arch.mli is)
#   FS      the disk image embedded in the kernel (start.s's fs_image)
#   EXTRA_OBJS  more objects to link (kernel/9pi's: principia's C pixel
#           libraries), built by the kernel's own rules
# and then add their own targets (run, check, ...). A board (BOARD=pi1,
# the default, or pi4) is lib/pi1/ or lib/pi4/: its Arch.ml, machine.c,
# start.s, board.h, kernel.ld; lib/ has the rest of the machine (the
# processes' kernel side, the C library, the DWC2's primitives) and the
# OCaml modules both kernels use (Machine, Screen, Page, Arch, Mmu).

# no built-in rules: a kernel's disk image is a source here, never a
# target (make's %: %.o rule once tried to rebuild ~/xv6's fs.img from
# its fs.img.o, and the failed link deleted it: plan_kernel.md)
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

BOARD ?= pi1
LIB = ../lib
BD = $(LIB)/$(BOARD)
# the build directory, the image: a kernel may build another (kernel/9pi's
# check: a test boot script in its bootdir) with its own B and IMAGE
B ?= build/$(BOARD)
MINIQEMU = ../../_build/default/raspberry/Main.exe

# the collector's parameters (ocaml-light's CAMLRUNPARAM, libc.c's
# getenv): a minor heap of 256k words, 8 times the default, most of a
# boot's data dying there. mini-9pi's boot to rc's prompt, the Pi1 13.5
# s to 9.4 (100 minor collections to 12, 43 major cycles to 6), the
# Pi4 9.7 to 8.1 (tests/perf/gc_boot.sh, plan_9pi_gc.md); 1 MB (2 on
# the Pi4) of the kernel's memory. make CAMLRUNPARAM= for ocaml-light's
# defaults, or others (s, i, h in words, o in %, v=1 its trace)
CAMLRUNPARAM ?= s=256k
SESSION_PY = $(LIB)/session.py

ifeq ($(BOARD),pi1)
# the Pi1: ARMv6 and its VFP, cross-compiled
OCL ?= /tmp/ix-ocaml-light-arm
CROSS = arm-linux-gnueabihf-
CPU = -march=armv6kz -mfpu=vfp -mfloat-abi=hard -marm
ASFLAGS = -march=armv6kz -mfpu=vfp -mfloat-abi=hard
TARGET = arm
IMAGE ?= kernel-pi1.img
BOOT = -M raspi1ap -device loader,file=$(IMAGE),addr=0x8000,cpu-num=0,force-raw=on -nographic
QEMU = qemu-system-arm
QEMU_BOOT = $(BOOT)
else
# the Pi4: ARMv8, this machine's own (aarch64): no cross compiler;
# no vectorizing (mini-qemu's arm64 has the scalar floating point, not
# Advanced SIMD)
OCL ?= /tmp/ix-ocaml-light-arm64
CROSS =
CPU = -mstrict-align -fno-tree-vectorize
ASFLAGS =
TARGET = arm64
IMAGE ?= kernel-pi4.elf
BOOT = -cpu cortex-a72 -M raspi4b -kernel $(IMAGE) -m 2G -nographic
# QEMU's raspi4b wants its four cores (mini-pi's QEMU64)
QEMU ?= $(or $(wildcard /media/pad/extradrive1/pad/work/TOOLCHAINS/qemu/build/qemu-system-aarch64),qemu-system-aarch64)
QEMU_BOOT = $(BOOT) -smp 4
endif

OCAMLOPT = $(OCL)/bin/ocamlopt
SRC = $(OCL)/src
# freestanding: no PIE (no GOT), no stack protector, no _FORTIFY_SOURCE's
# __sprintf_chk, no 64-bit file offsets' open64 beyond what libc.c stubs
CFLAGS = $(CPU) -O2 -ffreestanding -fno-builtin -fno-pie -fno-stack-protector -U_FORTIFY_SOURCE -w \
  -I$(BD) -I$(SRC)/byterun -I$(SRC)/config -I$(SRC)/asmrun -DNATIVE_CODE -DTARGET_$(TARGET) -DSYS_linux_elf
LIB_ML = Machine Screen Page Arch Mmu
ALL_ML = $(LIB_ML) $(notdir $(ML))
# a module's .mli: beside its .ml, or in the directory above
# (a module of types only has no .mli)
MLI = $(foreach m,$(ML),$(firstword $(wildcard $(m).mli $(dir $(m))../$(notdir $(m)).mli)))

# asmrun's Makefile's COBJS, less main.o (libc.c's kmain starts OCaml)
RUNTIME = startup fail roots signals misc freelist major_gc minor_gc memory alloc compare ints \
  floats str array io extern intern hash sys parsing gc_ctrl terminfo md5 obj lexing printexc \
  backtrace callback weak compact custom
RTOBJS = $(RUNTIME:%=$(B)/rt_%.o) $(B)/rt_$(TARGET).o
OBJS = $(B)/start.o $(B)/ocaml.o $(RTOBJS) $(B)/runtime.o $(B)/usb.o $(B)/machine.o $(B)/libc.o $(EXTRA_OBJS)

all: $(IMAGE)

$(B):
	mkdir -p $(B)/bin
	# ocaml-light's -output-obj calls "ld -r": the board's one here
	ln -sf $$(command -v $(CROSS)ld) $(B)/bin/ld

$(B)/rt_%.o: | $(B)
	src=$(SRC)/asmrun/$*.c; [ -f $$src ] || src=$(SRC)/byterun/$*.c; $(CROSS)gcc $(CFLAGS) -c $$src -o $@

$(B)/rt_$(TARGET).o: | $(B)
	$(CROSS)gcc $(CPU) -DSYS_linux_elf -c $(SRC)/asmrun/$(TARGET).S -o $@

$(B)/%.o: $(LIB)/%.c $(BD)/board.h | $(B)
	$(CROSS)gcc $(CFLAGS) -c $< -o $@

# libc.o with the collector's parameters, if CAMLRUNPARAM is given
# (libc.c's getenv); its stamp rewritten when they change, so that
# libc.o is rebuilt then
$(B)/libc.o: $(LIB)/libc.c $(BD)/board.h $(B)/camlrunparam | $(B)
	$(CROSS)gcc $(CFLAGS) $(if $(CAMLRUNPARAM),-DCAMLRUNPARAM='"$(CAMLRUNPARAM)"') -c $< -o $@

$(B)/camlrunparam: FORCE | $(B)
	@echo '$(CAMLRUNPARAM)' | cmp -s - $@ || echo '$(CAMLRUNPARAM)' > $@

FORCE:

$(B)/machine.o: $(BD)/machine.c $(BD)/board.h | $(B)
	$(CROSS)gcc $(CFLAGS) -c $< -o $@

$(B)/start.o: $(BD)/start.s $(B)/fs.img $(B)/font.bin | $(B)
	$(CROSS)as $(ASFLAGS) -I $(B) $< -o $@

# the OCaml: kernel/lib's modules (the board's Arch), then the kernel's
LIB_SRC = $(foreach m,$(filter-out Arch,$(LIB_ML)),$(LIB)/$(m).ml $(LIB)/$(m).mli) $(LIB)/Arch.mli $(BD)/Arch.ml
$(B)/ocaml.o: $(LIB_SRC) $(ML:%=%.ml) $(MLI) | $(B)
	cp $(LIB_SRC) $(ML:%=%.ml) $(MLI) $(B)/
	cd $(B) && for m in $(ALL_ML); do { [ ! -f $$m.mli ] || $(OCAMLOPT) -c $$m.mli; } && $(OCAMLOPT) -c $$m.ml || exit 1; done
	cd $(B) && PATH=$$PWD/bin:$$PATH $(OCAMLOPT) -output-obj -o ocaml.o $(ALL_ML:%=%.cmx)

# the kernel's disk image (a kernel's FS a source, or its own target)
$(B)/fs.img: $(FS) | $(B)
	cp $< $@

# the console's font (xv6_rpi_port's font1.bin: 128 characters of 8 x 16)
$(B)/font.bin: $(LIB)/font1.bin | $(B)
	cp $< $@

$(B)/kernel.elf: $(OBJS) $(BD)/kernel.ld
	$(CROSS)ld -T $(BD)/kernel.ld -o $@ $(OBJS)

ifeq ($(BOARD),pi1)
$(IMAGE): $(B)/kernel.elf
	$(CROSS)objcopy -O binary $< $@
else
$(IMAGE): $(B)/kernel.elf
	cp $< $@
endif

