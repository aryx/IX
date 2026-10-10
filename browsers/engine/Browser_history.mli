(* Browser_history: Back and Forward, as two stacks -- the pages behind
 * and the pages ahead (notes_browser.md section 9).
 *
 * Visiting a page pushes the current one behind and **empties what was
 * ahead**; Back moves the current one ahead and takes the last one
 * behind; Forward the other way. Worked example (the tests'):
 *
 *   visit A, B, C     behind [B; A]   current C   ahead []
 *   Back              behind [A]      current B   ahead [C]
 *   visit D           behind [B; A]   current D   ahead []    C is gone
 *
 * That last line surprises everyone once, and every browser does it
 * (MMM calls the lost branch "obsolete"; Mothra keeps no Forward, but
 * a list of its last 64 pages). What an entry is -- a URL, the page
 * kept whole, its scroll -- is the browser's: the stacks don't look.
 * Here it is Tab's: each of mini-netscape's tabs has its two stacks.
 *
 * cs-history:
 * The oldest button. Vannevar Bush's memex ("As We May Think", 1945)
 * kept the trail of what its reader had consulted, to go back along
 * it; Mosaic's Back was that trail as a stack. Studies of how people
 * browsed (Catledge and Pitkow, 1995; Tauscher and Greenberg, 1997)
 * found it the most used thing in a browser after the link itself: a
 * third or more of all moves were Back, because the web is read as a
 * hub and its spokes -- a list, an item, back to the list.
 *
 * others:
 * The same two stacks are an editor's undo and redo: a new edit
 * after an undo empties the redo, as a visit empties Forward. An
 * editor that keeps the lost branch has a tree (Emacs's undo is one,
 * flattened); no browser has taken that road for pages. *)

type 'a t = { behind : 'a list; (* the last visited first *) ahead : 'a list }

val empty : 'a t

(* [visit current h]: [current] left for another page *)
val visit : 'a -> 'a t -> 'a t

(* [back current h]: the page to go back to, and the history with
 * [current] ahead; None at the start *)
val back : 'a -> 'a t -> ('a * 'a t) option

(* [forward current h]: the other way *)
val forward : 'a -> 'a t -> ('a * 'a t) option
