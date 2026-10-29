.assembly strings
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Strings extends [System.Private.CoreLib]System.Object
{
  .method static int32 Value(string)   // RVA 0x2050, 50 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldstr "I"
    IL_0006: call bool [System.Private.CoreLib]System.String::op_Equality(string, string)
    IL_000b: brtrue.s IL_0029
    IL_000d: ldarg.0
    IL_000e: ldstr "V"
    IL_0013: call bool [System.Private.CoreLib]System.String::op_Equality(string, string)
    IL_0018: brtrue.s IL_002b
    IL_001a: ldarg.0
    IL_001b: ldstr "X"
    IL_0020: call bool [System.Private.CoreLib]System.String::op_Equality(string, string)
    IL_0025: brtrue.s IL_002d
    IL_0027: br.s IL_0030
    IL_0029: ldc.i4.1
    IL_002a: ret
    IL_002b: ldc.i4.5
    IL_002c: ret
    IL_002d: ldc.i4.s 10
    IL_002f: ret
    IL_0030: ldc.i4.0
    IL_0031: ret
  }
  .method static void Main()   // RVA 0x2084, 252 bytes
  {
    .entrypoint
    .maxstack 3
    .locals (string, int32, class [System.Private.CoreLib]System.Text.StringBuilder, valuetype [System.Private.CoreLib]System.Runtime.CompilerServices.DefaultInterpolatedStringHandler, int32)
    IL_0000: ldstr "Hello"
    IL_0005: stloc.0
    IL_0006: ldloc.0
    IL_0007: ldstr ", World"
    IL_000c: call string [System.Private.CoreLib]System.String::Concat(string, string)
    IL_0011: dup
    IL_0012: callvirt instance int32 [System.Private.CoreLib]System.String::get_Length()
    IL_0017: call void [System.Console]System.Console::WriteLine(int32)
    IL_001c: dup
    IL_001d: ldc.i4.7
    IL_001e: callvirt instance string [System.Private.CoreLib]System.String::Substring(int32)
    IL_0023: call void [System.Console]System.Console::WriteLine(string)
    IL_0028: dup
    IL_0029: callvirt instance string [System.Private.CoreLib]System.String::ToUpper()
    IL_002e: call void [System.Console]System.Console::WriteLine(string)
    IL_0033: dup
    IL_0034: ldstr "World"
    IL_0039: callvirt instance int32 [System.Private.CoreLib]System.String::IndexOf(string)
    IL_003e: call void [System.Console]System.Console::WriteLine(int32)
    IL_0043: ldc.i4.4
    IL_0044: callvirt instance char [System.Private.CoreLib]System.String::get_Chars(int32)
    IL_0049: call void [System.Console]System.Console::WriteLine(char)
    IL_004e: ldloc.0
    IL_004f: ldstr "Hello"
    IL_0054: call bool [System.Private.CoreLib]System.String::op_Equality(string, string)
    IL_0059: call void [System.Console]System.Console::WriteLine(bool)
    IL_005e: ldc.i4.s 42
    IL_0060: stloc.1
    IL_0061: ldloca.s 3
    IL_0063: ldc.i4.s 15
    IL_0065: ldc.i4.2
    IL_0066: call instance void [System.Private.CoreLib]System.Runtime.CompilerServices.DefaultInterpolatedStringHandler::.ctor(int32, int32)
    IL_006b: ldloca.s 3
    IL_006d: ldstr "n is "
    IL_0072: call instance void [System.Private.CoreLib]System.Runtime.CompilerServices.DefaultInterpolatedStringHandler::AppendLiteral(string)
    IL_0077: ldloca.s 3
    IL_0079: ldloc.1
    IL_007a: call instance void [System.Private.CoreLib]System.Runtime.CompilerServices.DefaultInterpolatedStringHandler::AppendFormatted<!!0>(!!0) with <int32>
    IL_007f: ldloca.s 3
    IL_0081: ldstr " and s is "
    IL_0086: call instance void [System.Private.CoreLib]System.Runtime.CompilerServices.DefaultInterpolatedStringHandler::AppendLiteral(string)
    IL_008b: ldloca.s 3
    IL_008d: ldloc.0
    IL_008e: call instance void [System.Private.CoreLib]System.Runtime.CompilerServices.DefaultInterpolatedStringHandler::AppendFormatted(string)
    IL_0093: ldloca.s 3
    IL_0095: call instance string [System.Private.CoreLib]System.Runtime.CompilerServices.DefaultInterpolatedStringHandler::ToStringAndClear()
    IL_009a: call void [System.Console]System.Console::WriteLine(string)
    IL_009f: ldstr "V"
    IL_00a4: call int32 Strings::Value(string)
    IL_00a9: ldstr "X"
    IL_00ae: call int32 Strings::Value(string)
    IL_00b3: add
    IL_00b4: call void [System.Console]System.Console::WriteLine(int32)
    IL_00b9: newobj instance void [System.Private.CoreLib]System.Text.StringBuilder::.ctor()
    IL_00be: stloc.2
    IL_00bf: ldc.i4.0
    IL_00c0: stloc.s 4
    IL_00c2: br.s IL_00da
    IL_00c4: ldloc.2
    IL_00c5: ldloc.s 4
    IL_00c7: callvirt instance class [System.Private.CoreLib]System.Text.StringBuilder [System.Private.CoreLib]System.Text.StringBuilder::Append(int32)
    IL_00cc: ldc.i4.s 32
    IL_00ce: callvirt instance class [System.Private.CoreLib]System.Text.StringBuilder [System.Private.CoreLib]System.Text.StringBuilder::Append(char)
    IL_00d3: pop
    IL_00d4: ldloc.s 4
    IL_00d6: ldc.i4.1
    IL_00d7: add
    IL_00d8: stloc.s 4
    IL_00da: ldloc.s 4
    IL_00dc: ldc.i4.5
    IL_00dd: blt.s IL_00c4
    IL_00df: ldloc.2
    IL_00e0: callvirt instance string [System.Private.CoreLib]System.Object::ToString()
    IL_00e5: call void [System.Console]System.Console::WriteLine(string)
    IL_00ea: ldstr "123"
    IL_00ef: call int32 [System.Private.CoreLib]System.Int32::Parse(string)
    IL_00f4: ldc.i4.1
    IL_00f5: add
    IL_00f6: call void [System.Console]System.Console::WriteLine(int32)
    IL_00fb: ret
  }
  .method instance void .ctor()   // RVA 0x218c, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}
