(* ix: capabilities, erased, for mini-ml (dune's builds take xix's caps
 * library; this directory is not dune's). In that library a function
 * says what it may do by the type of its parameter, an object type such
 * as < Cap.stdout; Cap.open_in; .. >, and the compiler checks it.
 * mini-ml has no objects: every such type is the same type (the "< .. >"
 * of Scope), and the names of its methods are not looked at, as in
 * ocaml-light. So the capabilities are still passed and written in the
 * types, for the reader and for OCaml, but they are not checked here.
 *
 * A capability is a value that a function must hold to act on the
 * world: to print, to open a file, or to start a process. [main] gives
 * them all, once, to the program's main function, which hands down to
 * each function the ones it needs. A function says which ones in the
 * type of its first parameter:
 *
 *     let copy (caps : < Cap.open_in; Cap.stdout; .. >) file =
 *       Console.print caps (FS.read caps file)
 *
 *     let () = Cap.main (fun caps -> copy caps (Fpath.v "notes"))
 *
 *     Cap.main --all_caps--> main --< open_in; stdout; .. >--> copy
 *                              |                    FS.read  (open_in)
 *                              |              Console.print  (stdout)
 *                              |
 *                              `--< fork; exec; wait; .. >--> a child run
 *
 * So a signature tells what a function may do, as an effect would. A
 * function given no capability only computes. A function given
 * < Cap.open_in; .. > may read files, and cannot write one or reach the
 * network, whatever its body becomes later. In the real library each
 * capability is an abstract type that only [main] makes, carried as a
 * method of an object. The two dots are OCaml's row variable, which lets
 * a function that asks for less take an object that has more. A caller
 * can also hand down a weaker object that it made itself (xix's ed, when
 * run restricted, gives its commands an open_in that refuses a name with
 * a slash), or a function alone: mini-datalog's CLI gives Datalog_eval
 * the clock as CapSys.time caps, which reads the time and can do nothing
 * else.
 *
 * This holds only if the code does not go around it, because Stdlib's
 * print_string and Unix's openfile ask for nothing. That part is a
 * convention (the functions of ix that take a capability are in
 * Console, FS, Procs, CapUnix, CapSys and CapStdlib), which xix checks
 * with a Semgrep rule.
 *
 * Where it stands: every program of ix starts with Cap.main in its
 * Main, the assembler as well as the shell. ix is compiled by OCaml and
 * by mini-ml, so what mini-ml does not check here, OCaml has checked.
 *
 * cs-history:
 * The word comes from Jack Dennis and Earl Van Horn (1966). In their
 * design a computation has a list of capabilities, each naming an
 * object and what may be done to it, and the supervisor keeps the list
 * where the computation cannot write. To act on an object, the
 * computation shows an entry of the list. The other way is the access
 * list: the object keeps who may use it, and a program acts with all
 * the rights of the user who runs it. Unix and Plan 9 took the second
 * way for files; kernels were built on the first (Hydra, KeyKOS, and
 * seL4 today).
 *
 * reframe:
 * A file descriptor is a capability. It is a number in a table that the
 * kernel keeps for the process. It names an open file, with the rights
 * the file was opened with; a child inherits it; and read checks no
 * name and no owner again. What is not a capability is open itself,
 * which takes a name from a space that every process sees, and decides
 * by who asks. Capsicum (FreeBSD, 2010) makes a sandbox of that remark:
 * a process that has entered it keeps its descriptors, but can no
 * longer open any global name.
 *
 * terminology:
 * Ambient authority is what a program may do without having been
 * handed anything, because of who runs it, such as open any file of
 * the user. Linux's own "capabilities" (CAP_NET_ADMIN, CAP_SYS_ADMIN...)
 * are something else: they are root's privilege cut in pieces, an
 * attribute of a process, and not a reference that is passed.
 *
 * others:
 * OpenBSD's pledge (2015) is the dynamic and coarse form: a process
 * says once which families of system calls it will still make, and the
 * kernel kills it if it makes another. Here the grain is the function,
 * and the type checker does the check, before the program runs. xix's
 * Cap calls this, after the Scheme papers, "Lambda the ultimate
 * security tool".
 *
 * References: J. B. Dennis and E. C. Van Horn, "Programming
 * Semantics for Multiprogrammed Computations", CACM 9(3), 1966, for the
 * capability and the C-list; R. Watson, J. Anderson, B. Laurie and
 * K. Kennaway, "Capsicum: Practical Capabilities for UNIX", USENIX
 * Security 2010; xix's lib_core Cap.mli, in the library that dune
 * links, which has the full list of capabilities and shows a program
 * restricting its own. *)

(* All the capabilities: the ones main is given. *)
type all_caps = < >

(* Calls f with the program's capabilities. *)
val main : (all_caps -> 'a) -> 'a
