(* The builtins are the commands that the shell runs itself, because
 * they change the shell (principia's builtins.c).
 *
 *     cd [dir]         chdir to dir, or to $home without one; a relative
 *                      dir is tried in each of $cdpath. When it fails:
 *                      "Can't cd dir: why", and the status is can't cd
 *                      (checked on 9base's rc)
 *     exit [status]    end rc, with this status or $status
 *     . [-i] file args read file's commands, with $* set to args; file
 *                      is searched in $path; -i makes it interactive (a
 *                      prompt, and errors do not end it)
 *     eval args        run the args, joined by spaces, as commands
 *     exec cmd         replace rc with cmd (and exec alone keeps the
 *                      redirections it is given, for rc itself)
 *     shift [n]        drop n words from $*
 *     wait [pid]       wait for the children started with &
 *     whatis names     print how rc would read each back: x=(a b c),
 *                      fn f {...}, builtin cd, /usr/bin/ls, or
 *                      "x: not found"
 *     flag c [+-]      tell whether -c is set (the status is "" or "flag
 *                      not set"), or set it, or clear it
 *     rfork, finit     accepted, and they do nothing on a Unix host
 *                      (in 9base, rfork e succeeds with an empty status)
 *
 * Why must cd be a builtin? That is the Principia book's question.
 * chdir changes the directory of the process that calls it, so a cd
 * program would change only its own directory, and then exit.
 *
 * cs-history:
 * Unix learned it through a bug. On the PDP-7, before fork, the shell
 * ran a command in its own process, and chdir was an ordinary
 * command. Once the shell forked a process for each command, chdir
 * still ran and said nothing, but it changed nothing except the
 * child's directory. Ritchie tells of the puzzlement, and of the fix:
 * the command moved into the shell.
 *
 * design:
 * The test for a builtin is that one question: does it change the
 * shell's own process (its directory, its variables, its input, its
 * life)? Everything else is a program, test and echo included. rc
 * has eleven builtins where bash has some sixty, most of them there
 * for speed.
 *
 * References: Dennis Ritchie, "The Evolution of the Unix Time-sharing
 * System" (AT&T Bell Laboratories Technical Journal, 1984);
 * principia's builtins.c. *)

(* register them in Eval.builtins *)
val init : unit -> unit
