(* A part of a document: something that can be put in a document
 * without the document knowing what it is. A spreadsheet in a letter, a
 * picture in a spreadsheet, a letter in a picture -- the idea of the
 * Andrew Toolkit's "insets" (CMU, 1988), of Microsoft's OLE (1991-93),
 * and of OpenDoc's "parts" (Apple and IBM, 1994-97), where it was the
 * whole architecture: no applications, only documents made of parts,
 * and the part you click on is the editor.
 *
 * All a document needs from a part is a handful of things it can do,
 * so a part is those things -- a record of functions, each closing
 * over the part's own state, whatever that is:
 *
 *   height    how tall I am at this width        the document lays out
 *   draw      myself into this rectangle         the document draws
 *   input     the mouse and keys, when I am      the document hands
 *             active, in this rectangle           them over
 *   menu      my commands, to show while I am    the document's menu
 *   command   active -- and doing one              bar changes
 *   save      myself, as text                    the document saves
 *
 * What COM did with an interface, a registry and reference counts, and
 * a Java component with a class, OCaml does with a record: [input] and
 * [command] return the part changed, a new record closing over the new
 * state, so a part is a value, and a document made of them is a value
 * too -- which is what gives the document its undo for nothing.
 *
 * The one thing a document cannot get from a part is the part itself,
 * back from the text it saved: that needs code for its kind, found by
 * name -- the [registry], OLE's CLSIDs in the Windows registry as an
 * association list. And a kind nobody here knows is not an error:
 * it becomes a [placeholder], which shows what it is, and saves back
 * exactly the text it was loaded from -- the rule that a document must
 * survive passing through a program that cannot read all of it.
 *
 * The smallest part, to see where the state is: a number that a
 * click makes one more. There is no field for the number. It is in
 * the closures, and a click answers with another record, made by
 * the same function over n + 1:
 *
 *   let rec counter n =
 *     { kind = "counter";
 *       draw = (fun box ~active -> the digits of n, in box);
 *       input = (fun computer box ->
 *                  if a click in box then counter (n + 1) else counter n);
 *       save = (fun () -> string_of_int n);
 *       ... }
 *   and its line in a registry:
 *     ("counter", fun text -> counter (int_of_string text))
 *
 * The six parts here are that with more in the closure: Part_text
 * (a Rich), Part_sheet (a Sheet and the cell selected), Part_picture
 * (a Bitmap, the tool, the pattern), Part_drawing, Part_chart,
 * Part_image.
 *
 * What a record of functions costs: two parts cannot be compared, a
 * function having no equality, and a host wants to know whether an
 * editing session changed anything before it records an edit. It
 * compares what they save (Office_edit.put_down). And a part cannot
 * be written by Marshal, hence [save] and the registry (Document's
 * [saved]).
 *
 * Where it stands. Document holds parts, as the body of a sheet,
 * picture or drawing document and as the objects floating on any
 * kind; Office_view calls [draw_in] on each, Office_update gives
 * [input_in] to the one being edited, Office_edit puts its [menu] in
 * the bar. None of the three names a kind of part but to insert one.
 *
 * reframe:
 * A record of functions closing over a state is an object, and the
 * record's type its interface: this is object-oriented programming
 * with nothing but closures. The kernel has the same shape for the
 * same reason. In Plan 9 a device is a table of functions (attach,
 * walk, open, read, write...) found by a letter, the console's, the
 * mouse's, the draw device's, and the kernel that calls read does
 * not know which it is calling. The letter is the [registry]'s
 * name.
 *
 * cs-history:
 * The Xerox Star (1981) already put text, pictures and tables in one
 * document, each edited where it was, but as a fixed set of kinds
 * built into one editor. The Andrew Toolkit opened the set: any
 * inset in any other, and anyone could write a new kind. OLE 2
 * (1993) made the idea known to everyone with in-place activation,
 * the sheet in the Word document and the menus turning into Excel's,
 * while keeping the applications. OpenDoc dropped the applications,
 * and was cancelled in 1997.
 *
 * comeback:
 * The idea then won somewhere else: a web page is made of embedded
 * things its author did not write (a video, a map, each an iframe
 * with its own code, sized by its host and handed the mouse), and a
 * notebook is a document of cells of several kinds. What made it
 * work there is what OpenDoc lacked, one runtime every part's code
 * can count on.
 *
 * References: Andrew Palay and others, "The Andrew Toolkit: An
 * Overview" (USENIX Winter 1988). Kraig Brockschmidt, "Inside OLE"
 * (Microsoft Press, 1993 and 1995). The playground's TinyOpenDoc, a
 * document of parts with no application, and TinyFrameMaker, parts
 * anchored in a text: the two layouts this program's floating
 * objects are neither of (Office says why). *)

type part = {
  (* the name of its kind, which [registry] loads it by *)
  kind : string;
  height : float -> float;
  (* the size its content has, if it has one -- a sheet of so many
     cells, a picture of so many dots -- which a host can scale to the
     room it gives it (see [draw_in]); None for what reflows or fits
     itself to any room (a text, a drawing) *)
  natural : (float * float) option;
  (* [~active]: whether it is the one being edited -- a caret, a
     selection, only show then *)
  draw : Widget.box -> active:bool -> Playground.shape list;
  input : Playground.computer -> Widget.box -> part;
  (* its menu's title, then its items; [] for none *)
  menu : string list;
  command : string -> part;
  save : unit -> string;
}

(* a way to read each kind back: its name, and a loader *)
type registry = (string * (string -> part)) list

(* [load registry ~kind text]: the part [text] was saved from, or a
 * placeholder when no loader is known for [kind] *)
val load : registry -> kind:string -> string -> part

(* a part that cannot be shown here, kept whole *)
val placeholder : kind:string -> string -> part

(* Scaling, the other way to give a part room. When a part's room is
 * not the size its content has, a host can ask the part to live with
 * it -- OpenDoc's frame negotiation, the part insisting on what it
 * needs -- or *scale* it, as OLE did with an embedded object and
 * FrameMaker with an imported graphic: the part draws at its natural
 * size, and the drawing is grouped and scaled, up or down, keeping its
 * proportions, to fit the room. The part never knows: the mouse is
 * mapped back through the same scaling before the part sees it.
 *
 *   natural 300 x 144, room 150 wide:  scale 0.5, drawn 150 x 72
 *
 * [~scaled:false], or a part with no natural size, is the part as it
 * is. *)

(* how tall a part is at a width: scaled, its natural height times the
 * scale that width gives; else its own [height] *)
val fitted_height : scaled:bool -> part -> float -> float

(* the part drawn into a box -- scaled to fit it, against its top-left,
 * if [scaled] *)
val draw_in : scaled:bool -> part -> Widget.box -> active:bool -> Playground.shape list

(* the part given the mouse and keys in a box, the mouse mapped back
 * into its natural size if it is [scaled] *)
val input_in : scaled:bool -> part -> Playground.computer -> Widget.box -> part
