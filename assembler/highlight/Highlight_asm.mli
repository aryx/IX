(* Highlight_asm gives the tokens of an assembly file their categories
   (those of Highlight_code), for an editor to colour them. It reads the
   assemblers of an old Unix, the AT&T syntax of as86 and gas (Linux
   0.01's boot.s and system_call.s), and Plan 9's.

   It reads line by line, without an assembler's grammar:

   - a comment runs from /* to */, maybe over several lines, or from |, !
     or # to the end of the line (as in as86 and gas);
   - a statement is [label:] [mnemonic or .directive] [operands], and a
     line may have several statements, with ; between them;
   - a label is a definition (Def_function), and a name defined by =
     (SIG_CHLD = 17) is a constant; numeric labels (1:) and the
     registers are neither;
   - a name in an operand that is one of the file's labels is a Local,
     and one that is one of its constants is a constant.

   The playground's version also finds what the file defines and uses,
   for the code map, and drops a.out's leading underscore so that C's
   system_call and the assembly's _system_call are one name. This one
   leaves both out (Highlight_asm.ml says so). *)

(* [lines src] is [src] cut into lines, ready to draw: each line is a
   list of spans, each with its category. *)
val lines : string -> Highlight_code.span list array
