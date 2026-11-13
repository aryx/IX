(* Ogg: a file of packets, the container of Vorbis, Theora and Opus,
   read here as far as its packets.

   A codec's output is packets, of any size. A file or a stream needs
   them delimited, and a listener who joins in the middle needs a place
   to start. Ogg (Xiph.Org, 2000) cuts the packets into *pages*, each
   of which has:

     "OggS"            where a page starts: what to look for after a
                       loss, or when tuning in
     version, flags    a first page, a last one, a packet continued
     granule position  the time, in the codec's own unit (samples)
     serial, sequence  which stream of the file, which page of it
     a checksum
     a segment table   up to 255 lengths of up to 255 bytes. A packet
                       is the segments up to one shorter than 255 (so
                       a packet of 255 bytes is 255 then 0), and it may
                       go on in the next page

   So a page can be found, checked and skipped without knowing what is
   inside. What is read here is the packets, in order, of a file with
   one stream. The checksum is not checked, and the times are not
   used.

   Reference: RFC 3533, The Ogg Encapsulation Format Version 0 (2003).
   The name comes from a move in the game Netrek, not from Terry
   Pratchett's Nanny Ogg (Vorbis comes from his Small Gods). *)

(* ix: copied from libs/audio/formats/vorbis/Ogg.mli
 * in the author's playground (docs/plans/plan_quake.md). *)

(* a file's packets, in order *)
val packets : string -> string list

(* how many samples a stream of sound has, in each channel: its last
 * page's granule position (the last block decoded gives more, which is
 * the encoder's padding, to be cut) *)
val length : string -> int option
