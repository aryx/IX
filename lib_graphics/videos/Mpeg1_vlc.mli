(* Mpeg1_vlc has MPEG-1's variable-length codes: the standard's tables
   (ISO/IEC 11172-2, annex B), as it prints them, read with Vlc.

   Each table is a lesson in what is common in video:

     macroblock_address_increment   "1" means "the next macroblock",
       the usual case; longer codes skip some macroblocks (those left
       as they were)
     macroblock_type                says what a macroblock is, for each
       picture type. In a P picture, "1" (moved and corrected) is the
       commonest, and intra (coded alone) is 5 bits long, the rare case
     coded_block_pattern            says which of the 6 blocks (4 Y,
       Cb, Cr) carry a correction. "111" (all four Y, not the color) is
       the commonest
     motion_code                    a vector's difference from the
       last one's. "1" (no change) is the commonest, because things
       move together
     dct_dc_size_*                  JPEG's DC sizes
     dct_coefficient                (run of zeros, level) pairs. "11s"
       is for (0, 1), the commonest, where "s" is the sign; EOB is
       "10"; the escape "0000 01" is for the rest, with run and level
       written plainly *)

type mb_type = { quant : bool; forward : bool; backward : bool; pattern : bool; intra : bool }

val address_increment : (string * int) list (* 1-33, and -1 for stuffing, -2 for escape (+33) *)
val mb_type_i : (string * mb_type) list
val mb_type_p : (string * mb_type) list
val mb_type_b : (string * mb_type) list
val coded_block_pattern : (string * int) list (* 1-63, where bit 5 is the first Y block *)
val motion_code : (string * int) list (* -16 to 16, with the sign in the code *)
val dc_size_luminance : (string * int) list
val dc_size_chrominance : (string * int) list

type coefficient = Coeff of int * int (* run, level; the sign bit follows *) | Eob | Escape

val dct_first : (string * coefficient) list (* a non-intra block's first coefficient: "1s" is (0, 1) *)
val dct_next : (string * coefficient) list (* the others: "11s" is (0, 1), "10" is EOB *)
