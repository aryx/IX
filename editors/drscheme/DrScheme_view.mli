(* DrScheme_view: the window, made from the model at each frame, back to
   front:

       the window's chrome colour
       the Definitions       their text, its shades, the caret
       the divider
       the Interactions      what was said, then the prompt
       the title bar         drawn after the texts: see below
       the toolbar           Step, Execute, Break
       the status line       the language, line:column, running
       a world               over all that, when one runs
       the stepper           over all that, when open

   The Playground has no clipping, so a text that runs past its window is
   hidden by what is drawn after it, the chrome; and a block of the
   Interactions is drawn only when it fits whole. The Interactions keep
   their bottom in view: the height of all that was said is added up, and
   what is over the top is simply left out, so there is no scroll bar and
   no state for one. What was said is a list of blocks, lines in a colour
   or a picture (DrScheme's value printed as itself), each knowing its
   height.

   Nothing remembers what was drawn before: a character is a shape, and
   a new list is made at every frame. What keeps that cheap is after it,
   in the platform (Redraw on mini-9pi: what is the same is not drawn
   again). Turbo_view and mini-emacs's Frame are the same way, in cells. *)

open Playground
open DrScheme_model

val view : computer -> model -> shape list
