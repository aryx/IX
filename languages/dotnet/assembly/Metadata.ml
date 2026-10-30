(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Metadata.mli *)

type column =
  | U8
  | U16
  | U32
  | String
  | Guid
  | Blob
  | Table of int
  | Coded of coded

and coded = { cname : string; bits : int; tables : int array }

let t_module = 0x00
let t_type_ref = 0x01
let t_type_def = 0x02
let t_field = 0x04
let t_method_def = 0x06
let t_param = 0x08
let t_interface_impl = 0x09
let t_member_ref = 0x0A
let t_constant = 0x0B
let t_custom_attribute = 0x0C
let t_class_layout = 0x0F
let t_stand_alone_sig = 0x11
let t_property_map = 0x15
let t_property = 0x17
let t_method_semantics = 0x18
let t_method_impl = 0x19
let t_module_ref = 0x1A
let t_type_spec = 0x1B
let t_field_rva = 0x1D
let t_assembly = 0x20
let t_assembly_ref = 0x23
let t_nested_class = 0x29
let t_generic_param = 0x2A
let t_method_spec = 0x2B
let t_generic_param_constraint = 0x2C
let t_user_string = 0x70

(* (the tables no program of ours has, by number where a coded index
 * names them) *)
let t_event = 0x14
let t_decl_security = 0x0E
let t_file = 0x26
let t_exported_type = 0x27
let t_manifest_resource = 0x28

