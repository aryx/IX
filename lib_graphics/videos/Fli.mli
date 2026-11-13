(* Fli reads FLI and FLC, Autodesk Animator's movies, where a frame is
 * stored as what changed since the one before.

   Jim Kent's Autodesk Animator (1989, DOS, 320 x 200 in 256 colors)
   saved its animations as FLI, and Animator Pro (early 1990s) saved
   them as FLC, the same idea for any size. Hundreds of DOS games
   played their cut-scenes from them. The idea is that the first frame
   is stored whole, run-length coded, and every other one is stored as
   **the pixels that changed**, the rest being left as they were. A
   still background costs nothing, and a moving ball costs its
   outline. It was the first video compression most programmers met,
   and it is still the simplest one that works.

   Here is a file, with all numbers little-endian (the PC's order):

     offset  size
          0     4   the file's size
          4     2   AF11 (FLI) or AF12 (FLC)
          6     2   the frames (not counting the ring frame, below)
          8   2+2   width, height (FLI: 320 x 200)
         12     2   bits a pixel: 8
         16     4   the delay between frames: FLI in 1/70 s (the VGA's
                    refresh), FLC in milliseconds
         80   4+4   FLC: where frames 1 and 2 start
        128         the frames

     a frame:   size (4), F1FA (2), chunks (2), 8 bytes (in FLC, a
                delay of its own), then its chunks
     a chunk:   size (4), type (2), then:

       COLOR_256 (4), COLOR_64 (11)   the palette entries that changed:
           packets of (entries to skip, entries to set (0 means 256),
           and r g b for each), in 0-255, or in 0-63 as the VGA's DAC
           took them
       BRUN (15)   the whole frame, a line at a time, run-length coded:
           a byte (the count of packets in FLI; FLC ignores it), then
           packets of a signed byte n and
             n > 0:  one byte, n times         (a run)
             n < 0:  -n bytes as they are      (literals)
       LC (12, "line compressed", FLI's delta)   the lines to skip and
           the lines changed (2 + 2), then for each changed line its
           packets (1), each one a byte of columns to skip and a
           signed byte n:
             n > 0:  n bytes as they are       (the other way around
             n < 0:  one byte, -n times         from BRUN's)
       DELTA_FLC (7, FLC's delta)   the same with 16-bit words (two
           pixels at a time, which was faster on a 386). A word whose
           top bits are 11 skips whole lines (-n means n lines), a word
           whose top bits are 10 gives the last pixel of an odd line,
           and any other word is a count of packets
       BLACK (13) makes all pixels color 0; COPY (16) is the frame
       raw; the others (a thumbnail, PSTAMP 18) are skipped

   Here is a worked example: a line of 8 pixels that is
   0 0 0 0 0 0 0 0 before and 0 0 5 5 0 0 9 0 after. In LC, it is 2
   packets: skip 2 columns, then one byte 5 twice; skip 2 columns,
   then the one byte 9:

     02   02 FE 05   02 01 09          7 bytes for 8, and a line that
                                       didn't change takes none at all

   As BRUN, the line 7 7 7 7 1 2 3 is 2 packets, a run of 4 sevens and
   3 literals: 02 04 07 FD 01 02 03.

   Animator ended a file with a **ring frame**, the delta from the last
   frame back to the first, for looping without a jump. It isn't
   counted, it isn't read here, and it isn't written.

   This module only reads, since a player writes nothing. The tests'
   Fli_write writes the files that the tests read back. *)

type format = Fli | Flc

type header = { format : format; width : int; height : int; frames : int; delay : float (* seconds between frames *) }

(* [of_string s] gives the header and the frames, decoded forward only,
 * each from the one before (Movie.sequential). It raises Failure if [s]
 * isn't an FLI or FLC file, or is a corrupt one. *)
val of_string : string -> header * Movie.t
