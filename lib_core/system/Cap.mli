(* ix: capabilities, erased, for mini-ml (dune's builds take xix's caps
 * library; this directory is not dune's). There a function says what it
 * may do by its parameter's type, an object's, < Cap.stdout; Cap.open_in;
 * .. >, and the compiler checks it. mini-ml has no objects: every such
 * type is one type (Scope's "< .. >"), its methods' names not looked at,
 * as ocaml-light does. So the capabilities are still passed and written
 * in the types, for the reader and for OCaml, and not checked here.
 *
 * A capability is a value a function must hold to do a thing to the
 * world: to print, to open a file, to start a process. The program's
 * main is given them all, once, by [main], and hands down to each
 * function the ones it needs; a function says which in the type of
 * its first parameter:
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
 * So a signature tells what a function may do, as an effect would: one
 * given no capability computes and nothing else, and one given
 * < Cap.open_in; .. > may read files and cannot write one or reach
 * the network, whatever its body becomes later. In the real library
 * each capability is an abstract type that nothing makes but
 * [main], carried as an object's method; the two dots are OCaml's
 * row variable, by which a function that asks for less takes an
 * object that has more. A caller can also hand down a weaker object
 * made by itself (xix's ed, run restricted, gives its commands an
 * open_in that refuses a name with a slash).
 *
 * It holds only if the code does not go around it: Stdlib's
 * print_string and Unix's openfile ask for nothing. That part is a
 * convention (the functions here that take a capability: Console, FS,
 * Procs, CapUnix, CapSys, CapStdlib), which xix checks with a Semgrep
 * rule.
 *
 * Where it stands: a program of ix starts by Cap.main in its Main,
 * the assembler's as the shell's. ix is compiled by OCaml and by mini-ml, so
 * what mini-ml does not check here OCaml has checked.
 *
 * cs-history:
 * The word is Jack Dennis and Earl Van Horn's (1966): a computation
 * has a list of capabilities, each naming an object and what may be
 * done to it, kept by the supervisor where the computation cannot
 * write; to act on an object is to show an entry of the list. The
 * other way is the access list: the object keeps who may use it, and
 * a program acts with all the rights of the user who runs it. Unix
 * and Plan 9 took the second for files; kernels were built on the
 * first (Hydra, KeyKOS, and seL4 today).
 *
 * reframe:
 * A file descriptor is a capability. It is a number in a table the
 * kernel keeps for the process, it names an open file with the
 * rights it was opened with, a child inherits it, and read checks no
 * name and no owner again. What is not one is open itself, which
 * takes a name from a space every process sees and decides by who
 * asks. Capsicum (FreeBSD, 2010) makes a sandbox of that remark: a
 * process that entered it keeps its descriptors and can open no
 * global name any more.
 *
 * terminology:
 * Ambient authority is what a program may do without having been
 * handed anything, because of who runs it: any file of the user's.
 * Linux's own "capabilities" (CAP_NET_ADMIN, CAP_SYS_ADMIN...) are
 * something else: root's privilege cut in pieces, an attribute of a
 * process, not a reference that is passed.
 *
 * others:
 * OpenBSD's pledge (2015) is the dynamic and coarse form: a process
 * says once which families of system calls it will still make, and
 * the kernel kills it at another. Here the grain is the function,
 * and the check is the type checker's, before the program runs: xix's
 * Cap calls it, after the Scheme papers, "Lambda the ultimate
 * security tool".
 *
 * References: J. B. Dennis and E. C. Van Horn, "Programming
 * Semantics for Multiprogrammed Computations", CACM 9(3), 1966: the
 * capability and the C-list; R. Watson, J. Anderson, B. Laurie and
 * K. Kennaway, "Capsicum: Practical Capabilities for UNIX", USENIX
 * Security 2010; xix's lib_core Cap.mli, the library dune links: the
 * capabilities' full list, and a program restricting its own. *)

(* all of them: main's *)
type all_caps = < >

(* f on the program's capabilities *)
val main : (all_caps -> 'a) -> 'a
