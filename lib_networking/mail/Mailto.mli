(* Mailto: a mailto: address read (RFC 6068, 2010; RFC 1738's, 1994,
   before it), what a page's "write to us" link says:

       mailto:alice@ix,bob@ix?cc=carol@ix&subject=lunch%3F&body=See%20you
              ~~~~~~~~~~~~~~~  ~~~~~~~~~~~  ~~~~~~~~~~~~~  ~~~~~~~~~~~~~~
              to (by commas)   cc, bcc, to   %XX decoded   CR LF: lines

   A '+' is a plus (alice+news@ix), not a space as in a form's fields
   (Urlencoded). Read by mini-netscape (a link's status line: "mail to
   alice@ix") and mini-pim (its composer filled: pim(1)'s write=), the
   reason this file is here and not in mini-pim's mail.

   cs-history:
   mailto: came with the first URLs (RFC 1738, Berners-Lee, 1994):
   Mosaic and Netscape opened their own mail window on it, Netscape
   2.0's Messenger (1995) a whole mail program behind it. *)

type t = {
  to_ : string list;
  cc : string list;
  bcc : string list;
  subject : string;
  body : string; (* its lines ended by LF *)
}

(* None for an address that is not mailto: *)
val parse : string -> t option
