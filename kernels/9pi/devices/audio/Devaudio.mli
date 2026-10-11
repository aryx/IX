(* '#A', the sound (Plan 9's devaudio, audio(3)): /dev/audio, written
 * the samples to play (16 bits signed, the low byte first, the left
 * ear then the right one, 44,100 pairs a second: a CD's, a WAV's
 * samples as they are); /dev/volume, text ("audio out 80", "speed out
 * 22050"); /dev/audiostat, how full the kernel's buffer is. The device
 * under it is the Pi's own jack (docs/plans/plan_audio.md, stage 3).
 *
 * For a reader who knows OCaml and not the hardware. A sound is a
 * pressure that changes; a sample is its value at one instant, a
 * number, and 44,100 of them a second are enough for what an ear
 * hears. The Pi 1 has no converter from a number to a voltage (a DAC).
 * It has a PWM (pulse width modulation): a pin that is on for a part
 * of a short period and off for the rest, the part being the number.
 * The jack's resistors and capacitors smooth the pulses, and what is
 * left is their average:
 *
 *     a sample: 16 bits, -32768 .. 32767
 *        |  moved to 0 .. range (5,669: so 12 bits and a half are kept)
 *        v
 *     the PWM's period: range ticks of its clock (250 MHz), the pin
 *     on for that many of them; 250,000,000 / 5,669 = 44,099.5
 *     periods a second: the period is the sample's time
 *
 * So the samples must come one each period, 88,200 words a second (two
 * ears), with no gap: a late one is a click. The kernel cannot be that
 * punctual (it looks at its devices every 10 ms), and does not try: a
 * second device, the DMA controller (direct memory access), copies
 * words from memory to the PWM each time the PWM asks for one. The
 * kernel's part is to keep that memory filled ahead of it:
 *
 *     a program            the kernel (here)             the board
 *     write(/dev/audio) -> each sample to a PWM word,
 *                          in the ring, after the last
 *                          one written; the writer
 *                          sleeps while the ring is
 *                          full
 *                               the ring: 32 pages   --> DMA --> PWM --> jack
 *                               of words, each page      (a word when
 *                               its control block,       the PWM asks)
 *                               the last block's
 *                               next the first
 *     every 10 ms (Main's tick): where the DMA is now (a register);
 *     what it played since the last look is written over with silence
 *
 * The DMA goes round the ring for ever: when no program writes, it
 * plays the silence that was put behind it. Nothing here waits for an
 * interrupt, and no time is the kernel's to keep.
 *
 * What is lost when the writer is late: the ring runs empty, silence
 * is heard, and the next write starts just ahead of the DMA again
 * (audiostat's "empty" counts those). When the kernel itself is away
 * more than the ring's 370 ms (it does not happen in a system call of
 * today's), a third of a second is heard twice.
 *
 * design:
 * Plan 9's interface, as it is: bytes of one fixed format written to a
 * file, text to another. No library, no ioctl, no negotiation of
 * formats: cat plays a file, and a program on another machine plays
 * here by importing /dev. What a program wants beyond that (mixing
 * several sounds, another rate, a compressed file) it does itself,
 * before the write (lib_audio, mini-play).
 *
 * others:
 * Circle (R. Stange's bare-metal C++ library for the Pi) drives the
 * same device with two buffers and an interrupt at each one's end,
 * asking the program for the next; principia's 9pi has no sound on
 * the Pi (its devaudio is the PC's SoundBlaster, its arm dma.c the SD
 * card's). Linux's driver for the jack goes to
 * the VideoCore (the firmware plays, through a message queue), which
 * is why the registers used here are little documented: the Broadcom
 * manual has the PWM and the DMA, not the PWM's clock.
 *
 * References: audio(3) of the Plan 9 manual. "BCM2835 ARM
 * Peripherals" (Broadcom, 2012), chapters 4 (DMA) and 9 (PWM), and
 * its errata at elinux.org; G. van Loo, "BCM2835 Audio and PWM clocks"
 * (2013), the clock manager's registers. Circle's
 * lib/sound/pwmsoundbasedevice.cpp and lib/machineinfo.cpp (which pin
 * is which ear, by board). docs/plans/plan_audio.md. *)

(* the device registered; nothing of the board touched until
 * /dev/audio is first opened (QEMU has no PWM: its sessions never
 * open it) *)
val init : unit -> unit

(* the tick's: where the DMA is, what it played made silence *)
val clock : unit -> unit
