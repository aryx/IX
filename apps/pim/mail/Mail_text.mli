(* Mail_text: a message as the text to read, real mail's (plan_mail.md,
   "What real mail needs").

   Much of what arrives is HTML only, or HTML with a plain part that
   is empty. The plain part is read when it says something; otherwise
   the HTML is made text by the browsers' engine, the Line Mode
   Browser's way (Line_mode: the blocks on lines of their own, each
   link followed by its number), its links listed after:

       Your order has shipped. Track it[1].

       [1] https://shop.example/track/42

   The attachments are said after the text, a line each, with their
   size, so the reader knows they are there (saving them is
   stage 7's). *)

(* the HTML of a page or a part, as lines of 72 characters, the links
   listed after *)
val of_html : string -> string

(* the text to read: the plain parts (Mime.text) when one is not blank,
   else the HTML made text; then the attachments *)
val text : Mail.t -> string
