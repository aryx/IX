(* The BCM2835's PWM (base + 0x20C000) and its clock: the sound of the
 * board's 3.5 mm jack.
 *
 * The jack is not a converter of numbers to voltages. It is two pins
 * that are only ever high or low, each behind a resistor and a
 * capacitor, and the trick of pulse width modulation: a pin that is
 * high for a part of a short period, over and over, is, once the
 * capacitor has smoothed it, a voltage that is that part of the
 * supply's. A period of [range] ticks of a fast clock, a number below
 * [range] for the ticks the pin is high:
 *
 *      range = 8, data = 2          range = 8, data = 6
 *      __      __      __           ______  ______  ______
 *     |  |____|  |____|  |____     |      ||      ||      |_
 *      a quarter of 3.3 V           three quarters
 *
 * A new number at each period is a sample; the periods a second are
 * the sampling rate. The clock manager (base + 0x1010A0) makes the
 * fast clock from one of the board's oscillators and a divisor; the
 * kernel that wants 44,100 samples a second of about 12 bits asks
 * PLLD's 500 MHz divided by 2, and a range of 5,669:
 *
 *     250,000,000 / 5,669 = 44,099.5 periods a second
 *
 * The registers (Circle's names; the two channels are the two ears):
 *
 *     0x00 CTL    a channel on (PWEN1, PWEN2), fed by the FIFO (USEF1,
 *                 USEF2) or by its DAT register; CLRF1 empties the FIFO
 *     0x04 STA    the FIFO full (FULL1) or empty (EMPT1), a write when
 *                 full (WERR1), a period with nothing to play (GAPO1,
 *                 GAPO2): those written 1 to clear
 *     0x08 DMAC   the FIFO asks the DMA controller for its words (ENAB)
 *     0x10 RNG1   0x20 RNG2    a channel's range
 *     0x14 DAT1   0x24 DAT2    its data, when not fed by the FIFO
 *     0x18 FIF1   a word into the FIFO, 8 words deep; with both
 *                 channels on it, their words by turns, 1 then 2
 *
 * Nobody can write 88,200 words a second to FIF1 by hand and do
 * anything else. So the DMA controller does: a control block says
 * "these 4,096 words of memory to FIF1, when it asks" (TI's DEST_DREQ,
 * and PERMAP 5, this device's request line), and the controller moves
 * a word each time the FIFO has room, interrupting at the block's end
 * for the kernel to give the next. Here the FIFO's asking is this
 * module pulling from Dma, a period's words at a time, as the board's
 * time goes by ([advance]): **the sound is what paces the transfer**,
 * which is why Dma's transfers at once (enough for the SD card) were
 * not enough for it.
 *
 * What is ours: a period is not drawn tick by tick. A sample is its
 * number over its range, given to [output] as 16 bits around zero,
 * with the rate, as a sound card would have it; so M/S and the PWM
 * algorithm (MSEN, which say where in the period the pin is high) are
 * the same here. The pins' function in the GPIO is not looked at (a
 * kernel that forgets it is heard here and not on the board). The
 * polarity, the serializer and the silence bit are not modelled.
 *
 * others:
 * QEMU models this device as registers that remember, and its raspi
 * boards have no sound but a USB audio device plugged in. The Pi's
 * other ways out are the HDMI cable (the firmware's, by VCHIQ) and
 * I2S, a real converter on the header's pins.
 *
 * References: BCM2835 ARM Peripherals, chapter 9 (the PWM) and 6.3
 * (the clocks) (from memory); Circle's lib/sound/pwmsoundbasedevice.cpp,
 * lib/gpioclock.cpp and include/circle/dmacommon.h (read 2026-10-11:
 * the bits, the request lines, the clocks' rates, the pins by board). *)

type t

(* [create ~pi4 ~dma ~yield]: the device, its words asked of [dma] when
 * DMAC says so; [yield] is called when the guest finds the FIFO full
 * (the board ends its batch of instructions there: time passes a
 * batch at a time, and a guest that writes by hand would fill the 8
 * words at a batch's start and have no room for the 12 the batch
 * lasts); [pi4]: the Pi 4's clocks (PLLD 750 MHz, the oscillator 54)
 * and request line (1: its second PWM), where the Pi 1's (500 MHz,
 * 19.2; 5) *)
val create : pi4:bool -> dma:Dma.t -> yield:(unit -> unit) -> t

(* the PWM's registers, and the clock manager's two for it (CTL, DIV:
 * to map at the manager's base + 0xA0) *)
val device : t -> Memory.device
val clock : t -> Memory.device

(* where the samples go: the rate (periods a second, rounded), then the
 * first channel's and the second's, each -32768 to 32767; none at
 * first: the samples are dropped *)
val set_output : t -> (rate:int -> int -> int -> unit) -> unit

(* the board's time moved on by microseconds: the periods that fit are
 * played *)
val advance : t -> int -> unit

(* the microseconds until the DMA's block ends (its interrupt), for an
 * idle CPU; a large number when nothing is being played *)
val until_next : t -> int
