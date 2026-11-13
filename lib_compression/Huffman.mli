(* Huffman codes: short codes for common symbols, rebuilt from their
   lengths alone.

   David Huffman's algorithm (1952, a term paper in Robert Fano's class)
   gives each symbol a code of bits, shorter when the symbol is more
   common. No code is the beginning of another (it is a *prefix-free*
   code), so the bits can be read one by one with no separator. For the
   eight symbols AAAABBCD (the playground's notes_images.md, section 3):

         (8)
        0/ \1           A = 0      AAAABBCD = 0 0 0 0 10 10 110 111
        A  (4)          B = 10     is 14 bits, where 2 bits per symbol
          0/ \1         C = 110    would take 16: 1.75 bits per symbol,
          B  (2)        D = 111    exactly the entropy of the source
            0/ \1
            C   D

   A decoder needs the same code as the encoder, and sending the tree is
   wasteful. DEFLATE (and JPEG, which met the same idea a second time)
   sends only each symbol's *code length*, and both sides rebuild the
   one *canonical* code with those lengths: shorter codes come first,
   and within a length the symbols are in order, counting up. With the
   lengths A 1, B 2, C 3, D 3:

     how many codes of each length:     1 -> 1,  2 -> 1,  3 -> 2
     the first code of each length:     1:  0
                                        2: (0 + 1) << 1 = 2  = 10
                                        3: (2 + 1) << 1 = 6  = 110
     then counting up within a length:  A 0,  B 10,  C 110,  D 111

   (RFC 1951, section 3.2.2.) Decoding needs no table of codes at all.
   We read a bit at a time, and at each length we check whether the code
   read so far falls within that length's range of codes: the codes of
   length [len] are the [count.(len)] numbers that start at the first
   code of that length. This is the decoder of Mark Adler's puff.c, and
   it is the one here. It takes at most 16 steps per symbol, which is
   slow next to zlib's lookup tables but plenty for the playground's
   pictures.

   JPEG (Jpeg.mli) sends a table differently: first how many codes there
   are of each length, 1 to 16, then the symbols in the order of their
   codes. The symbols are not sorted by value, so JPEG uses [of_counts]
   rather than [of_lengths]; the codes are the same canonical ones.

   Lengths are at most 16 (this is JPEG's limit; DEFLATE's is 15). A set
   of lengths can be *over-subscribed*, with more codes than the bits
   allow (e.g. three codes of length 1), and that is an error. It can be
   *incomplete*, with codes left over (e.g. a single code of length 1,
   which DEFLATE uses for a block with one distance). That is allowed,
   and decoding one of the missing codes is then an error.

   cs-history:
   In 1951 Robert Fano gave his information theory class at MIT a
   choice: a final exam, or a term paper on finding the most efficient
   binary code. Fano's own method, and Claude Shannon's (the
   Shannon-Fano code), work from the top: split the symbols in two
   groups of about equal weight, give one a 0 and the other a 1, and
   split each again. It is good and not always the best. Huffman, a
   student, went from the bottom: join the two *rarest* symbols under
   one node, which then counts as one symbol with their weights added,
   and repeat until one node is left. That is the tree above (C and D
   first, then B, then A), and it is proved optimal among the codes
   that give each symbol a whole number of bits.

   others:
   A whole number of bits is the limit: a symbol that comes 99 times
   in 100 deserves a hundredth of a bit and gets one. Arithmetic
   coding (Jorma Rissanen and Richard Pasco, 1976) writes a whole
   message as one number and has no such floor; JPEG has it as an
   option that patents kept nearly unused. Asymmetric numeral systems
   (Jarek Duda, 2009) get the same gain at about one table lookup per
   symbol, and they are what Zstandard uses, next to Huffman codes for
   its literals.

   modern:
   zlib does not read a bit at a time as [decode] does: it takes the
   next several bits of the input at once as an index in a table
   built for the block, which gives the symbol and how many of those
   bits its code really was (a second table for the longer codes).
   The table costs time to build, repaid on any block of some size.

   References: David Huffman, "A Method for the Construction of
   Minimum-Redundancy Codes", Proceedings of the IRE 40 (1952); Peter
   Deutsch, RFC 1951 (1996), section 3.2.2; Mark Adler, puff.c, in
   zlib's contrib/puff/. *)
(* ix: copied from libs/compression/Huffman.mli in the author's
 * playground (docs/plans/done/plan_pdf.md) *)

(* a canonical code, ready to decode *)
type t

(* the length of the longest code *)
val max_bits : int

(* [of_lengths lengths] is the canonical code where symbol [i] has a
 * code of [lengths.(i)] bits, 0 meaning the symbol has no code. Raises
 * Failure if the lengths are over-subscribed. *)
val of_lengths : int array -> t

(* [of_counts counts symbols] takes JPEG's form: there are [counts.(i)]
 * codes of length [i + 1] (16 counts), given to [symbols] in order.
 * Raises Failure if the counts are over-subscribed, or don't add up to
 * the number of symbols. *)
val of_counts : int array -> int array -> t

(* [decode next_bit code] returns the next symbol, reading its code one
 * bit at a time with [next_bit] (the code's most significant bit
 * first). Raises Failure on a code that isn't there (in an incomplete
 * code). *)
val decode : (unit -> int) -> t -> int

(* [codes lengths] gives each symbol's (code, length), as the encoder
 * writes them, and (0, 0) for a symbol without a code. For A 1, B 2,
 * C 3, D 3, it gives [| (0, 1); (2, 2); (6, 3); (7, 3) |]. *)
val codes : int array -> (int * int) array
