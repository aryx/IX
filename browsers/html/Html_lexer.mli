(* Html_lexer: a page's text cut into tokens, which are tags, text, and
   comments.

   The tokenizer is the first stage that knows it is reading HTML.
   Characters go in, and tokens come out (notes_browser.md section 3):

     <p class=intro>Caf&eacute; <a href="menu.html">menu</a>

     Start_tag "p" [class = "intro"]
     Text      "Café "
     Start_tag "a" [href = "menu.html"]
     Text      "menu"
     End_tag   "a"

   Nothing here knows that a <p> cannot hold another <p>, or that </a>
   closes the <a>: that is the tree's business (Html_tree). A token is
   only what the characters say, and where its names come from
   (Dtd.origin). Netscape's extensions added no syntax, only names and
   values, so a start tag is marked when its element is Netscape's, and
   a core element's Netscape attributes are kept apart:

     <font size=+1>   Start_tag "font" [size = "+1"] {Netscape}
     <hr noshade>     Start_tag "hr" [] {Netscape: noshade = ""}

   It is a **state machine**, the WHATWG's (HTML, 13.2.5
   "Tokenization"). It reads a character at a time, and the state says
   what the character means. Here each state is a function and a
   transition is a tail call to the next one, so the machine reads like
   the spec's list:

                     letter            space           letter
     data ---'<'---> tag open ------> tag name -------> attribute name
      ^                |   '/'           |  '>': emit      | '='
      |                |   '!'           v                 v
      |                |    -> markup    data           before value
      |                |       (<!-- comment, <!DOCTYPE)   | '"'  '\''  other
      |                |                                   v
      |                '-- another char: the '<' was text   value (quoted,
      '------------------------------------------------ '>'  or up to a space)

   Here is what makes it HTML's and not a textbook's, each point
   checked by the tests:

   - **A '<' that starts no tag is text**: "a < b", "<3", "< p>". Only
     a '<' followed by a letter, '/', '!' or '?' does anything.
   - **Names are case-insensitive**, and lowercased: <P> is <p>, and
     HREF is href.
   - **There are three ways to quote a value**: "double", 'single', or
     none (up to a space or '>': <td align=center>). There may also be
     no value at all (<hr noshade>, where the value is ""). A name given
     twice keeps its first value.
   - **Entities are decoded** in text and in attribute values
     (Entities.decode): &amp; in an href is an "&".
   - **Some elements' content is not HTML.** Inside <script> and
     <style>, nothing is a tag until the matching end tag (this is
     RAWTEXT: "if (a<b)" is not a tag). <title> and <textarea> are the
     same, but with entities decoded (RCDATA). The tokenizer needs to
     know these names (it is the one place where it knows elements),
     because the tree comes too late to tell it.
   - **Comments** are <!-- ... -->. <!--> and <!---> are empty ones (as
     the spec says), and a comment never closed runs to the end.
     <!DOCTYPE ...> is a token of its own. <? ... > and any other
     <! ... > are "bogus comments", read up to the '>' and kept as
     comments.
   - **A tag cut off by the end of the page is dropped**, as the spec
     says: "<a href=" at the very end is nothing.
   - **Line ends are normalized** first: CR LF and a lone CR become LF.

   Not done are the WHATWG's cases that we treat another way (its
   tokenizer has 80 states, and ours a dozen): character references
   inside RAWTEXT (there are none there, as the spec says, and we
   agree), the "&copy=2" rule for attributes (Entities.mli),
   <plaintext>, CDATA sections (only in SVG and MathML), and the parse
   errors (the spec names each one; we recover the same way, silently).

   cs-history:
   Here is where the rules came from. HTML (Tim Berners-Lee, CERN,
   1990; "HTML Tags", 1991, had eighteen of them) borrowed its angle
   brackets from SGML (ISO 8879, 1986, Charles Goldfarb's Standard
   Generalized Markup Language), by way of the SGML documents that CERN
   already wrote. In theory an HTML page was an SGML document, to be
   read by an SGML parser against a DTD (Dtd.mli). In practice no
   browser ever had one. Mosaic and Netscape read tags with code of
   their own, each differently, and pages were written to whatever
   that code accepted: this was "tag soup". For fifteen years what
   "<a href=x>y" or "<!-- -- >" meant was whatever the browser of the
   day did, and each new browser had to find out by trying the others.
   HTML5 ended that. Ian Hickson (the WHATWG, from 2004) wrote the
   tokenizer down as a state machine of some eighty states, the
   mistakes included, so that every sequence of characters has a
   meaning, the same in every browser; the rules were found by testing
   what the browsers did. Chrome 7 (2010, with WebKit's new parser) and
   Firefox 4 (2011, with Henri Sivonen's) were the first to ship it.
   This module is that machine, with the states that a page of the
   1990s needs.

   Reference: Tim Berners-Lee, "HTML Tags" (1991), the first list; RFC
   1866, "Hypertext Markup Language - 2.0" (Berners-Lee and Connolly,
   1995), HTML as SGML; WHATWG HTML Living Standard, 13.2.5
   "Tokenization" (the
   data, tag open, end tag open, tag name, attribute name and value,
   comment, DOCTYPE, RCDATA and RAWTEXT states); Mothra's rdhtml.c and
   MMM's lexhtml.mll, the same job in C and ocamllex (see
   notes_browser_related_work.md). *)

(* a name (lowercased) and its value (with entities decoded) *)
type attribute = string * string

type token =
  | Doctype of string (* after "<!DOCTYPE", trimmed: "html", "HTML PUBLIC ..." *)
  | Start_tag of {
      name : string;
      attributes : attribute list; (* all of them for a Netscape element *)
      extensions : attribute list; (* the Netscape ones of a core element *)
      origin : Dtd.origin; (* the element's origin *)
      self_closing : bool; (* <br/> *)
    }
  | End_tag of string
  | Text of string (* consecutive text is one token *)
  | Comment of string

(* the tokens of a page's text (in UTF-8, as Charset gives it) *)
val tokenize : string -> token list

(* a token as the notes and the tests write it: Start_tag "p" [class =
 * "intro"], Text "Café\n" (with a newline as \n) *)
val to_string : token -> string

(* the value of an attribute, if the tag has it: attribute "href" attrs *)
val attribute : string -> attribute list -> string option
