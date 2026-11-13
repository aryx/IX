(* Dom: a page as a tree of elements, with attributes and children, and
   of text.

   The Document Object Model is what the rest of a browser works on.
   The looks are computed on it, the layout walks it, a click finds its
   way back to it (and, in browsers with scripts, JavaScript changes
   it). Html_tree builds it from the tokens. Nothing here knows HTML's
   rules, only the shape:

     html                       the root, always there (Html_tree
      +- head                    makes the three of them even when the
      |   +- title               page wrote none)
      |       +- "Lunch"
      +- body
          +- h1
          |   +- "Menu"
          +- p
              +- "Soup of the day"

   An element keeps **where it comes from** (Dtd.origin): HTML 2.0's
   core, or Netscape's extensions. An extension is either an element of
   its own (<font>), or an attribute that Netscape gave to a core
   element (<body bgcolor=silver>), which is kept apart from the core's
   attributes. So code reading HTML 2.0 sees HTML 2.0, and asks for the
   rest by name ([attribute_any]).

   The real DOM has more kinds of node (the document itself, comments,
   the doctype, processing instructions), and each node knows its
   parent. Ours keeps only elements and text, and it is a value: it is
   built once, then only read, so a node's parent is where you came
   from.

   In the system, the tree is the one value that every stage after the
   parser reads. Line_mode prints it; Computed gives each of its
   elements a style; Box_layout walks it into lines and boxes, and Hit
   goes from a point back to one of its elements; Forms reads a form's
   controls in it. A page's scripts want a tree
   they can change, with parents. webapi's Shadow_tree is that tree: it
   is made from this one, and made back into this one when a script
   has changed it.

   cs-history:
   The name is a standard's. When scripts came to pages, each browser
   gave them its own view of the page. Netscape 2 and 3 (both 1996)
   gave only the forms, images and links ("DOM Level 0", named
   afterwards). Then, for "Dynamic HTML" (1997), Netscape 4 gave its
   layers and Internet Explorer 4 gave document.all, every element.
   These were two incompatible models, and pages were written twice.
   The W3C's Document Object Model (Level 1, October 1998) is the one
   tree that both agreed on, defined apart from any language: nodes,
   with a parent, children and attributes. Levels 2 (2000) and 3 (2004)
   added events, styles and ranges; it is now a living standard of the
   WHATWG's. Here it is the tree alone, as an OCaml value; what a
   script sees of it is webapi's business.

   Reference: W3C, "Document Object Model (DOM) Level 1 Specification"
   (1998); WHATWG, "DOM Living Standard", section 4 (nodes, trees);
   notes_browser.md section 4. *)

type node = Element of element | Text of string

and element = {
  name : string; (* lowercased: "p" *)
  attributes : (string * string) list; (* all of them for a Netscape element *)
  extensions : (string * string) list; (* the Netscape ones of a core element *)
  origin : Dtd.origin; (* the element's origin *)
  children : node list;
}

(* an element of this name, from the core, without attributes or, for
 * element_with, with these (core) ones (ix: these are two functions,
 * where the attributes were optional) *)
val element : string -> node list -> element
val element_with : (string * string) list -> string -> node list -> element

(* the value of an attribute: a core one or, for attribute_any, one of
 * Netscape's too (ix: it was ~extensions:true) *)
val attribute : string -> element -> string option
val attribute_any : string -> element -> string option

(* ix: from mini-chrome's later Dom, for a page's scripts
 * (browsers/webapi). comment_name is the name of the element that a
 * comment becomes, in a tree that keeps comments (its one child is the
 * comment's text); hash is a hash that reads little of the element. *)
val comment_name : string
val hash : element -> int

(* the elements of this name, in document order, [root] included *)
val find_all : string -> element -> element list

(* the text inside, in document order, concatenated *)
val text_content : element -> string

(* the tree without the text nodes that are only spaces and newlines
 * (the source's indentation, which layout ignores). This is what a
 * person reading the tree wants, and the tests' way to write it. *)
val without_blank_text : element -> element

(* the tree as indented lines, two spaces for each level. An element is
 * written [name attr="value"] (Netscape's are marked: [font size="+1"
 * {Netscape}], [hr {Netscape: noshade=""}]), and a text is quoted, with
 * its newlines as \n:
 *
 *   html
 *     head
 *       title
 *         "Lunch"
 *)
val to_lines : element -> string list
