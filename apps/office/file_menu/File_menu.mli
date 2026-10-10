(* The File menu every application shares: New, Open..., Save, Save
 * As..., Export, and ix's Exit (the program ended at once) -- and the
 * two dialogs behind them (plan_io.md).
 *
 * A document is saved as a value, with appkits/document/Saved:
 * Marshal behind a line naming the application and a version, so that
 * opening a file of another kind, or of an older build, says so
 * rather than crashing. What is saved is the application's *data*
 * ('d): its sheet, its text, its bitmap -- never a part of a compound
 * document, which is a record of functions, only each part's kind and
 * saved text (the registry reads them back).
 *
 * Where it goes is the platforms' store (Store), and the authority to
 * go there is capabilities, [caps] (ix: used, not only said; and
 * Cap.env among them, the store's directory being read in the
 * environment), which the application's main gets
 * from Cap.main and hands to its update: an application that does not
 * is one that cannot save, and its type says so.
 *
 * The menu is immediate mode like the rest of the toolkit: [command]
 * when an item is chosen, and, while a dialog is up ([busy]), [dialog]
 * every frame instead of the application's own input, and [view]
 * under Gui.draw's shapes.
 *
 * A document's way to the disk and back, and who knows what on it:
 *
 *   the application     its data, 'd (mini-office: Document.saved)
 *        | [current ()], asked only when there is something to write
 *   File_menu           the document's name, the dialogs, what to say
 *        | Saved.to_string ~magic       the line, then Marshal's bytes
 *   Store               a name -> bytes: the files of one directory
 *        | FS, through the capabilities
 *   the system          $PLAYGROUND_STORE, or ~/.ix-playground/documents
 *                       on Linux, $home/lib/documents on Plan 9
 *
 * and Open is the same way up: the stored names that end as the
 * kind's do, listed; the one chosen fetched; its line checked and its
 * bytes read (Saved.of_string); [Opened d] given to the application.
 * Export leaves the store: it writes beside where the program was
 * started, for another program to read (mini-office's is a PDF,
 * which mini-page shows).
 *
 * The dialogs are modal with no machinery for it. A dialog up is a
 * value in [t], the application asks [busy] and calls [dialog] where
 * it would have read its own input, and that is all a modal dialog
 * is in immediate mode: an if at the top of the update.
 *
 * (The names above are the playground's: appkits/document/Saved is
 * Saved here.)
 *
 * cs-history:
 * A File menu, the same in every program and in the same place, is
 * the Lisa's and the Macintosh's (1983, 1984), with the dialog that asks
 * for a name: before them each program had its own commands to load
 * and save, VisiCalc's /S, an editor's w. The model under it is
 * older and stranger than it looks: the document one edits is a copy
 * in memory, the file is another, and Save is the moment the first
 * replaces the second.
 *
 * others:
 * Two ways not to have this menu. No Save at all: the document is
 * what is on the screen and is written as it changes, HyperCard's
 * way (1987), the phones' and the web's now, and [autosave] here.
 * And no dialog: on Plan 9 a file is named by text, typed or pointed
 * at, in the editors sam and acme as in the shell, so there is no
 * panel listing files to build, and none was built. mini-office
 * follows the Macintosh on mini-9pi too: it came from the
 * playground whole.
 *
 * References: the playground's apps/office/file_menu and its
 * plan_io.md; Store.mli; Saved.mli. *)

(*****************************************************************************)
(* {1 Setting up} *)
(*****************************************************************************)

type caps = < Cap.env ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.exit >

(* what an application's files are: the line its documents start with
   ("TinyExcel 1" -- the number goes up when the saved type changes),
   and the extension of their names (".sheet") *)
type kind = { magic : string; extension : string }

(* the document's name, if it has one yet; the dialog showing, if any;
   and what the last command did, for a status line *)
type t

val start : t

(*****************************************************************************)
(* {1 The menu} *)
(*****************************************************************************)

(* the menu, its title first *)
val items : string list

(* what the application has to do after a command or a dialog *)
type 'd result =
  | Nothing
  | New
  | Opened of 'd
  (* ix: a file that is no document, by [choose]: its name, its bytes *)
  | Chosen of string * string

(* [command caps kind ~current item t]: File > [item]. Save writes at
   once to the document's name (or asks for one); Open and Save As put
   up their dialog. [current] gives the data to save, asked only when
   saving. *)
val command : caps -> kind -> current:(unit -> 'd) -> string -> t -> t * 'd result

(* ix: [export caps ~extension bytes t]: what an application writes
   for Export when it has a form of its own for other programs to
   read (mini-office: a PDF), in place of [command]'s, which writes
   the document as Save does. The file is the document's name with
   that extension, in the directory the program was started in. *)
val export : caps -> extension:string -> string -> t -> t

(* ix: [choose caps ~extensions t]: the dialog put up that lists the
   stored files whose names end so (".png": a picture to insert), where
   Open lists the application's documents; [dialog] then says the one
   [Chosen], its bytes read and not looked at *)
val choose : caps -> extensions:string list -> t -> t

(* ix: the status line said by the application (a chosen file it
   could not use) *)
val say : string -> t -> t

(* the menu itself, this frame, in a menu bar at [box]: [Gui.menu_in],
   and [command] with what was chosen; [~items] is [items], or a
   menu with fewer of them *)
val menu_in : items:string list -> caps -> kind -> Playground.computer -> Widget.box -> current:(unit -> 'd) -> t -> t * 'd result

(* HyperCard's way, which had no Save: [autosave caps kind ~current t]
   writes the document to its name, if it has one yet -- to be called
   when it has changed *)
val autosave : caps -> kind -> current:(unit -> 'd) -> t -> t

(*****************************************************************************)
(* {1 The dialogs} *)
(*****************************************************************************)

(* is a dialog up? the application's own input waits while it is *)
val busy : t -> bool

(* the dialog, this frame: the name typed (Enter saves, Escape
   cancels), or the documents of this kind listed to open one *)
val dialog : caps -> kind -> Playground.computer -> current:(unit -> 'd) -> t -> t * 'd result

(* the dialog's panel and name field, to draw before Gui.draw () *)
val view : t -> Playground.shape list

(*****************************************************************************)
(* {1 The name and the status line} *)
(*****************************************************************************)

(* the document's name, or "untitled" *)
val title : t -> string

(* what the last command did: "saved budget.sheet, 1204 bytes", "not a
   TinyExcel document", ... *)
val said : t -> string
