(* Mailto: reading a mailto: address (RFC 6068, 2010; before it, RFC
   1738, 1994), which is what a page's "write to us" link says:

       mailto:alice@ix,bob@ix?cc=carol@ix&subject=lunch%3F&body=See%20you
              ~~~~~~~~~~~~~~~  ~~~~~~~~~~~  ~~~~~~~~~~~~~  ~~~~~~~~~~~~~~
              to (by commas)   cc, bcc, to   %XX decoded   CR LF: lines

   A '+' is a plus (alice+news@ix), not a space as in a form's fields
   (Urlencoded). It is read by mini-netscape (for a link's status line:
   "mail to alice@ix") and by mini-pim (to fill its composer: the
   write= of pim(1)). That is the reason this file is here and not in
   mini-pim's mail.

   cs-history:
   mailto: came with the first URLs (RFC 1738, Berners-Lee, 1994).
   Mosaic and Netscape opened their own mail window on it, and Netscape
   2.0's Messenger (1995) put a whole mail program behind it. *)

type t = {
  to_ : string list;
  cc : string list;
  bcc : string list;
  subject : string;
  body : string; (* its lines ended by LF *)
}

(* None for an address that is not mailto: *)
val parse : string -> t option
