(* The HTML tokenizer of TinyBrowser: a page's messages, as they come,
 * to its tags and its texts, which TinyBrowserPage turns into lines.
 *
 * A message can end anywhere, even in the middle of a tag, of an
 * entity like &amp;, or of a multi-byte UTF-8 character. The reader
 * keeps the unfinished end (its tail) and reads it again in front of
 * the next message:
 *
 *     "<p>Hello <b>wo"   ──►  Open p, Text "Hello "     tail "<b>wo"
 *     "rld</b></p>"      ──►  Open b, Text "world", Close b, Close p
 *
 * Comments, <!DOCTYPE> and <?xml?> are skipped; the content of <style>
 * and <script>, which is not HTML, is skipped to its end tag; of the
 * attributes only those the browser uses are kept (Parsoid's data-mw
 * can be kilobytes), their values made ASCII by TinyBrowserText.
 *
 * others:
 * the "tokenization" chapter of the HTML standard, a state machine,
 * says everything a tokenizer must accept; this one handles the part
 * that well-formed pages use. The full-size one in ix is mini-chrome's
 * Html_lexer (its entities in Entities).
 *)

(* A tag's name and its attributes are in lower case. *)
type token =
  | Text of string
  | Open of string * (string * string) list
  | Close of string

(* What the last message left unfinished (tail), and, while we skip the
 * content of a <style> or <script>, the name of that element (raw);
 * both "" to begin. *)
type reader = { mutable tail : string; mutable raw : string }

(* [tokens reader message last]: the tokens of a message. [last] is
 * true when no message follows, so nothing is kept for later. *)
val tokens : reader -> string -> bool -> token list
