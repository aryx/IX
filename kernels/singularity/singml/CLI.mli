(* mini-singml: what mini-singularity (kernels/singularity) asks of the
 * language beyond mini-ml, as a program of its own over mini-ml's
 * parser: nothing of it is in languages/ml. A contract's declaration
 * made its module, in OCaml, which mini-ml then compiles (Description,
 * Output); a program's source refused if it is not safe (Safe). Its usage:
 * [help] in CLI.ml, what mini-singml -h prints.
 *
 * Its three jobs, each a file in OCaml's syntax read by mini-ml's
 * parser (no grammar of its own) and given another meaning:
 *
 *     Intro.contract --> Description --> Output --> Intro.ml,
 *       (types: the       a Contract.t              Intro.mli: an
 *        messages; a let                            end a type, an
 *        rec: the states)                           operation a
 *                                                   message
 *     Main.ml -------> Safe ----------> nothing, or  file:line: why
 *       (a program's)                   and the build stops
 *     Main.manifest --> Manifest -----> Given.ml (the program's
 *                                       resources, by name) and the
 *                                       kernel's list of grants
 *
 * Where it stands: it runs on the host when the image is built,
 * before mini-ml compiles a program, and is the only thing between
 * a program's text and the kernel's address space. Everything
 * Singularity did in a compiler and a verifier of its own is here
 * 600 lines over another compiler's front end, with the loss the
 * modules say (Safe.mli, Description.mli).
 *
 * design:
 * A small language inside a big one's syntax. A contract is
 * written as OCaml that would not type (send Ready; serve), read
 * as a tree and interpreted by its shape: no lexer, no parser, no
 * new rules of precedence to learn, and an editor colours it. The
 * cost is that what is allowed is a subset to document
 * (Description.mli's table), and errors must be said in the
 * contract's words, not OCaml's. Sing# went the other way, a
 * compiler extended; OCaml's own ppx rewriters are this way made a
 * mechanism. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