(* II.24.2.6, the coded indexes' tables in the order of their tags *)
let type_def_or_ref =
  { cname = "TypeDefOrRef"; bits = 2; tables = [| t_type_def; t_type_ref; t_type_spec |] }
let has_constant =
  { cname = "HasConstant"; bits = 2; tables = [| t_field; t_param; t_property |] }
let has_custom_attribute =
  { cname = "HasCustomAttribute"; bits = 5;
    tables = [| t_method_def; t_field; t_type_ref; t_type_def; t_param;
                t_interface_impl; t_member_ref; t_module; t_decl_security;
                t_property; t_event; t_stand_alone_sig; t_module_ref;
                t_type_spec; t_assembly; t_assembly_ref; t_file;
                t_exported_type; t_manifest_resource; t_generic_param;
                t_generic_param_constraint; t_method_spec |] }
let has_field_marshal =
  { cname = "HasFieldMarshal"; bits = 1; tables = [| t_field; t_param |] }
let has_decl_security =
  { cname = "HasDeclSecurity"; bits = 2; tables = [| t_type_def; t_method_def; t_assembly |] }
let member_ref_parent =
  { cname = "MemberRefParent"; bits = 3;
    tables = [| t_type_def; t_type_ref; t_module_ref; t_method_def; t_type_spec |] }
let has_semantics =
  { cname = "HasSemantics"; bits = 1; tables = [| t_event; t_property |] }
let method_def_or_ref =
  { cname = "MethodDefOrRef"; bits = 1; tables = [| t_method_def; t_member_ref |] }
let member_forwarded =
  { cname = "MemberForwarded"; bits = 1; tables = [| t_field; t_method_def |] }
let implementation =
  { cname = "Implementation"; bits = 2; tables = [| t_file; t_assembly_ref; t_exported_type |] }
let custom_attribute_type =
  { cname = "CustomAttributeType"; bits = 3;
    tables = [| -1; -1; t_method_def; t_member_ref; -1 |] }
let resolution_scope =
  { cname = "ResolutionScope"; bits = 2;
    tables = [| t_module; t_module_ref; t_assembly_ref; t_type_ref |] }
let type_or_method_def =
  { cname = "TypeOrMethodDef"; bits = 1; tables = [| t_type_def; t_method_def |] }

(* II.22, a table a line: its number is its place *)
let tables : (string * (string * column) array) array = [|
  "Module", [| "Generation", U16; "Name", String; "Mvid", Guid;
               "EncId", Guid; "EncBaseId", Guid |];
  "TypeRef", [| "ResolutionScope", Coded resolution_scope;
                "TypeName", String; "TypeNamespace", String |];
  "TypeDef", [| "Flags", U32; "TypeName", String; "TypeNamespace", String;
                "Extends", Coded type_def_or_ref; "FieldList", Table t_field;
                "MethodList", Table t_method_def |];
  "FieldPtr", [| "Field", Table t_field |];
  "Field", [| "Flags", U16; "Name", String; "Signature", Blob |];
  "MethodPtr", [| "Method", Table t_method_def |];
  "MethodDef", [| "RVA", U32; "ImplFlags", U16; "Flags", U16; "Name", String;
                  "Signature", Blob; "ParamList", Table t_param |];
  "ParamPtr", [| "Param", Table t_param |];
  "Param", [| "Flags", U16; "Sequence", U16; "Name", String |];
  "InterfaceImpl", [| "Class", Table t_type_def;
                      "Interface", Coded type_def_or_ref |];
  "MemberRef", [| "Class", Coded member_ref_parent; "Name", String;
                  "Signature", Blob |];
  "Constant", [| "Type", U8; "Parent", Coded has_constant; "Value", Blob |];
  "CustomAttribute", [| "Parent", Coded has_custom_attribute;
                        "Type", Coded custom_attribute_type; "Value", Blob |];
  "FieldMarshal", [| "Parent", Coded has_field_marshal; "NativeType", Blob |];
  "DeclSecurity", [| "Action", U16; "Parent", Coded has_decl_security;
                     "PermissionSet", Blob |];
  "ClassLayout", [| "PackingSize", U16; "ClassSize", U32;
                    "Parent", Table t_type_def |];
  "FieldLayout", [| "Offset", U32; "Field", Table t_field |];
  "StandAloneSig", [| "Signature", Blob |];
  "EventMap", [| "Parent", Table t_type_def; "EventList", Table t_event |];
  "EventPtr", [| "Event", Table t_event |];
  "Event", [| "EventFlags", U16; "Name", String;
              "EventType", Coded type_def_or_ref |];
  "PropertyMap", [| "Parent", Table t_type_def;
                    "PropertyList", Table t_property |];
  "PropertyPtr", [| "Property", Table t_property |];
  "Property", [| "Flags", U16; "Name", String; "Type", Blob |];
  "MethodSemantics", [| "Semantics", U16; "Method", Table t_method_def;
                        "Association", Coded has_semantics |];
  "MethodImpl", [| "Class", Table t_type_def;
                   "MethodBody", Coded method_def_or_ref;
                   "MethodDeclaration", Coded method_def_or_ref |];
  "ModuleRef", [| "Name", String |];
  "TypeSpec", [| "Signature", Blob |];
  "ImplMap", [| "MappingFlags", U16; "MemberForwarded", Coded member_forwarded;
                "ImportName", String; "ImportScope", Table t_module_ref |];
  "FieldRVA", [| "RVA", U32; "Field", Table t_field |];
  "EncLog", [| "Token", U32; "FuncCode", U32 |];
  "EncMap", [| "Token", U32 |];
  "Assembly", [| "HashAlgId", U32; "MajorVersion", U16; "MinorVersion", U16;
                 "BuildNumber", U16; "RevisionNumber", U16; "Flags", U32;
                 "PublicKey", Blob; "Name", String; "Culture", String |];
  "AssemblyProcessor", [| "Processor", U32 |];
  "AssemblyOS", [| "OSPlatformID", U32; "OSMajorVersion", U32;
                   "OSMinorVersion", U32 |];
  "AssemblyRef", [| "MajorVersion", U16; "MinorVersion", U16;
                    "BuildNumber", U16; "RevisionNumber", U16; "Flags", U32;
                    "PublicKeyOrToken", Blob; "Name", String;
                    "Culture", String; "HashValue", Blob |];
  "AssemblyRefProcessor", [| "Processor", U32;
                             "AssemblyRef", Table t_assembly_ref |];
  "AssemblyRefOS", [| "OSPlatformID", U32; "OSMajorVersion", U32;
                      "OSMinorVersion", U32; "AssemblyRef", Table t_assembly_ref |];
  "File", [| "Flags", U32; "Name", String; "HashValue", Blob |];
  "ExportedType", [| "Flags", U32; "TypeDefId", U32; "TypeName", String;
                     "TypeNamespace", String;
                     "Implementation", Coded implementation |];
  "ManifestResource", [| "Offset", U32; "Flags", U32; "Name", String;
                         "Implementation", Coded implementation |];
  "NestedClass", [| "NestedClass", Table t_type_def;
                    "EnclosingClass", Table t_type_def |];
  "GenericParam", [| "Number", U16; "Flags", U16;
                     "Owner", Coded type_or_method_def; "Name", String |];
  "MethodSpec", [| "Method", Coded method_def_or_ref; "Instantiation", Blob |];
  "GenericParamConstraint", [| "Owner", Table t_generic_param;
                               "Constraint", Coded type_def_or_ref |];
|]

let count = Array.length tables
let name (t : int) : string = fst tables.(t)
let columns (t : int) : (string * column) array = snd tables.(t)

let col (t : int) (c : string) : int =
  let cols = columns t in
  let rec go i =
    if i >= Array.length cols then raise Not_found
    else if fst cols.(i) = c then i
    else go (i + 1) in
  go 0

let token (table : int) (row : int) : int = (table lsl 24) lor row
let token_table (tok : int) : int = (tok lsr 24) land 0xFF
let token_row (tok : int) : int = tok land 0xFFFFFF
