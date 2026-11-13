(* Highlight_asm gives the tokens of an assembly file their categories
   (those of Highlight_code), and finds what the file defines and uses,
   for the code map. It reads the assemblers of an old Unix, the AT&T
   syntax of as86 and gas (Linux 0.01's boot.s and system_call.s), and
   Plan 9's.

   It reads line by line, without an assembler's grammar:

   - a comment runs from /* to */, maybe over several lines, or from |, !
     or # to the end of the line (as in as86 and gas);
   - a statement is [label:] [mnemonic or .directive] [operands], and a
     line may have several statements, with ; between them;
   - a label is a definition, which the map takes as a function
     (Def_function); a name defined by = (SIG_CHLD = 17) is a value;
     numeric labels (1:) and the registers are neither;
   - a name in an operand is a use. It is a use of a label of the file
     (an occurrence bound to it), or else of a name defined elsewhere (a
     reference).

   In a.out's convention, C's names have a leading underscore in
   assembly (C's main is _main). So the names of definitions and of
   references lose it, and C's system_call and the assembly's
   _system_call are one name to the map (Code_names treats .s files as
   C files, in the same namespace).

   A worked example, from the tests:

     _system_call:            system_call: Def_function, defined
         call _sys_call_table(,%eax,4)   sys_call_table: a reference
         jmp ret_from_sys_call           bound to the file's label *)

(* In ix, [lines src] is [src] cut into lines, ready to draw: the spans
   that the playground's analyze computes. *)
val lines : string -> Highlight_code.span list array
