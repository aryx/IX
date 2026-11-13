(* Layer III's tables, as ISO/IEC 11172-3 prints them (and 13818-3 for
   MPEG-2's lower sample rates).

   **The Huffman codes** (Table B.7). Layer III's quantized spectrum is
   mostly small numbers, and mostly zeros towards the high frequencies.
   It is sent in pairs (x, y) (the "big values") and then in
   quadruples of 0s and 1s ("count1"). Each pair is one code of a
   table that the encoder picks among 32, for each region of the
   spectrum: the table whose statistics fit best. A table of size n
   codes x and y from 0 to n - 1: table 13's 16 x 16 is for loud music,
   and table 1's 2 x 2 for near silence. In the 16 x 16 tables, values
   of 15 and more are sent as 15, then the rest in "linbits" plain bits
   (the 8 tables made from table 16, and the 8 made from table 24,
   differ only by that). The code gives the magnitude, and a sign bit
   follows each value that is not 0.

   Unlike JPEG's, these codes are fixed, and not canonical
   (Huffman.mli). They are listed code by code, as the standard does,
   and read with Vlc (Vlc.mli), which also reads the codes of MPEG-1
   video's tables.

   **The scalefactor bands** (Table B.8) group the spectrum's 576
   lines (192 in each of a short block's 3 windows) in bands about as
   wide as the ear's *critical bands*: narrow in the low frequencies
   and wide in the high ones, from 4 lines (about 77 Hz at 44,100) at
   the bottom to 158 at the top. Each band gets a scalefactor, its
   loudness, which is what the encoder shapes its noise with. *)

(* ix: copied from libs/audio/formats/mpeg_audio/Layer3_tables.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* each table's codes, for (x, y), row after row *)
val t1 : string array
val t2 : string array
val t3 : string array
val t5 : string array
val t6 : string array
val t7 : string array
val t8 : string array
val t9 : string array
val t10 : string array
val t11 : string array
val t12 : string array
val t13 : string array
val t15 : string array
val t16 : string array
val t24 : string array

(* the tables by table_select, 0 to 31: the codes, the size and the
 * linbits; None for table 0 (zeros, with no bits sent) and for the
 * unused 4 and 14 *)
val pairs : (string array * int * int) option array

(* count1's quadruples (v, w, x, y) of 0s and 1s, indexed by
 * v * 8 + w * 4 + x * 2 + y: table A is a Huffman code, and table B
 * is 4 plain bits, each inverted *)
val quad_a : string array
val quad_b : string array

(* [long_bands rate] gives the starts of the 22 long bands, then 576;
 * [short_bands rate] gives those of the 13 short bands, then 192 *)
val long_bands : int -> int array
val short_bands : int -> int array

(* the preemphasis of the 22 long bands (Table B.6) *)
val pretab : int array

(* for each scalefac_compress, 0 to 15, the bits of each low band's
 * scalefactor and of each high band's (MPEG-1) *)
val slen : (int * int) array

(* MPEG-2's scalefactors, in 4 partitions: how many are in each, by
 * coding (0 to 5) and by block (long, short, mixed) *)
val nr_of_sfb : int array array array
