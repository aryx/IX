(* zlib streams: deflate's compressed blocks, between a two-byte header
 * and an Adler-32 checksum (as in principia's lib_strings/libflate,
 * which git9 uses for its loose objects and packs).
 *
 * A deflate stream is a sequence of blocks. A block is either stored
 * (its bytes as they are) or Huffman-coded over two alphabets: literals
 * and lengths are in one, distances in the other. A length and a
 * distance mean "copy that many bytes from that far back" (LZ77). A
 * block's codes are either the fixed ones of the format, or are sent
 * at its start (dynamic) as code lengths, which are themselves
 * Huffman-coded.
 *
 *    zlib:     | 78 01 | block ... block (the last one flagged) | adler32 |
 *
 * The copy may overlap what it writes, which is what makes a run
 * cheap: "copy 9 from 3 back" after abc gives abcabcabcabc,
 *
 *    a b c
 *    a b c a                     the a just copied...
 *    a b c a b c a b c a b c     ...is copied again: length > distance
 *
 * so the copy goes one byte at a time (a block copy gives the wrong
 * answer here, which is the classic bug), and a distance of 1 gives
 * run-length encoding for free. The bigger lengths and distances share
 * a Huffman code and are told apart by extra bits after it. A block
 * with its own codes sends them as code lengths only (Huffman.mli
 * explains the canonical code), and those lengths are Huffman-coded in
 * turn.
 *
 * Here is that string in one block of fixed codes, with the bits least
 * significant first in each byte:
 *
 *    the last block, fixed codes                 3 bits
 *    literals a b c: 0x30 + 97... in 8 bits     24 bits
 *    code 263: a length of 9                     7 bits
 *    distance code 2: a distance of 3            5 bits
 *    code 256, the end of the block              7 bits
 *    46 bits, 6 bytes: 4B 4C 4A 86 23 00
 *
 * which is what [deflate] writes of it, between the header's 78 01
 * and the checksum's 1D E0 04 99.
 *
 * wib:
 * inflate reads all three kinds of blocks, but deflate writes only
 * blocks with fixed codes, with a greedy LZ77 over hash chains. This is
 * less code to write than dynamic codes, and git reads any valid stream
 * (an object's name is the hash of its uncompressed bytes, so two
 * compressors give the same repository). The cost is size: the fixed
 * codes spend 8 or 9 bits on every literal whatever the text, where a
 * block's own codes would give e and the space 4 or 5 bits.
 *
 * terminology:
 * deflate, zlib, gzip, zip. Deflate is the compression: the blocks,
 * with no header and no checksum (RFC 1951; [inflate_blocks]). zlib
 * is deflate in the envelope drawn above, with two bytes before and an
 * Adler-32 of the uncompressed bytes after (RFC 1950); it is what git,
 * PNG and PDF hold. gzip is deflate in another envelope, with a file's
 * name and time and a CRC-32 (RFC 1952); it is the .gz file, and
 * HTTP's "Content-Encoding: gzip". zip is an archive of many files,
 * each usually deflated. And zlib is also the name of the C library
 * that reads and writes the first three.
 *
 * cs-history:
 * Phil Katz designed deflate for version 2 of his PKZIP (out in
 * 1993, the format published before it). Jean-loup Gailly and Mark
 * Adler wrote it anew as free software: gzip (1992), to replace
 * Unix's compress, whose LZW was patented (Lzw.mli), then the
 * library zlib (1995), made for PNG. Peter Deutsch wrote the three
 * RFCs in 1996 from what those programs did.
 *
 * why-win:
 * Thirty years on, deflate is still what a web page, a PNG picture,
 * a zip file, a PDF and a git object are compressed with. This is not
 * for its ratio, which LZMA (1998), Brotli (2013) and Zstandard (2015)
 * all beat. It was free of patents when LZW was not; it was written
 * down in an RFC that a programmer can implement in a few hundred
 * lines (this file); a decoder needs 32 KB of memory; and one good
 * free library was there for everyone to link.
 *
 * References: P. Deutsch, RFC 1951, "DEFLATE Compressed Data Format
 * Specification version 1.3", and P. Deutsch and J-L. Gailly, RFC
 * 1950, "ZLIB Compressed Data Format Specification version 3.3" (1996),
 * for the formats; M. Adler's puff.c, in zlib's contrib/, for the
 * decoding of canonical codes by counts used here. *)

exception Corrupt of string

(* [inflate_at pos s] returns the bytes, uncompressed, of the stream
 * starting at [pos] of [s], and the position just past the stream (a
 * pack's objects are streams end to end, and their compressed sizes
 * are recorded nowhere). [inflate] does the same at 0. *)
val inflate_at : int -> string -> string * int
val inflate : string -> string * int

(* [inflate_blocks pos s] reads deflate's blocks alone, from [pos]. It
 * looks at no header and no checksum, for a stream whose writer got
 * one of them wrong (such as a PDF file's, in lib_graphics/pdf's
 * Pdf_filter). *)
val inflate_blocks : int -> string -> string
(* the same, and also the position just past the last block, at a byte
 * boundary. A gzip file's members are such blocks between a header and
 * a trailer of their own (mini-gunzip reads them this way). *)
val inflate_blocks_at : int -> string -> string * int

val deflate : string -> string

(* the bytes of a gzip file, uncompressed (RFC 1952: deflate's blocks
 * under another header, with a CRC-32). This is what a web server
 * sends for "Content-Encoding: gzip" (Http). *)
val gunzip : string -> string

(* [gzip name mtime data] makes a gzip file of [data], with the envelope
 * that Plan 9's gzip writes:
 * - a file's name, or none (for the standard input);
 * - the time, as its two halves of 16 bits (an int has 31 bits where
 *   mini-ml builds for arm, and a time since 1970 has needed more than
 *   30 bits since 2004);
 * - 03 (Unix) as the system.
 * Inside are [deflate]'s blocks. *)
val gzip : string option -> int * int -> string -> string

(* the CRC-32 (with the polynomial 0xedb88320, reflected) of [len] bytes
 * of [s] from [pos], as its two halves, the high 16 bits and the low
 * 16. An int has 31 bits where mini-ml builds for arm, and the CRC does
 * not fit in one. A pack index records it for each entry's bytes
 * (version_control's Pack), and a PNG file's chunks are checked and
 * written with it (lib_graphics/images' Png). *)
val crc32_halves : string -> pos:int -> len:int -> int * int
