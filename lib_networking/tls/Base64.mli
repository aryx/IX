(* Base64: bytes written as ordinary characters.

   A PNG is bytes, and bytes are awkward to carry around in text: in a
   source file, in a URL, in an e-mail. Base64 is the usual answer. It
   takes the bits 6 at a time instead of 8, and writes each group as
   one of 64 characters, A-Z a-z 0-9 + / :

       3 bytes                24 bits                4 characters
       +--------+--------+--------+
       |01001101|01100001|01101110|     "Man", the example of
       +--------+--------+--------+     Wikipedia's article and
       |010011|010110|000101|101110|    of many since
       +------+------+------+------+
          19     22      5      46
          T      W       F      u       -> "TWFu"

   3 bytes go in and 4 characters come out: the text is a third bigger,
   which is worth it when what carries it only takes text. If the last
   group is short, it is padded with '=' (one or two).

   Here it is what lets a texture live inside the program. A dune rule
   turns minecraft.png into an OCaml string of base64 (as
   graphics/font/dune does for the Hershey font). The game hands that
   string to Playground3d.embedded_texture, and the backends turn it
   back into pixels: with [decode] here for the backends that decode
   images themselves, and with the browser's own "data:" URL for the
   WebGL one, which wants exactly this encoding. The WebSocket
   handshake (Websocket.mli) also answers a key with the base64 of a
   SHA-1. The module is pure, and in core/, so that everything can
   reach it, natively and in a browser.

   (ix: the paragraph above is the playground's, where the module was
   written. Here it has two callers. One is Pem, for the certificates
   between their BEGIN and END lines, which is why it sits with TLS.
   The other is the browser's engine, for a "data:" URL whose payload
   says ";base64", which is a picture inside the page's own text.)

   The padding, on the same example cut short:

       "Man"   4d 61 6e    TWFu
       "Ma"    4d 61       TWE=     16 bits: two groups and 4 bits, 0000 added
       "M"     4d          TQ==      8 bits: one group and 2 bits

   So the number of '=' says how many bytes the last group of four
   holds, and a decoder may also do without them, as [decode] does.

   cs-history:
   Mail was made for seven-bit text, for lines of limited length, and
   for gateways that changed what they did not like. Unix's uuencode
   (1980) was the first common way to send a file through it, but its
   64 characters included the space and punctuation that some gateways
   altered. Privacy-Enhanced Mail chose this alphabet in 1987 (RFC 989;
   Pem.mli), as the characters that every character set had, and MIME
   (1992) took it for attachments. From there it went everywhere that
   a protocol speaking text must carry bytes: an HTTP password, a
   certificate, a picture in a URL, a token in a cookie (with - and _
   for + and /, which mean something in a URL).

   Reference: RFC 4648, "The Base16, Base32, and Base64 Data
   Encodings" (Simon Josefsson, 2006). *)

(* [decode s] is the bytes that [s] stands for. Padding ('='), spaces
 * and newlines are ignored, so a string cut into lines decodes the
 * same. Any other character is skipped too, rather than raising,
 * because the strings this decodes are generated, not typed. *)
val decode : string -> string

(* [encode s] is [s] as base64, with no line breaks. (The build-time
 * generator has its own copy, since it runs before this library is
 * built; this one is here for the tests, and for symmetry.) *)
val encode : string -> string
