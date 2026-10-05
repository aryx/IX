# kernel/firmware: the Raspberry Pi's boot files

Not ix's, and not source: the binary files a Raspberry Pi's GPU reads
from the first partition of its SD card (a FAT) before any kernel
runs. They load the kernel `config.txt` names, at the address it says,
and start the ARM. ix puts them on the card it makes
([`docs/plans/plan_rio.md`](../../docs/plans/plan_rio.md), stage 3). QEMU
and mini-qemu do not need them: they load a kernel themselves
(`-kernel`).

**License**: Broadcom's, [`LICENCE.BROADCOM`](LICENCE.BROADCOM): binary
redistribution is allowed, for use with a Raspberry Pi only. It covers
`bootcode.bin`, `fixup*.dat` and `start*.elf`.

## pi1/: the Raspberry Pi 1 (and Zero)

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
