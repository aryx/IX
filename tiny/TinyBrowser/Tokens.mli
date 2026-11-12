(* The HTML tokenizer of TinyBrowser. It turns a page's messages, as
 * they come, into tags and texts, which Html then turns into lines.
 *
 * A message can end anywhere, even in the middle of a tag, of an
 * entity like &amp;, or of a multi-byte UTF-8 character. The reader
 * keeps the unfinished end (its tail) and reads it again in front of
 * the next message:
 *
 *     "<p>Hello <b>wo"   ──►  Open p, Text "Hello "     tail "<b>wo"
 *     "rld</b></p>"      ──►  Open b, Text "world", Close b, Close p
 *
 * Comments, <!DOCTYPE> and <?xml?> are skipped. The content of <style>
 * and <script>, which is not HTML, is skipped up to its end tag. Only
 * the attributes the browser uses are kept, because some can be huge
 * (Parsoid's data-mw can be kilobytes), and their values are made ASCII
 * by Charset.
 *
 * others:
 * The "tokenization" chapter of the HTML standard, a state machine,
 * says everything a tokenizer must accept; this one handles the part
 * that well-formed pages use. The full-size one in ix is mini-chrome's
 * Html_lexer (with its entities in Entities).
 *)

(* A tag's name and its attributes are in lower case. *)
type token =
  | Text of string
  | Open of string * (string * string) list
  | Close of string

(* [tail] is what the last message left unfinished; [raw] the <style> or
 * <script> being skipped; both "" to begin. *)
type reader = { mutable tail : string; mutable raw : string }

(* [tokens_end] gives the tokens of the tail kept at the end *)
val tokens : reader -> string -> token list
val tokens_end : reader -> token list
