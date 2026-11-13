(* Host_calls.t on the Unix host that runs mini-5i (Linux or macOS,
 * for example). Its calls go through
 * Unix (and the capabilities), and it translates Linux's flags,
 * errnos, signal numbers and wait statuses to and from OCaml's. A
 * guest's file descriptors are mini-5i's own (qemu-user's choice):
 * what the guest opens, mini-5i has open. *)

type caps =
  < Cap.fork; Cap.wait; Cap.chdir; Cap.kill; Cap.open_in; Cap.open_out;
    Cap.clock; Cap.pipe; Cap.env >

val create : caps -> Host_calls.t
