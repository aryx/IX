/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* The Pi 1's jack from the bare board (docs/plans/plan_audio.md, stage
 * 2): the PWM's clock, its two channels on the FIFO, then a tenth of a
 * second of sound twice, each timed by the board's clock:
 *
 *   by hand   a square wave of 441 Hz, a word written to the FIFO
 *             each time it has room; the right ear upside down
 *   by DMA    a sawtooth of 441 Hz, 8,820 words of memory given to
 *             the FIFO by the DMA controller as it asks, to the
 *             block's end
 *
 * Each is 4,410 periods of 5,669 ticks of a clock of 250 MHz: 100 ms,
 * which the two lines say if the sound paced the writes. What mini-qemu
 * heard is its -audiodev wav's file (pwm.sh). */
#include <u.h>
#include <libc.h>

#define IO	0x20000000
#define REG(a)	(*(volatile uint*)(IO + (a)))

#define CLO		REG(0x3004)	/* the system timer, microseconds */
#define CM_PWMCTL	REG(0x1010a0)	/* the clock manager's clock for the PWM */
#define CM_PWMDIV	REG(0x1010a4)
#define PASSWD		0x5a000000
#define PWM_CTL		REG(0x20c000)
#define PWM_STA		REG(0x20c004)
#define PWM_DMAC	REG(0x20c008)
#define PWM_RNG1	REG(0x20c010)
#define PWM_FIF1	REG(0x20c018)
#define PWM_RNG2	REG(0x20c020)
#define DMA		5		/* the channel */
#define DMA_CS		REG(0x7000 + DMA*0x100)
#define DMA_CONBLK	REG(0x7004 + DMA*0x100)
#define DMA_ENABLE	REG(0x7ff0)

enum {
	Range = 5669,		/* 250 MHz / 5,669 = 44,099.5 periods a second */
	Periods = 4410,		/* a tenth of a second */
	Wave = 100,		/* periods a wave: 441 Hz */

	Pwen1 = 1<<0, Usef1 = 1<<5, Clrf1 = 1<<6, Pwen2 = 1<<8, Usef2 = 1<<13,
	Full1 = 1<<0, Empt1 = 1<<1,
	Enab = 1<<31,

	Inten = 1<<0, Destdreq = 1<<6, Srcinc = 1<<8, Permap = 5<<16,	/* TI */
	Active = 1<<0, End = 1<<1, Int = 1<<2,				/* CS */
};

static uint square[2*Periods], words[2*Periods];
static uint blocks[16];		/* a control block is 8 words at an address of 32 bytes */

static void
say(char *what, uint us)
{
	char line[64];
	int n;

	n = snprint(line, sizeof line, "%s: %d ms\n", what, (us + 500) / 1000);
	write(1, line, n);
}

void
main(void)
{
	uint *cb, t0;
	int i, v;

	/* the waves first: a division is a function here, and the by-hand
	 * loop has 11 microseconds a word */
	for(i = 0; i < Periods; i++){
		v = (i / (Wave/2)) % 2 ? Range/4 : 3*Range/4;
		square[2*i] = v;
		square[2*i+1] = Range - v;
		words[2*i] = words[2*i+1] = (i % Wave) * Range / Wave;
	}

	/* the clock: PLLD's 500 MHz (source 6) by 2, then on */
	CM_PWMDIV = PASSWD | 2<<12;
	CM_PWMCTL = PASSWD | 6;
	CM_PWMCTL = PASSWD | 6 | 1<<4;
	PWM_RNG1 = Range;
	PWM_RNG2 = Range;
	PWM_CTL = Pwen1 | Usef1 | Pwen2 | Usef2 | Clrf1;

	/* by hand: the first channel's word, then the second's */
	t0 = CLO;
	for(i = 0; i < 2*Periods; i++){
		while(PWM_STA & Full1)
			;
		PWM_FIF1 = square[i];
	}
	while(!(PWM_STA & Empt1))
		;
	say("by hand", CLO - t0);

	/* by DMA: both channels the same sawtooth */
	cb = (uint*)(((uint)blocks + 31) & ~31);
	cb[0] = Permap | Destdreq | Srcinc | Inten;
	cb[1] = (uint)words | 0xc0000000;	/* a bus address: the memory, not through the VideoCore's cache */
	cb[2] = 0x7e20c018;			/* FIF1's */
	cb[3] = sizeof words;
	cb[4] = 0;
	cb[5] = 0;				/* no next block */
	cb[6] = cb[7] = 0;
	DMA_ENABLE |= 1<<DMA;
	DMA_CS = 1<<31;				/* reset */
	DMA_CONBLK = (uint)cb | 0xc0000000;
	PWM_DMAC = Enab | 7<<8 | 7;
	t0 = CLO;
	DMA_CS = Active;
	while(DMA_CS & Active)
		;
	say((DMA_CS & (End|Int)) == (End|Int) ? "by DMA" : "by DMA, no end", CLO - t0);
	PWM_DMAC = 0;
	PWM_CTL = 0;
	exits(nil);
}
