/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-xv6's USB host controller: the DWC2 (Synopsys DesignWare Hi-Speed
 * USB 2.0 OTG) of both boards (the Pi1's, the Pi4's second controller,
 * which QEMU's raspi4b models too), at the peripherals' 0x980000. What
 * OCaml cannot say: its registers use bits 31 and 30 (a channel's
 * enable, the SETUP PID), past the Pi1's OCaml ints. So the protocol is
 * Usbhost.ml's, and here only the controller's two operations: the host
 * started (the root port powered and reset), and one transfer, on
 * channel 0, polled to its end, through a DMA page OCaml fills and reads
 * (Phys, at usb_buffer's physical address).
 *
 * References: the DWC2's registers as QEMU's hw/usb/hcd-dwc2.h names
 * them (read 2026-09-25); CSUD, xv6 arm-pi1's USB driver, for the
 * order of the steps. */

#include <mlvalues.h>
#include "board.h"

void delay_us(unsigned us);

#define USB(off) (*(volatile unsigned *)(IO_BASE + 0x980000UL + (off)))

#define GAHBCFG 0x008
#define GUSBCFG 0x00c
#define GRSTCTL 0x010
#define GRXFSIZ 0x024
#define GNPTXFSIZ 0x028
#define HPTXFSIZ 0x100
#define HPRT 0x440
#define HCCHAR(ch) (0x500 + 0x20 * (ch))
#define HCINT(ch) (0x508 + 0x20 * (ch))
#define HCINTMSK(ch) (0x50c + 0x20 * (ch))
#define HCTSIZ(ch) (0x510 + 0x20 * (ch))
#define HCDMA(ch) (0x514 + 0x20 * (ch))

/* HPRT: the bits a write clears when 1 (connect detected, enabled,
 * enable changed, over-current changed), kept 0 when writing others */
#define HPRT_W1C 0x2e
#define HPRT_POWER (1 << 12)
#define HPRT_RESET (1 << 8)
#define HPRT_ENABLED (1 << 2)
#define HPRT_CONNECTED (1 << 0)

/* the DMA page: the transfers' data. A page's address is a multiple of
 * 4096: the first one inside two (no compiler's alignment asked) */
#define PAGE(b) ((unsigned char *)(((uintptr)(b) + 4095) & ~(uintptr)4095))
static unsigned char buffer_[2 * 4096];
#define buffer PAGE(buffer_)

/* (the second channel's page, below) */
static unsigned char buffer1_[2 * 4096];
#define buffer1 PAGE(buffer1_)

/* (the controller reads and writes the two pages itself: they are never
 * cached, board.h; said once, before the first use of either) */
static int uncached_said;
static void uncache(void)
{
  if (uncached_said) return;
  uncached_said = 1;
  uncached_add((uintptr)buffer - KERNBASE, 4096);
  uncached_add((uintptr)buffer1 - KERNBASE, 4096);
}

value usb_buffer(value unit) { (void)unit; uncache(); return Val_long((uintptr)buffer - KERNBASE); }

/* the host started: DMA on, the root port powered, then reset (50ms, as
 * USB wants) and enabled; whether a device is there */
/* GRSTCTL's bits set, waited on until the controller clears them (a
 * second at most: an emulator may never) */
static void greset(unsigned bits)
{
  unsigned i;
  USB(GRSTCTL) |= bits;
  for (i = 0; i < 1000000 && (USB(GRSTCTL) & bits); i++) ;
  delay_us(10);
}

/* The controller itself, before its port: what a board asks and an
 * emulator does not, which starts with the controller ready (found on
 * the author's Pi1, 2026-10-08: no keyboard, no mouse; the steps and
 * their numbers are usbdwc.c's init, principia's 9pi, which runs
 * there). Powered (the firmware asked); reset, once it is idle; told
 * to be a host (the same controller can be a device: OTG); DMA; its
 * three queues' sizes (FIFOs: received, to send, to send
 * periodically), then emptied. */
static void controller(void)
{
  unsigned i;
  USB(GAHBCFG) = 0;
  usb_power();
  for (i = 0; i < 1000000 && !(USB(GRSTCTL) & (1u << 31)); i++) ;      /* the bus idle */
  greset(1 << 0);                                          /* the core's soft reset */
  USB(GUSBCFG) |= 1 << 29;                                 /* host mode forced */
  delay_us(25000);
  USB(GAHBCFG) |= 1 << 5;                                  /* DMA */
  USB(GRXFSIZ) = 0x306;
  USB(GNPTXFSIZ) = 0x306 | (0x100 << 16);
  delay_us(1000);
  USB(HPTXFSIZ) = (0x306 + 0x100) | (0x200 << 16);
  greset(1 << 4);                                          /* the receive queue emptied */
  USB(GRSTCTL) = 0x10 << 6;                                /* every transmit queue */
  greset(1 << 5);                                          /* emptied */
}

/* (mini-9pi's start: its port is Usbdwc's) */
value usb_controller(value unit) { (void)unit; controller(); return Val_unit; }

value usb_init(value unit)
{
  unsigned p;
  (void)unit;
  controller();
  p = USB(HPRT) & ~HPRT_W1C;
  USB(HPRT) = p | HPRT_POWER;
  delay_us(20000);
  p = USB(HPRT) & ~HPRT_W1C;
  USB(HPRT) = p | HPRT_RESET;
  delay_us(50000);
  p = USB(HPRT) & ~HPRT_W1C;
  USB(HPRT) = p & ~HPRT_RESET;
  delay_us(20000);
  return Val_bool((USB(HPRT) & (HPRT_CONNECTED | HPRT_ENABLED)) == (HPRT_CONNECTED | HPRT_ENABLED));
}

/* Split transactions: a low or full speed device (a keyboard, a mouse)
 * behind a high speed hub, as every device of a Pi1 model B is: its two
 * ports are an onboard hub's (the LAN9512, which is the Ethernet too),
 * the controller's only port being that hub's. The controller talks
 * high speed to the hub only, and the hub talks slowly to the device:
 * a transfer is then two, both addressed to the hub's translator
 * (HCSPLT: the hub's address and the port) -- the start (here is what
 * to ask the device), which the hub acknowledges, then the complete
 * (what did it answer?), to which the hub says "not yet" (NYET) while
 * it does not know. Each at the start of a frame (SOF: the bus's 1ms
 * beat, 125us at high speed), in one of the parity the controller is
 * told (usbdwc.c's chansetup, chanio and chanintr, principia's 9pi).
 *
 * QEMU's controller has no split (a packet goes by its address alone)
 * and says so by its version, 2.94a, a board's being 2.80a: none
 * there, as principia does (its emulating()). */
#define GINTSTS 0x014
#define GSNPSID 0x040
#define HFNUM 0x408
#define HCSPLT(ch) (0x504 + 0x20 * (ch))
#define SOF (1 << 3)
#define SPLIT_ENABLE (1u << 31)
#define SPLIT_ALL (3 << 14)                                /* the data whole, in one */
#define SPLIT_COMPLETE (1 << 16)
#define ODD_FRAME (1u << 29)
#define CHAN_ENABLE (1u << 31)
#define CHAN_DISABLE (1u << 30)
#define XFER_DONE 0x1
#define HALTED 0x2
#define STALL 0x8
#define NAK 0x10
#define ACK 0x20
#define NYET 0x40
#define FRAME_OVERRUN 0x200

/* the hub and its port of the next transfer's device (0: none, the
 * device on the controller's own port) */
static unsigned split_hub, split_port;

value usb_split(value hub, value port)
{
  split_hub = Long_val(hub);
  split_port = Long_val(port);
  return Val_unit;
}

/* the next frame's start, not the last eighth of a millisecond */
static void sof_wait(void)
{
  unsigned i;
  do {
    USB(GINTSTS) = SOF;
    for (i = 0; i < 1000000 && !(USB(GINTSTS) & SOF); i++) ;
  } while ((USB(HFNUM) & 7) == 6);
}

/* the channel started, to its halt: its interrupts' bits, 0 when it
 * never halts. A NAK may leave it enabled, the controller asking again
 * by itself: it is then disabled */
static unsigned chan_run(void)
{
  unsigned i, hcint = 0, naks = 0;
  USB(HCCHAR(0)) = (USB(HCCHAR(0)) & ~CHAN_DISABLE) | CHAN_ENABLE;
  for (i = 0; i < 1000000; i++) {
    hcint = USB(HCINT(0));
    if (hcint & HALTED) return hcint;
    if ((hcint & NAK) && ++naks == 1000) break;
  }
  if (USB(HCCHAR(0)) & CHAN_ENABLE) {
    USB(HCCHAR(0)) |= CHAN_ENABLE | CHAN_DISABLE;
    for (i = 0; i < 1000000 && !(USB(HCINT(0)) & HALTED); i++) ;
  }
  return (hcint & NAK) ? (hcint | HALTED) : 0;
}

/* one transfer of [len] bytes from or to the DMA page: [desc] packs the
 * device's address (bits 0-6), the endpoint (7-10), its type (11-12:
 * 0 control, 3 interrupt), IN (13), low speed (14), the maximum packet
 * (16-26); [pid] 0 DATA0, 2 DATA1, 3 SETUP. The bytes moved, or -1 NAK
 * (or a split not complete: tried again as a NAK is), -2 STALL, -3 an
 * error or no answer */
value usb_transfer(value vdesc, value vpid, value vlen)
{
  unsigned desc = Long_val(vdesc), pid = Long_val(vpid), len = Long_val(vlen);
  unsigned addr = desc & 0x7f, ep = (desc >> 7) & 0xf, type = (desc >> 11) & 3;
  unsigned in = (desc >> 13) & 1, low = (desc >> 14) & 1, mps = (desc >> 16) & 0x7ff;
  unsigned pkts = len == 0 ? 1 : (len + mps - 1) / mps;
  unsigned i, hcint, tries;
  int split = split_hub != 0 && USB(GSNPSID) != 0x4f54294a;
  /* claude: a channel left enabled by a transfer that did not end (its
   * device unplugged: no answer) is disabled first, and waited on: a
   * channel still enabled starts nothing, and every transfer after
   * would fail, to any device */
  if (USB(HCCHAR(0)) & CHAN_ENABLE) {
    USB(HCCHAR(0)) |= CHAN_DISABLE | CHAN_ENABLE;
    for (i = 0; i < 1000000 && !(USB(HCINT(0)) & HALTED); i++) ;
  }
  USB(HCINT(0)) = 0xffffffff;
  USB(HCINTMSK(0)) = 0;                                    /* polled: the channel's interrupt never raised */
  USB(HCTSIZ(0)) = len | (pkts << 19) | (pid << 29);
  USB(HCDMA(0)) = (unsigned)(((uintptr)buffer - KERNBASE + BUS_ALIAS) & 0xffffffffUL);
  USB(HCSPLT(0)) = split ? SPLIT_ENABLE | SPLIT_ALL | (split_hub << 7) | split_port : 0;
  USB(HCCHAR(0)) = mps | (ep << 11) | (in << 15) | (low << 17) | (type << 18) | (1 << 20) | (addr << 22);
  cache_drain();
  if (split) {
    sof_wait();
    if (USB(HFNUM) & 1) USB(HCCHAR(0)) |= ODD_FRAME;
  }
  hcint = chan_run();                                      /* the transfer, or a split's start */
  /* the start acknowledged: the complete, again while the hub says not
   * yet (three times, then the whole is tried again) */
  for (tries = 0; split && tries < 3 && (hcint == (HALTED | ACK) || hcint == (HALTED | NYET)); ) {
    if (hcint == (HALTED | ACK)) USB(HCSPLT(0)) |= SPLIT_COMPLETE;
    else tries++;
    USB(HCINT(0)) = hcint;
    if (USB(HFNUM) & 1) USB(HCCHAR(0)) &= ~ODD_FRAME;
    else USB(HCCHAR(0)) |= ODD_FRAME;
    hcint = chan_run();
  }
  USB(HCINT(0)) = 0xffffffff;
  if (!(hcint & HALTED)) return Val_long(-3);
  if (hcint & XFER_DONE) return Val_long(len - (USB(HCTSIZ(0)) & 0x7ffff));
  if (hcint & STALL) return Val_long(-2);
  if (hcint & (NAK | NYET | FRAME_OVERRUN)) return Val_long(-1);
  return Val_long(-3);                                     /* not complete: an error */
}

/* claude: the PID the channel's next packet would have (HCTSIZ's bits
 * 29-30: 0 DATA0, 2 DATA1), after a transfer: the endpoint's data
 * toggle, which mini-9pi keeps between transfers (usbdwc's hctsiz&Pid) */
value usb_pid(value unit)
{
  (void)unit;
  return Val_long((USB(HCTSIZ(0)) >> 29) & 3);
}

/* claude: a second channel, its own DMA page, for a transfer left
 * pending: a bulk IN the controller tries again at each NAK by itself
 * (the DWC2's, QEMU's too: a disabled channel's retries go on there),
 * started, then polled from the clock (mini-9pi's Etherusb: a frame a
 * transfer, a short packet its end). [usb_start1 desc pid len] as
 * usb_transfer's; [usb_poll1 ()] -1 still pending, else the bytes
 * moved, or -2 STALL, -3 an error */
value usb_buffer1(value unit) { (void)unit; uncache(); return Val_long((uintptr)buffer1 - KERNBASE); }

value usb_start1(value vdesc, value vpid, value vlen)
{
  unsigned desc = Long_val(vdesc), pid = Long_val(vpid), len = Long_val(vlen);
  unsigned addr = desc & 0x7f, ep = (desc >> 7) & 0xf, type = (desc >> 11) & 3;
  unsigned in = (desc >> 13) & 1, low = (desc >> 14) & 1, mps = (desc >> 16) & 0x7ff;
  unsigned pkts = len == 0 ? 1 : (len + mps - 1) / mps;
  USB(HCINT(1)) = 0xffffffff;
  USB(HCINTMSK(1)) = 0;
  USB(HCTSIZ(1)) = len | (pkts << 19) | (pid << 29);
  USB(HCDMA(1)) = (unsigned)(((uintptr)buffer1 - KERNBASE + BUS_ALIAS) & 0xffffffffUL);
  USB(HCCHAR(1)) = mps | (ep << 11) | (in << 15) | (low << 17) | (type << 18) | (1 << 20) | (addr << 22);
  cache_drain();
  USB(HCCHAR(1)) |= 1u << 31;
  return Val_unit;
}

value usb_poll1(value vlen)
{
  unsigned len = Long_val(vlen), hcint = USB(HCINT(1));
  if (!(hcint & 0x2)) return Val_long(-1);                 /* not halted: pending */
  USB(HCINT(1)) = 0xffffffff;
  if (hcint & 0x8) return Val_long(-2);
  if (!(hcint & 0x1)) return Val_long(-3);
  return Val_long(len - (USB(HCTSIZ(1)) & 0x7ffff));
}

value usb_pid1(value unit) { (void)unit; return Val_long((USB(HCTSIZ(1)) >> 29) & 3); }
