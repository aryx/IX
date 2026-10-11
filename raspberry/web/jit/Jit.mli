(* The board's ARM instructions translated to JavaScript, for mini-qemu
 * in a web page: a run of instructions reached often becomes a
 * function of JavaScript's, which the browser then compiles to the
 * host's own instructions. The interpreter (Arm32, Board.run) is
 * untouched, and is what runs everything else.
 *
 *     Board.run, at each instruction, asks Board.blocks (this module):
 *       a block starts here --> its function runs
 *       none               --> the interpreter runs the one instruction;
 *                              a place reached by a jump 200 times is
 *                              translated
 *     a block's function runs 1 to 64 instructions, or a loop's turns,
 *     and the next block's follows it without the board's loop
 *
 *     ldr r3, [r0, #4]    R[16]=...;q=R[1];y=(q+(4))|0;a=y;
 *                         p=TR(a,1,0);v=L32(p);R[4]=v;
 *     TR: the TLB's line,     TG[i]===a>>>12 && (RT[i]&1) ? PG[i]|(a&4095) : the emulator's
 *     L32: the RAM's word,    p < RAM && !(p&3) ? I32[p>>2] : the emulator's
 *
 * terminology: a block here is straight code from a place a jump
 * reaches to an instruction that always leaves (bx, pop {pc}, mov pc),
 * a page's end or 64 instructions; a conditional branch inside it
 * leaves or goes on, and an unconditional b or bl to a place of the
 * same page is followed (a trace: the call and what is called in one
 * function). A dynamic binary translator's, or a JIT's, basic block
 * extended.
 *
 * design: what is translated and what is not.
 * - Translated: the data-processing instructions (shifts by a register
 *   too, pc written), loads and stores of words, halves and bytes, push
 *   and pop, b, bl, bx, mul, the extensions: what compiled code is
 *   mostly made of. Anything else is one call of the interpreter from
 *   inside the block, and the block ends there when that instruction
 *   may change what interrupts or how addresses are translated.
 * - The state is the emulator's own: the registers' array, the flags'
 *   fields, the TLB's arrays, the RAM's bytes, read and written where
 *   they are (js_of_ocaml's values are JavaScript's arrays). The
 *   interpreter and a block can so follow each other at any
 *   instruction, and an abort inside a block is the interpreter's.
 * - The same instructions are counted (the board's time is its
 *   instructions), and interrupts are taken where the interpreter takes
 *   them, to a block's end: looked at when the board's loop is back,
 *   and it is back after a store to a device or an instruction that
 *   may unmask them. Blocks follow each other without the board's loop
 *   for 1024 instructions at most. Boot_bench's sessions give the same
 *   console with and without; the instructions counted are within a
 *   hundredth (a tick comes some instructions later).
 * - A block is kept by the physical address of its first instruction
 *   and its words, and found for an address through the TLB: an
 *   emptied TLB (each switch of process) costs one look a page of
 *   code. A kernel built for a page says which pages of instructions
 *   it wrote (Board.blocks_written). Another kernel is trusted no
 *   further than the interpreter's decode cache trusts it: at each
 *   invalidation of the instructions' cache, and each time the TLB is
 *   emptied, every block is compared with the memory before it runs
 *   again (the Pi's own mini-9pi boots so in 33 s under node, where
 *   51 by the interpreter).
 * - A block's text is what is compiled, and the same text is compiled
 *   once: a program run again has its pages elsewhere and the same
 *   blocks.
 *
 * To find a wrong translation (Boot_jit, by the environment):
 * JIT_CHECK=1, each block's first run done again by the interpreter
 * from the same registers and memory, and the two compared;
 * JIT_WITHOUT=reg,pc,mem,follow, kinds of instructions left to the
 * interpreter; JIT_MOST=n, n blocks and no more, the last one's text
 * printed; JIT_THRESHOLD=n.
 *
 * others: QEMU's TCG translates blocks to the host's instructions
 * through its own intermediate code; v86 (an x86 PC in a page)
 * translates hot code to WebAssembly modules; jslinux interprets. Here
 * the target is JavaScript's text, which a browser compiles: no
 * backend to write.
 *
 * Bellard, "QEMU, a Fast and Portable Dynamic Translator" (USENIX
 * 2005). *)

(* [attach board]: the board's blocks are this module's, from now *)
val attach : Board.t -> unit

(* a place reached by a jump so many times is translated (200) *)
val threshold : int ref

(* the blocks compiled, put back after their slot was lost, and not
 * made (the interpreter's instructions mostly) *)
val compiled : int ref
val retexted : int ref   (* made, and their code found by their text *)
val reused : int ref
val refused : int ref
