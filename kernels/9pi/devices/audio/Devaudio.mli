(* '#A' is the sound (Plan 9's devaudio, audio(3)). Its files are:
 * - /dev/audio, where the samples to play are written: 16 bits signed,
 *   the low byte first, the left ear then the right one, 44,100 pairs a
 *   second, which is how a CD's or a WAV's samples are;
 * - /dev/volume, in text ("audio out 80", "speed out 22050");
 * - /dev/audiostat, which says how full the kernel's buffer is.
 * The device under it is the Pi's own jack (docs/plans/plan_audio.md,
 * stage 3).
 *
 * This part is for a reader who knows OCaml and not the hardware. A
 * sound is a pressure that changes. A sample is its value at one
 * instant, a number, and 44,100 of them a second are enough for what an
 * ear hears. The Pi 1 has no converter from a number to a voltage (a
 * DAC). It has a PWM (pulse width modulation) instead: a pin that is on
 * for a part of a short period and off for the rest, where the part is
 * given by the number.
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
 * So the samples must come one in each period, 88,200 words a second
 * (for two ears), with no gap, because a late one is a click. The
 * kernel cannot be that punctual (it looks at its devices every 10 ms),
 * and does not try. A second device, the DMA controller (direct memory
 * access), copies words from memory to the PWM each time the PWM asks
 * for one. The kernel's part is to keep that memory filled ahead of the
 * DMA:
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
 * The DMA goes round the ring for ever, so when no program writes, it
 * plays the silence that was put behind it. Nothing here waits for an
 * interrupt, and the kernel has no time to keep.
 *
 * When the writer is late, the ring runs empty, silence is heard, and
 * the next write starts just ahead of the DMA again (audiostat's
 * "empty" counts those times). When the kernel itself is away for more
 * than the ring's 370 ms (which does not happen in any system call
 * today), a third of a second is heard twice.
 *
 * design:
 * This is Plan 9's interface, as it is: bytes of one fixed format are
 * written to one file, and text to another. There is no library, no
 * ioctl, and no negotiation of formats: cat plays a file, and a program
 * on another machine plays here by importing /dev. What a program wants
 * beyond that (mixing several sounds, another rate, a compressed file)
 * it does itself, before the write (lib_audio, mini-play).
 *
 * others:
 * Circle (R. Stange's bare-metal C++ library for the Pi) drives the
 * same device with two buffers and an interrupt at the end of each one,
 * which asks the program for the next buffer. principia's 9pi has no
 * sound on the Pi: its devaudio is for the PC's SoundBlaster, and its
 * arm dma.c is for the SD card. Linux's driver for the jack goes
 * through the VideoCore (the firmware plays the sound, given through a
 * message queue). That is why the registers used here are little
 * documented: the Broadcom manual has the PWM and the DMA, but not the
 * PWM's clock.
 *
 * References: audio(3) of the Plan 9 manual. "BCM2835 ARM
 * Peripherals" (Broadcom, 2012), chapters 4 (DMA) and 9 (PWM), and
 * its errata at elinux.org; G. van Loo, "BCM2835 Audio and PWM clocks"
 * (2013), for the clock manager's registers. Circle's
 * lib/sound/pwmsoundbasedevice.cpp and lib/machineinfo.cpp (which pin
 * is which ear, by board). docs/plans/plan_audio.md. *)

(* registers the device; nothing of the board is touched until
 * /dev/audio is first opened (QEMU has no PWM, and its sessions never
 * open it) *)
val init : unit -> unit

(* called at each tick: finds where the DMA is, and makes what it played
 * silence *)
val clock : unit -> unit
