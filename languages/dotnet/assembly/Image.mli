(* An assembly's file read: the PE around it, the metadata's heaps and
 * tables, a method's body. The reader of ECMA-335's Partition II; the
 * one module that knows where the bytes are (Writer is its inverse).
 *
 * A .NET assembly is a PE file, Windows's format for its executables,
 * kept on every system: on Linux too `hello.dll` starts with "MZ" and
 * a stub that says "This program cannot be run in DOS mode". The
 * machine's code is not in it (a tiny stub at most); a directory of
 * the PE's header, the 15th, points to the CLI header, which points to
 * the metadata and gives the entry point's token.
 *
 *     hello.dll (4,096 bytes)
 *     0x000  MZ, the DOS stub; at 0x3C the PE header's offset
 *     0x080  "PE\0\0", the COFF header, the optional header and its
 *            16 directories (the 15th: the CLI header)
 *     0x178  the sections: .text (code and metadata), .reloc
 *     0x200  .text:  the CLI header (72 bytes)
 *                    the methods' bodies (headers, IL, clauses)
 *                    the metadata: "BSJB", the version, 5 streams
 *                      #~        the tables: a row count each, the rows
 *                      #Strings  names, NUL-terminated (UTF-8)
 *                      #US       ldstr's strings (UTF-16, a length each)
 *                      #GUID     16 bytes each
 *                      #Blob     signatures, a length each
 *
 * An address in the file is an RVA (relative virtual address: where it
 * would be in memory, the section's place there and not in the file);
 * the sections' table turns it into a file offset.
 *
 * The tables are read whole into arrays of ints, a row an array of its
 * columns (Metadata's shapes): 1-based like the tokens, row 0 unused.
 * Microsoft's System.Private.CoreLib.dll (13 MB, 2,466 types, 33,768
 * methods) is read in under a second.
 *
 * modern:
 * The PE format is from Windows NT (1993); .NET (2002) put its own
 * world inside it so that Windows's loader would start a .NET program
 * as any other, the stub then calling the runtime (mscoree.dll's
 * _CorExeMain). On Linux and macOS the `dotnet` host reads the same
 * file and ignores the stub: the format stayed for that compatibility,
 * not for its own merits.
 *
 * References: ECMA-335, Partition II, 24 (the metadata's physical
 * layout), 25 (the PE file); Microsoft's "PE Format" page. *)

type t = {
  file : string;          (* the whole file's bytes *)
  sections : (int * int * int * int) list;
    (* (rva, virtual size, file offset, raw size) a section *)
  entry_point : int;      (* a MethodDef's token, 0 for a library *)
  version : string;       (* the metadata's: "v4.0.30319" *)
  strings : int;          (* the heaps' offsets in [file], and their sizes *)
  user_strings : int;
  blobs : int;
  guids : int;
  blobs_size : int;
  rows : int array;       (* each table's count of rows *)
  tables : int array array array;
    (* tables.(t).(row).(column), row from 1 *)
}

exception Bad_image of string

(* a file's bytes read: Bad_image if not an assembly *)
val read : string -> t

(* an RVA's offset in the file *)
val offset : t -> int -> int

(* the heaps: a name (#Strings), a user's string (#US, decoded from UTF-16:
 * a character above 255 is kept as UTF-8), a blob's bytes, a GUID's *)
val string : t -> int -> string
val user_string : t -> int -> string
val blob : t -> int -> string
val guid : t -> int -> string

(* a row's column, by its name (Metadata.col) *)
val get : t -> int -> int -> string -> int
(* a coded index decoded: (its table, its row); the table -1 for row 0 *)
val decode : Metadata.coded -> int -> int * int

(* the rows [first, last] of a range column: a type's fields
 * (FieldList), its methods (MethodList), a method's parameters
 * (ParamList), each until the next row's first or the table's end *)
val range : t -> int -> int -> string -> int -> int * int

(* a method's body, at its RVA *)
type clause = {
  kind : int;             (* 0 catch, 1 filter, 2 finally, 4 fault *)
  try_start : int;
  try_end : int;          (* offsets in the IL, the end excluded *)
  handler_start : int;
  handler_end : int;
  class_token : int;      (* the type caught; a filter's offset for 1 *)
}
type body = {
  max_stack : int;
  locals_token : int;     (* a StandAloneSig, 0 for none *)
  init_locals : bool;
  code : string;          (* the IL *)
  clauses : clause list;
}
val body : t -> int -> body
