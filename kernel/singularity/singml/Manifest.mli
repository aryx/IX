(* mini-singml: a program's manifest read (decision 5 of
 * kernel/singularity's plan_system_singularity.md): what it needs of
 * the machine, which the kernel gives it at its start and no more. A
 * manifest is a file in OCaml's syntax beside the program's Main.ml,
 * Main.manifest, a name a resource:
 *
 *   let uart = registers 0x201000 0x1000    a device's registers: where
 *                                           among the peripherals', how many bytes
 *   let keys = interrupt 57                 an interrupt, by its number
 *
 * From it, two texts: the program's module Given, where each name is
 * the resource (a Sip.registers, a Sip.interrupt), with the endpoints
 * its parent gave it; and the kernel's list of what to give. *)

type resource =
  | Registers of int * int
  | Interrupt of int

(* the line, the message *)
exception Error of int * string

(* a manifest's resources, each with its name, in order ([] for no manifest) *)
val read : Ast.structure -> (string * resource) list

(* Given's two files' text; source is the manifest's file, named in their first line *)
val ml : string -> (string * resource) list -> string
val mli : string -> (string * resource) list -> string
(* the kernel's: an OCaml list of Programs.grant *)
val grants : (string * resource) list -> string
