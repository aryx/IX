# kernels/firmware: the Raspberry Pi's boot files

Not ix's, and not source: the binary files a Raspberry Pi's GPU reads
from the first partition of its SD card (a FAT) before any kernel
runs. They load the kernel `config.txt` names, at the address it says,
and start the ARM. ix puts them on the card it makes (`kernels/9pi`'s
`make card`, by mini-mkcard, with `kernels/9pi/conf/config.txt`:
[`docs/plans/done/plan_rio.md`](../../docs/plans/done/plan_rio.md), stage 3). QEMU
and mini-qemu do not need them: they load a kernel themselves
(`-kernel`).

**License**: Broadcom's, [`LICENCE.BROADCOM`](LICENCE.BROADCOM): binary
redistribution is allowed, for use with a Raspberry Pi only. It covers
`bootcode.bin`, `fixup*.dat` and `start*.elf`.

## pi1-pi2/: the Raspberry Pi 1 (and Zero) and the Pi 2 (and 3)

What `make card` puts on the card (`kernels/9pi/Makefile`'s
`FIRMWARE`). The same three files start a Pi 1 and a Pi 2: the
firmware then loads the kernel of the board it finds
([`docs/plans/plan_pi2.md`](../../docs/plans/plan_pi2.md): one card for
both).

| file | bytes | sha256 | what |
|---|---:|---|---|
| `bootcode.bin` | 52,624 | `4245ec23b58158dc...` | the second stage: the ROM loads it, it loads `start_cd.elf` |
| `start_cd.elf` | 844,380 | `ba2e8d34524bcac1...` | the GPU's firmware, the cut-down one (`gpu_mem=16`; no 3D): reads `config.txt`, loads the kernel |
| `fixup_cd.dat` | 3,280 | `64e1d7100658b031...` | its companion: the memory split |

**Origin**: github.com/raspberrypi/firmware, `boot/`, at the tag
`1.20260915` (the commit `6f0881cba8be`), downloaded 2026-10-12 as
they are; `start_cd.elf` says it was built on Sep 14 2026. Their
licence is that repository's of that tag,
[`pi1-pi2/LICENCE.broadcom`](pi1-pi2/LICENCE.broadcom) (the one above
less its copyright line and its clause on derivative devices). Why
newer files: a Pi 2B V1.2 (BCM2837), the author's, wants a firmware of
October 2016 or later. The whole sums: `sha256sum pi1-pi2/*`.

**On a board** (2026-10-12): the author's Pi 1 boots mini-9pi with
them to the prompt, the keyboard working, after the kernel's USB
start was changed for them (`kernels/lib_machine/usb.c`,
[`docs/plans/bugs/ix.md`](../../docs/plans/bugs/ix.md): this firmware
leaves the USB controller to be powered and set up, where the files
of 2015 left it ready). The old set is kept, below (the author:
"we can keep the old one, you never know"): `make card
FIRMWARE=../firmware/pi1`.

## pi1/: the Pi 1's files of 2015, the set before

| file | bytes | sha256 | what |
|---|---:|---|---|
| `bootcode.bin` | 17,864 | `18e58724814b0b8a...` | the second stage: the ROM loads it, it loads `start_cd.elf` |
| `start_cd.elf` | 586,616 | `97a66d7f707b7c92...` | the GPU's firmware, the cut-down one (`gpu_mem=16`): reads `config.txt`, loads the kernel |
| `fixup_cd.dat` | 2,365 | `ee58e3ab010e2f31...` | its companion: the memory split |

**Origin**: copied as they are, 2026-10-05, from principia
(`~/principia/MISC/pi/`, there since 2018), which took them from the
FAT partition of Richard Miller's Plan 9 image for the Raspberry Pi
(9pi); they are the Raspberry Pi Foundation's
(github.com/raspberrypi/firmware, `boot/`). `start_cd.elf` says it was
built on Mar 27 2015. They are the files principia's 9pi boots a real
Pi 1 with. The whole sums: `sha256sum pi1/*`.

## The Raspberry Pi 4: to come

Its loader is in the board's EEPROM, so no `bootcode.bin`; it wants
`start4.elf` (or `start4cd.elf`), `fixup4.dat` (`fixup4cd.dat`) and
`bcm2711-rpi-4-b.dtb`, from the same repository. To add here, with
their version and sums, when the card is made for the Pi 4.
