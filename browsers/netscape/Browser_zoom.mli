(* Browser_zoom is Chrome's page zoom, with Ctrl and + (or =), Ctrl and
 * -, and Ctrl and 0. It goes by Chrome's steps, and each site keeps its
 * own zoom.
 *
 * It is the whole page that grows, not its fonts alone. The browser
 * lays the page out narrower, at the window's width divided by the
 * zoom (so a site's @media rules for a small screen may then hold),
 * and draws it scaled. That part is done by the program (Netscape);
 * this module has the levels and what is remembered.
 *
 *   at 100%, Ctrl +  -> 110%   Ctrl + again -> 125%   Ctrl -  -> 110%
 *   at 500%, Ctrl +  -> 500%   (the last level)
 *   Ctrl 0  -> 100%, and the site is forgotten
 *
 * A zoom belongs to its site (its host) and applies to every page and
 * tab of it, as in Chrome. Chrome keeps it in the profile, and so
 * does Browser_profile here (a "zoom host z" line in preferences).
 *
 * evolution:
 * There were three zooms, in this order. The first browsers could only
 * change the text's size (the "Text Size" of Netscape and Internet
 * Explorer): the letters grew, but the pictures and the widths set in
 * pixels did not, and pages broke. Zooming the whole page came from
 * Opera, then from Internet Explorer 7 (2006) and Firefox 3 (2008): a
 * CSS pixel becomes more than one dot, and the page is laid out again,
 * narrower. That is this module's zoom. The third came with the iPhone
 * (2007), for pages made for a desktop computer: the page is laid out
 * as if on a screen 980 wide and shown small, and two fingers magnify
 * a part without any new layout. The <meta name=viewport> that a page
 * uses to decline that is Safari's, from the same year.
 *
 * https://support.google.com/chrome/answer/96810 *)
(* ix: copied from src/chrome/Browser_zoom.mli in the author's
 * mini-chrome (docs/plans/plan_browser.md) *)

(* The sites zoomed, by host. Those at 100% are not kept. *)
type t = (string * float) list

val empty : t

(* Chrome's levels: 0.25, 0.33, 0.5, ... 1., 1.1, 1.25, ... 5. *)
val levels : float list

(* [step up z] is the level after [z] (or before it, if not [up]). At
 * either end, it is [z]. *)
val step : bool -> float -> float

(* A host's zoom, which is 1. unless it was set. *)
val of_host : t -> string -> float

val with_host : t -> string -> float -> t

(* What a key pressed with Ctrl asks for, given the key's name (SDL's
 * or the web's, in any case) or the character it types:
 * - "=", "+" and "Keypad +" ask for a step up;
 * - "-" and "Keypad -" ask for a step down;
 * - "0" and "Keypad 0" ask for things at their own size again.
 * Any other key gives None. *)
type change = Up | Down | Reset

val key : string -> change option

(* The zoom after a change: one step away, or 1. *)
val apply : change -> float -> float

(* The zoom as "125%", or "" at 100%. *)
val label : float -> string
