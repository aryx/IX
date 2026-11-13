(* Vlc: variable-length codes fixed once, in a standard, and written as a
 * table the way the standard prints it.

   JPEG sends its Huffman tables in the file (Jpeg.mli), each picture
   with its own, and they are rebuilt from their lengths (Huffman.mli
   has the canonical codes). MPEG fixes its codes once, in the
   standard, built from statistics of typical data: short codes for
   what is common, long ones for what is rare. They are not canonical,
   so a table is the list of its codes. A code here is written as the
   standard prints it, "0000 0101 11", with spaces for the eye. It is
   read bit by bit, down a binary tree until a leaf.

   A code table must be **prefix-free** (no code is the start of
   another, so the reader knows where each one ends), and [of_list]
   checks it. *)

(* ix: copied from libs/compression/Vlc.mli in the author's playground;
 * its Bits module is Bitstream here (docs/plans/plan_audio.md) *)

type 'a t

(* [of_list codes] builds the tree of [codes], given as (code, value)
 * pairs. Raises Invalid_argument if one is a prefix of another. *)
val of_list : (string * 'a) list -> 'a t

(* [read bits table] returns the next code's value. Raises Failure if
 * the bits are not a code of the table. *)
val read : Bitstream.t -> 'a t -> 'a

(* the Kraft sum of [codes], the sum of 2^-length: it is at most 1 for
 * any prefix-free code, and 1 when no bit string is left out *)
val kraft : (string * 'a) list -> float
