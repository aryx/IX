(* LZW: GIF's compression, with a dictionary built while reading.

   Huffman codes (Huffman.mli) give short codes to common symbols. But a
   picture repeats whole *sequences*, such as a row of sky or a sprite's
   outline. Lempel and Ziv's second method (LZ78, 1978), made fast by
   Terry Welch at Sperry (LZW, 1984), gives a code to every sequence
   already seen. The dictionary is never sent: the decoder builds the
   same one from the codes alone. GIF (1987) took the method. Then
   Unisys, which Sperry had become, enforced its patent on it (1994),
   and the web answered with PNG (Png.mli). The patent expired in
   2003-2004.

   GIF's variant, for pictures of up to 256 colors, works this way:

   - The dictionary starts with one entry per color (with 4 colors,
     codes 0 to 3), then two special codes: *clear* = 1 lsl
     min_code_size (4 here), which starts again with a fresh
     dictionary, and *end* = clear + 1 (5). New entries are numbered
     from end + 1 (6) on.
   - Codes have a variable width. They are min_code_size + 1 bits at
     first (3), and one bit more when the next code to add no longer
     fits (after adding code 7, the next is 8 = 2^3). They grow up to
     12 bits, or 4096 entries; the dictionary is then full, and stays
     so until a clear.
   - Bits are packed least significant first.

   The encoder keeps the longest sequence w that is still in the
   dictionary. When w + the next pixel isn't in it, the encoder sends
   w's code and adds w + pixel. The decoder adds each entry one step
   later: when it reads a code (except the first after a clear), it adds
   the previous code's sequence + the first pixel of this one. There is
   one exception, called KwKwK: the code read is the very one the
   encoder has just added, which the decoder doesn't know yet. That only
   happens when the new sequence is the previous one plus its own first
   pixel, so that is what the decoder adds.

   Here is the worked example (the playground's notes_images.md, section
   4): six pixels of color 1, with 4 colors and min_code_size 2.

     encoder                     emits  adds
     w = 1
     pixel 1: "11" not known     1      6 = "11"    w = 1
     pixel 1: "11" known                            w = 11
     pixel 1: "111" not known    6      7 = "111"   w = 1
     pixel 1: "11" known                            w = 11
     pixel 1: "111" known                           w = 111
     end of pixels               7
     stream: clear(4) 1 6 7 end(5)

     decoder     width  code  output   adds
     (clear)     3      1     1
                 3      6     1 1      6 = 1 + 1   (6 unknown: KwKwK)
                 3      7     1 1 1    7 = 11 + 1  (7 unknown: KwKwK)
         the next code, 8, needs 4 bits
                 4      5     (end)

   Packed least significant bit first, with 4 in 3 bits, then 1, 6, 7,
   then 5 in 4 bits, this makes 16 bits: the two bytes 8C 5F.

   These are the places where LZW decoders go wrong, and each is worth
   a test:
   - The clear code is 1 lsl min_code_size. (imagelib, the pure-OCaml
     library this repository once used, computes 1 lsl (min_code_size -
     1); see the playground's Image_decode.ml.)
   - When the width grows: after adding an entry, when the next code
     reaches 2^width. An encoder that grows it one code early (TIFF's
     "early change") writes another format.
   - The KwKwK case.
   - A full dictionary without a clear.

   terminology:
   LZ77, LZ78, LZW. Lempel and Ziv published two methods a year
   apart. LZ77 has no dictionary but the text itself: it says "copy 9
   bytes from 3 bytes back", within a window of what was just seen.
   It is the method of deflate (Zlib.mli). LZ78 builds a dictionary of
   sequences as it goes, and sends pairs of (the number of a known
   sequence, the character after it). LZW is Welch's LZ78 with the
   character left out: the dictionary starts with every single symbol,
   so a code alone is enough, and the next code's first symbol is the
   one that would have been sent.

   cs-history:
   The patent. Welch's article of 1984 did not say that Sperry had
   applied for a patent on the method. Programmers took it for free:
   Unix's compress (Spencer Thomas, 1984; the .Z files) and
   CompuServe's GIF. At the end of 1994 Unisys and CompuServe
   announced that programs writing GIF needed a license. In a few
   weeks a group on Usenet had drafted a format without it, PNG
   (1996), with deflate in LZW's place; gzip had replaced compress
   for the same reason two years before. Deflate was also the better
   compression: the patent is why the change was made, not why it
   was a good one.

   References: Terry Welch, "A Technique for High-Performance Data
   Compression", IEEE Computer 17 (1984); Jacob Ziv and Abraham Lempel,
   "Compression of Individual Sequences via Variable-Rate Coding", IEEE
   Transactions on Information Theory 24 (1978); the GIF89a
   specification (CompuServe, 1990), appendix F. *)
(* ix: copied from libs/compression/Lzw.mli in the author's playground
 * (docs/plans/plan_browser.md) *)

(* [decode ~min_code_size data ~npixels] returns the [npixels] color
 * indices of the LZW stream [data] (a frame's sub-blocks, joined). It
 * stops at the end code, or when [npixels] are decoded, or when [data]
 * runs out (the pixels not reached are 0, because some encoders stop
 * early). Raises Failure on a code that can't be there. *)
val decode : min_code_size:int -> string -> npixels:int -> Bytes.t

(* One code read, which is a line of the decoder's table above: the
 * [code], its [width] in bits, the pixels it wrote ([length] of them
 * from [start], none for a clear or the end), and the entry it [added]
 * to the dictionary, if any. *)
type step = { code : int; width : int; start : int; length : int; added : int option }

(* [steps ~min_code_size data ~npixels] returns [decode]'s pixels, and
 * each code it read, in order (the playground's examples/ImageLzw.ml
 * plays them back). For the worked example, the codes are clear, then
 * 1 (no entry), 6 (adds 6) and 7 (adds 7). Then the six pixels are written, and
 * [decode] stops without reading the end code. *)
val steps : min_code_size:int -> string -> npixels:int -> step list * Bytes.t
