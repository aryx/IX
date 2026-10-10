(* St_boot: from the kernel's text to a running Smalltalk.

   Smalltalk-80 never booted: its image was the world, saved and loaded,
   each one made by the previous one since 1976. Here there is no image
   to start from, so the world is made from the text of its classes
   (St_kernel.mli, kernel/*.st), in four steps:

   1. the classes, empty: an object and a metaclass for every class
      definition in the text, before anything is read -- so that the
      Array, String, Symbol, Character objects made next have their
      classes. nil, true, false, the 256 Characters, the Smalltalk
      dictionary with a global per class;
   2. the classes filled from their definitions (St_class.define_class):
      superclasses, formats, instance variables; the knot at the top
      tied by the same code: Object's metaclass's superclass is Class,
      found as a global, and every metaclass is an instance of
      Metaclass, itself a class whose metaclass is an instance of
      Metaclass;
   3. every method compiled, by the OCaml compiler (St_compile.mli) --
      a Smalltalk compiler would need a running Smalltalk to run it, the
      chicken and the egg every self-hosted language has to break once;
   4. the virtual machine made, and the chunks that are not definitions
      run: from here, everything is Smalltalk.

   A later file may define again a class of an earlier one, with
   other instance variables: the last definition is the class's.

   A mistake in the kernel is an OCaml exception naming its file and
   line.

   Where it stands: CLI and Squeak call [boot] with one of St_kernel's
   lists of files, read by St_chunk; St_image.load_vm is the other way
   to a running system, with no text compiled, and what a host on a
   slow machine starts from (Squeak.resume).

   others:
   The same knot in every system written in itself, and the three
   ways out of it. Keep the last result and start from it: Smalltalk's
   image, a Lisp's core, and a C compiler's binary, which compiles the
   next compiler. Keep a result small enough to carry with the
   sources: OCaml's boot/ocamlc, bytecode in its repository. Or write
   the first one in another language, as here, and as ix's own start
   does (mini-ml compiled by OCaml before it compiles itself). The
   first is the fastest and the hardest to trust: nobody can read an
   image, and what is in it was put there by a program that is in it
   (Ken Thompson, "Reflections on Trusting Trust", 1984).

   modern:
   Pharo, Squeak's fork, builds its image again from its sources at
   each release, by a second Smalltalk that makes the first objects of
   the new one as steps 1 and 2 here do (from memory). *)

exception Error of string

(* a host that throws the Transcript away *)
val quiet_host : St_interp.host

(* the running system: Smalltalk-80, from the Blue Book's kernel
 * (St_kernel.files), or the system of another kernel -- Squeak's,
 * [~kernel:St_kernel.squeak], whose BlockClosure class makes the
 * compiler emit closures for every method, the Blue Book's included *)
val boot : St_interp.host -> (string * string) list -> St_interp.vm

(* a class by name, from the globals *)
val class_named : St_memory.t -> string -> St_memory.oop
