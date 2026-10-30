// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// What is in an assembly, counted: the numbers of
// docs/plans/done/plan_dotnet.md. Run by survey.sh.
//
//   Survey file.dll...          a line by assembly, then what they ask
//                               together: tables, opcodes, the library
//   Survey -size file.dll       its types, methods and bytes of IL only
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection.Emit;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;

class Survey {
    static Dictionary<int, OpCode> opcodes = new Dictionary<int, OpCode>();

    static int OperandSize(OpCode op, byte[] il, int at) {
        switch (op.OperandType) {
            case OperandType.InlineNone: return 0;
            case OperandType.ShortInlineBrTarget:
            case OperandType.ShortInlineI:
            case OperandType.ShortInlineVar: return 1;
            case OperandType.InlineVar: return 2;
            case OperandType.InlineI8:
            case OperandType.InlineR: return 8;
            case OperandType.InlineSwitch: return 4 + 4 * BitConverter.ToInt32(il, at);
            default: return 4;
        }
    }

    // the opcodes of a method's body, counted in [seen]
    static void Opcodes(byte[] il, SortedDictionary<string, int> seen) {
        int i = 0;
        while (i < il.Length) {
            int code = il[i++];
            if (code == 0xFE) code = 0xFE00 | il[i++];
            OpCode op = opcodes[code];
            seen[op.Name] = (seen.TryGetValue(op.Name, out int n) ? n : 0) + 1;
            i += OperandSize(op, il, i);
        }
    }

    static string TypeName(MetadataReader r, EntityHandle h) {
        switch (h.Kind) {
            case HandleKind.TypeReference:
                TypeReference t = r.GetTypeReference((TypeReferenceHandle)h);
                string ns = r.GetString(t.Namespace);
                return (ns == "" ? "" : ns + ".") + r.GetString(t.Name);
            case HandleKind.TypeDefinition:
                return r.GetString(r.GetTypeDefinition((TypeDefinitionHandle)h).Name);
            case HandleKind.TypeSpecification:
                // a generic instance, an array: the blob's generic type
                BlobReader b = r.GetBlobReader(r.GetTypeSpecification((TypeSpecificationHandle)h).Signature);
                if (b.ReadByte() == 0x15) {      // GENERICINST
                    b.ReadByte();
                    return TypeName(r, b.ReadTypeHandle()) + "<>";
                }
                return "(spec)";
            default: return "(" + h.Kind + ")";
        }
    }

    static void Main(string[] args) {
        foreach (var f in typeof(OpCodes).GetFields()) {
            OpCode op = (OpCode)f.GetValue(null);
            opcodes[(ushort)op.Value] = op;
        }
        bool sizeOnly = args.Length > 0 && args[0] == "-size";
        var allOps = new SortedDictionary<string, int>();
        var allTables = new SortedDictionary<int, int>();
        var allTypes = new SortedSet<string>();
        var allMembers = new SortedSet<string>();
        int inOwn = 0;
        if (!sizeOnly)
            Console.WriteLine("{0,-14}{1,8}{2,8}{3,8}{4,8}{5,8}{6,8}{7,8}{8,8}{9,8}",
                "assembly", "bytes", "IL", "tables", "rows", "types", "methods", "opcodes", "extern", "clauses");
        foreach (string path in args.Skip(sizeOnly ? 1 : 0)) {
            byte[] bytes = File.ReadAllBytes(path);
            using var pe = new PEReader(new MemoryStream(bytes));
            MetadataReader r = pe.GetMetadataReader();
            var ops = new SortedDictionary<string, int>();
            int il = 0, clauses = 0, tables = 0, rows = 0;
            foreach (MethodDefinitionHandle h in r.MethodDefinitions) {
                MethodDefinition m = r.GetMethodDefinition(h);
                if (m.RelativeVirtualAddress == 0) continue;
                MethodBodyBlock body = pe.GetMethodBody(m.RelativeVirtualAddress);
                byte[] code = body.GetILBytes();
                il += code.Length;
                clauses += body.ExceptionRegions.Length;
                if (!sizeOnly) Opcodes(code, ops);
            }
            if (sizeOnly) {
                Console.WriteLine("{0}: {1} bytes, {2} types, {3} methods, {4} bytes of IL",
                    Path.GetFileName(path), bytes.Length, r.TypeDefinitions.Count,
                    r.MethodDefinitions.Count, il);
                continue;
            }
            for (int t = 0; t < 64; t++) {
                int n = r.GetTableRowCount((TableIndex)t);
                if (n == 0) continue;
                tables++; rows += n;
                allTables[t] = (allTables.TryGetValue(t, out int was) ? was : 0) + n;
            }
            var members = new SortedSet<string>();
            foreach (MemberReferenceHandle h in r.MemberReferences) {
                MemberReference m = r.GetMemberReference(h);
                string parent = TypeName(r, m.Parent);
                // a member of a generic instance of the program's own class
                if (m.Parent.Kind == HandleKind.TypeSpecification) {
                    BlobReader b = r.GetBlobReader(r.GetTypeSpecification((TypeSpecificationHandle)m.Parent).Signature);
                    if (b.ReadByte() == 0x15) {
                        b.ReadByte();
                        if (b.ReadTypeHandle().Kind == HandleKind.TypeDefinition) { inOwn++; continue; }
                    }
                }
                members.Add(parent + "::" + r.GetString(m.Name));
            }
            foreach (TypeReferenceHandle h in r.TypeReferences) allTypes.Add(TypeName(r, h));
            allMembers.UnionWith(members);
            foreach (var kv in ops) allOps[kv.Key] = (allOps.TryGetValue(kv.Key, out int was) ? was : 0) + kv.Value;
            Console.WriteLine("{0,-14}{1,8}{2,8}{3,8}{4,8}{5,8}{6,8}{7,8}{8,8}{9,8}",
                Path.GetFileNameWithoutExtension(path), bytes.Length, il, tables, rows,
                r.TypeDefinitions.Count - 1, r.MethodDefinitions.Count, ops.Count, members.Count, clauses);
        }
        if (sizeOnly) return;

        Console.WriteLine();
        Console.WriteLine("tables: {0} of the 45 have a row", allTables.Count);
        foreach (var kv in allTables) Console.WriteLine("  0x{0:X2} {1,-24}{2,5}", kv.Key, (TableIndex)kv.Key, kv.Value);

        Console.WriteLine();
        Console.WriteLine("opcodes: {0} distinct of the {1} that the runtime names, {2} instructions",
            allOps.Count, opcodes.Count, allOps.Values.Sum());
        // the families: ldarg.0, ldarg.1, ldarg.s are one idea
        var families = new SortedDictionary<string, int>();
        foreach (var kv in allOps) {
            string fam = kv.Key.Split('.')[0];
            families[fam] = (families.TryGetValue(fam, out int was) ? was : 0) + kv.Value;
        }
        Console.WriteLine("families (the name before the first dot): {0}", families.Count);
        foreach (var kv in families.OrderByDescending(kv => kv.Value))
            Console.WriteLine("  {0,-14}{1,5}", kv.Key, kv.Value);

        Console.WriteLine();
        Console.WriteLine("the library: {0} types named, {1} members ({2} more are the programs' own generic classes')",
            allTypes.Count, allMembers.Count, inOwn);
        foreach (string m in allMembers) Console.WriteLine("  " + m);
        Console.WriteLine("types named and no member used:");
        foreach (string t in allTypes)
            if (!allMembers.Any(m => m.StartsWith(t + "::") || m.StartsWith(t + "<>::")))
                Console.WriteLine("  " + t);
    }
}
