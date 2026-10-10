(* Pdf_filter: a stream's bytes as they were before the file was made
   smaller, or made of plain characters.

   A stream names its filters, to undo in order:

     /FlateDecode      zlib's Deflate (ix's Zlib.inflate): nearly every
                       stream of a file of today
     /LZWDecode        Welch's LZW, the first compression PDF had
     /ASCII85Decode    four bytes as five printable characters; z is
     /ASCIIHexDecode   four zeros. From when a file had to go through
                       electronic mail of seven bits
     /RunLengthDecode  a count, then bytes to copy or one to repeat
     /DCTDecode        JPEG: a picture's own, left as it is for the
                       picture's reader (Pdf_image)

   Flate and LZW may come with a *predictor*: each row of a picture
   (or of the table of objects) stored as its difference from its
   neighbours, PNG's five ways (a byte before each row says which) or
   TIFF's -- so that the compression sees runs of zeros.

   "87cURD]i,\"Ebo80~>" in ASCII85 is "Hello World!" (~> ends it).

   cs-history:
   LZW was all PDF 1.0 had (1993). Unisys held a patent on it and
   asked for royalties from 1994; PDF 1.2 (1996) added Flate, free,
   and LZW has not been written since. The same quarrel that made PNG
   (Png.mli).

   Where it stands in ix: called by Pdf when an object's stream is
   asked for, and under it Zlib (lib_compression). The LZW here is
   written out again and is not Lzw's: PDF's codes have the most
   significant bit first and widen a code early, GIF's (Gif.mli) the
   least significant first. The PNG predictors are Png's five
   filters, undone a second time in a few lines, a row of a stream
   being no picture. A file whose Flate stream has a wrong header or
   checksum is common enough that the blocks are then read alone
   (Zlib.inflate_blocks).

   design:
   A pipe of small reversible steps, named in the file. Each filter
   does one thing (make it text, make it small, make it differences)
   and a stream lists the ones it went through, so a reader undoes
   them in turn with no knowledge of what the bytes are; a new
   compression is one more name. HTTP's Content-Encoding and a
   .tar.gz file's two endings are the same design.

   Reference: ISO 32000-1:2008, section 7.4. *)
(* ix: mini-chrome's libs/pdf/Pdf_filter.mli; lzw's early is said, where it was optional (1) (docs/plans/plan_pdf.md) *)

(* [decode resolve dictionary bytes]: the bytes with the stream's
 * filters undone, as far as they are ours; the first filter that is
 * not (a picture's own: "DCTDecode", "JPXDecode", "CCITTFaxDecode"),
 * if it has one. [resolve] follows references *)
val decode : (Pdf_object.t -> Pdf_object.t) -> Pdf_object.dict -> string -> string * string option

val ascii85 : string -> string
val ascii_hex : string -> string
val run_length : string -> string

(* [early] (1 unless the stream says): the code's width grows one code early *)
val lzw : early:int -> string -> string
