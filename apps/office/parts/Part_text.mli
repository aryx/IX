(* A text with looks, as a part of a compound document (appkit_embed):
 * TinyWord's engine (Rich, Page, Stroke_text) behind the four
 * functions a document asks of a part. Active, it takes clicks, drags,
 * typing, and its Text menu; inactive, it is only drawn.
 *
 * A frame of it: the text is laid out at the box's width (Page, with
 * Stroke_text's widths), a press puts the caret where Page.offset_at
 * says, a drag extends the selection, a key is typed at the caret in
 * the look Rich gives it; Control with b, i or u is the menu's Bold,
 * Italic, Underline. Its height is the laid-out text's, so a text
 * box grows down as it is typed in, and it has no natural size: made
 * narrower, it breaks its lines again and is never scaled.
 *
 * What it saves, which a person can read: how many runs, a line for
 * each (its length in bytes, bold italic underline strike as four
 * digits, the size), then the characters. "The quick", the second
 * word bold:
 *
 *   2
 *   4 0000 16
 *   5 1000 16
 *   The quick
 *
 * cs-history:
 * A key typed is a letter, wherever the caret is: that had to be
 * invented. Bravo (1974) was modal, as vi still is: the keys were
 * commands until one of them said that text followed. Larry Tesler
 * and Tim Mott's Gypsy (Xerox PARC, 1975) removed the modes: a
 * caret put down by a click, typing always inserting there, and cut,
 * copy and paste to move text, which are Gypsy's too. Word and the
 * Macintosh took it whole, and this part is that editor. (The
 * playground's TinyBravo is the modal one, on the same Rich, to try
 * the difference.) *)

val kind : string

(* [make rich]: the part, showing [rich] *)
val make : Rich.t -> Component.part

(* read back from its save: the looks first, then the characters *)
val load : string -> Component.part
