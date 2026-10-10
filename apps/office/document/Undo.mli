(* The versions you can go back to, and forward to again.
 *
 *   record c on [b; a]   ->  now c, past [b; a], future []
 *   undo                 ->  now b, past [a],    future [c]
 *   undo                 ->  now a, past [],     future [b; c]
 *   record d             ->  now d, past [a],    future []      <- c and b
 *                                                                  are gone
 *
 * In a language where a state is a value, undo is *keeping the old
 * ones*, and this module is a list and its mirror. That is worth
 * saying because the famous answer is the other one: the **command
 * pattern** (the Gang of Four's, 1994 -- and Smalltalk's before
 * them), where a program that changes its state in place records what
 * each change *did* and how to put it back. Every undo bug anybody
 * has ever had is in that "how to put it back": the inverse of an
 * edit is easy to write and easy to write wrong, and it has to stay
 * right as the program grows. Here there is no inverse to write.
 *
 * The two costs, since nothing is free: a version is kept whole, so
 * the memory is the sum of the versions (which is why [start ~limit]
 * caps them, as every editor does), and it only works while the
 * states really are values -- share a mutable array between two of
 * them and undo will go back to a version that has been changed
 * behind its back.
 *
 * In this repository there are three of these, and the differences
 * are the interesting part:
 *
 *   gamekits/puzzle/Undo     a game's: one way, no redo, no names. A
 *                        Sokoban player wants the move before, and
 *                        never a menu
 *   gui/Text_edit        a text's own, over its pieces: the same idea
 *                        specialised, so that a version costs a list
 *                        of pieces rather than a copy of the text
 *   this one             an application's: any value, both ways, with
 *                        a name per edit, because a menu says "Undo
 *                        Add Circle" and an editor's whole document
 *                        is the state
 *
 * (That is the playground. In ix the first is not here, the second
 * is lib_gui's Text_edit, and this one has two users: the examples'
 * Gui7Circles and mini-office, whose history is a
 * [Document.doc Undo.t] of at most 100 versions, in Office_model.)
 *
 * What an edit is, is the caller's to say, and it is the real
 * question of an undo: one press of Undo should take back what the
 * person thinks of as one thing. mini-office has three answers, all
 * made of [record] and [amend] (Office_edit, Office_update):
 *
 *   a run of typing     the first key records "Typing", the next ones
 *                       amend it, until the caret is moved: Undo takes
 *                       the word back, not its last letter
 *   a drag              the document being dragged is kept beside the
 *                       history, not in it; the release records one
 *                       "Move" or "Resize", or nothing if nothing moved
 *   an object edited    the same, until it is put down: one "Edit
 *   in place            Object", if what its parts save has changed
 *
 * and what is no edit at all (the caret moved, the pages scrolled, the
 * slide shown) is [amend]: it changes the version, it does not make
 * one. So Undo also puts the caret back where it was at that version.
 *
 * Keeping versions whole costs less than it sounds. A version is not
 * a copy: a document changed is a new record that points to
 * everything the change did not touch, the other objects, the other
 * slides, and a text's buffers (Text_edit's are shared by all its
 * versions). A hundred versions of a ten-page document are ten pages
 * and a hundred small records. The name for values made this way is
 * persistent data structures.
 *
 * others:
 * [record] forgets the future, as nearly every editor does. Two that
 * do not: in Emacs an undo is itself an edit, recorded like any
 * other, so undoing the undos brings back what a new edit would have
 * lost, at the price of a history nobody can picture; Vim (since
 * version 7) keeps the tree, each version with its branches, and
 * commands to walk it. A version control system is the same tree
 * with names on it.
 *
 * cs-history:
 * The first Macintosh programs (1984) had Undo in the Edit menu of
 * every one of them, and one level of it: Undo again undid the undo.
 * That menu is why people expect it everywhere. Unlimited undo with
 * a redo, as here, came with the memory to keep it. Earlier still,
 * Warren Teitelman's BBN-LISP, the later Interlisp, had an UNDO for
 * the commands typed to it, by 1971.
 *
 * modern:
 * The same list, in programs that are not editors: with the state of
 * a whole application one value and every change through one update
 * function (Mvu.mli), keeping the old states gives a debugger that
 * goes back in time, Elm's and Redux's. The playground's Inspect
 * scrubs a game that way.
 *
 * References: James Driscoll, Neil Sarnak, Daniel Sleator and Robert
 * Tarjan, "Making Data Structures Persistent" (1986), for versions
 * that share. Erich Gamma, Richard Helm, Ralph Johnson and John
 * Vlissides, "Design Patterns" (1994), Command, for the other way.
 *)

type 'a t

(* [start ~limit v]: a history holding [v], with nothing behind it.
 * [limit] is how many versions to keep (the playground's default: 100): the oldest
 * are forgotten, which is what makes an editor's memory bounded. *)
val start : limit:int -> 'a -> 'a t

val now : 'a t -> 'a

(* [record ~name v t]: [v] is the state now. [name] says what the edit
 * was, for the menu that offers to undo it. Recording makes the
 * future unreachable -- the branch you did not take is gone, in this
 * as in every editor that is not a version control system. *)
val record : name:string option -> 'a -> 'a t -> 'a t

(* [amend v t]: [v] is the state now, *without* a new version -- for
 * what changes the state but is not an edit: the selection moving,
 * or the second keystroke of a word being typed, which should be
 * undone together with the first. *)
val amend : 'a -> 'a t -> 'a t

val undo : 'a t -> 'a t
val redo : 'a t -> 'a t
val can_undo : 'a t -> bool
val can_redo : 'a t -> bool

(* what the menu says: the name of the edit that undo would take back,
 * and of the one redo would put back *)
val undo_name : 'a t -> string option
val redo_name : 'a t -> string option

(* how many versions are behind and ahead *)
val undos : 'a t -> int
val redos : 'a t -> int
