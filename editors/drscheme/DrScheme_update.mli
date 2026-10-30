(* DrScheme_update: a frame of mini-drscheme, what happened since the last
   one and to whom it goes.

       update computer m
         | presses: the keys down, made presses
         | who has them?
         |-- the stepper, while it is open         all of them
         |-- the world, while one runs             but Control-B, Break
         '-- the windows
               | the buttons, and Control-T and Control-B
               | the mouse: a window chosen, the caret placed, a selection
               | the keys, into the window that has them
               | the definitions scrolled to the caret
         | work: the program's steps, whoever had the keys
         | this frame's keyboard and mouse kept for the next's comparison

   The last two lines are what makes a program running and a program
   being edited one thing: the machine runs at the end of each frame
   whatever the frame was for, so a key never waits for the program and
   there is no second loop for running.

   The Playground gives the keys that are down, not their presses:

       frames a key is held    1   2 ...  24  25  26  27  28  29  30
       a press                 x                      x           x
                               at once, then, for the keys that move or
                               erase, one every 3 frames after 24

   The two texts are Text_edit's, a piece table that gives undo for
   nothing; the keys change them through [edit], and only the Definitions
   have undo (Control-Z): the prompt is emptied by each Enter, and there
   is little to undo.

   Enter at the prompt is the one place where the keys and the machine
   meet: what was typed in the frame is put in first, it is asked whether
   the expression is whole, and then it is a job on the machine that
   Execute left, the same machine, so it sees the definitions. Whether it
   is whole only the reader can say: read it, and it wants more lines only
   when the reader says "end of input". A line with a mistake in it is
   whole: Enter says the mistake. An edit in the definitions does not touch
   the machine; it puts up DrScheme's warning that what runs is no longer
   what shows, once.

   wib:
   The whole text is made a string again at each key, and its lines are
   cut again, and all that takes as long as the text does, where the
   piece table was made so as not to. It is a window of a beginner's
   programs, a few pages, and it costs no line of code. mini-emacs's
   buffer has to do better: it holds any file. *)

open Playground
open DrScheme_model

val update : computer -> model -> model
