(* The builtins: the commands the shell runs itself, because they
 * change the shell (principia's builtins.c).
 *
 *     cd [dir]         chdir; no dir: $home; a relative dir is tried in
 *                      each of $cdpath. Failing: "Can't cd dir: why",
 *                      status can't cd (checked on 9base's rc)
 *     exit [status]    end rc, with this status or $status
 *     . [-i] file args read file's commands, $* set to args; file is
 *                      searched in $path; -i: interactive (a prompt,
 *                      errors don't end it)
 *     eval args        the args joined by spaces, as commands
 *     exec cmd         replace rc with cmd (and exec alone keeps the
 *                      redirections it is given, for rc itself)
 *     shift [n]        drop n words from $*
 *     wait [pid]       for the children started with &
 *     whatis names     how rc would read each back: x=(a b c), fn f
 *                      {...}, builtin cd, /usr/bin/ls, or "x: not found"
 *     flag c [+-]      is -c set (status "" or "flag not set"), set it,
 *                      clear it
 *     rfork, finit     accepted, and nothing on a Unix host (9base: rfork
 *                      e succeeds with an empty status)
 *
 * Why cd must be a builtin, the Principia book's question: chdir
 * changes the directory of the process that calls it, and a cd program
 * would change only its own, and then exit.
 *
 * cs-history:
 * Unix learned it by a bug. On the PDP-7, before fork, the shell ran
 * a command in its own process, and chdir was an ordinary command.
 * Once the shell forked a process for each command, chdir still ran,
 * said nothing, and changed nothing: only the child's directory.
 * Ritchie tells of the puzzlement, and of the fix: the command
 * moved into the shell.
 *
 * design:
 * The test for a builtin is that one question: does it change the
 * shell's own process (its directory, its variables, its input, its
 * life)? Everything else is a program, test and echo included: rc
 * has eleven builtins where bash has some sixty, most of them there
 * for speed.
 *
 * References: Dennis Ritchie, "The Evolution of the Unix Time-sharing
 * System" (AT&T Bell Laboratories Technical Journal, 1984);
 * principia's builtins.c. *)

(* register them in Eval.builtins *)
val init : unit -> unit
