(* Pdf_filter gives back a stream's bytes as they were before the file
   was made smaller, or made of plain characters.

   A stream names its filters, which are undone in order:

     /FlateDecode      zlib's Deflate (ix's Zlib.inflate), used by
                       nearly every stream of today's files
     /LZWDecode        Welch's LZW, the first compression PDF had
     /ASCII85Decode    four bytes written as five printable characters,
     /ASCIIHexDecode   and z for four zeros. Both date from when a file
                       had to go through seven-bit electronic mail
     /RunLengthDecode  a count, then bytes to copy or one to repeat
     /DCTDecode        JPEG, a picture's own filter, left as it is for
                       the picture's reader (Pdf_image)

   Flate and LZW may come with a *predictor*: each row of a picture
   (or of the table of objects) is stored as its difference from its
   neighbours, in one of PNG's five ways (a byte before each row says
   which) or in TIFF's way, so that the compression sees runs of
   zeros.

   "87cURD]i,\"Ebo80~>" in ASCII85 is "Hello World!" (~> ends it).

   cs-history:
   LZW was the one general compression of PDF 1.0 (1993). Unisys
   held a patent on it and asked for royalties from 1994; PDF 1.2
   (1996) added Flate, which was free, and LZW has not been written
   since. The same quarrel made PNG (Png.mli).

   Where it stands in ix: Pdf calls it when an object's stream is
   asked for, and it calls Zlib (lib_compression). The LZW here is
   written out again and is not Lzw's, because PDF's codes have the
   most significant bit first and widen a code early, where GIF's
   (Gif.mli) have the least significant bit first. The PNG predictors
   are Png's five filters, undone a second time in a few lines, since
   a row of a stream is not a picture. Files whose Flate stream has a
   wrong header or checksum are common enough that, for them, the
   blocks are read alone (Zlib.inflate_blocks).

   design:
   The filters are a pipe of small reversible steps, named in the
   file. Each filter does one thing (make it text, make it small, make
   it differences), and a stream lists the ones it went through. So a
   reader undoes them in turn with no knowledge of what the bytes are,
   and a new compression is one more name. HTTP's Content-Encoding and
   a .tar.gz file's two endings are the same design.

   Reference: ISO 32000-1:2008, section 7.4. *)
(* ix: from mini-chrome's libs/pdf/Pdf_filter.mli. lzw's early is given
 * explicitly, where it was optional with 1 as default
 * (docs/plans/done/plan_pdf.md) *)

(* [decode resolve dictionary bytes] gives the bytes with the stream's
 * filters undone, as far as this module knows them, and the first
 * filter that it does not know (a picture's own: "DCTDecode",
 * "JPXDecode", "CCITTFaxDecode"), if there is one. [resolve] follows
 * references *)
val decode : (Pdf_object.t -> Pdf_object.t) -> Pdf_object.dict -> string -> string * string option

val ascii85 : string -> string
val ascii_hex : string -> string
val run_length : string -> string

(* [early] (1 unless the stream says otherwise) is how many codes early
 * the code's width grows *)
val lzw : early:int -> string -> string
