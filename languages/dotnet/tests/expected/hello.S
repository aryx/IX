.assembly hello
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Hello extends [System.Private.CoreLib]System.Object
{
  .method static void Main()   // RVA 0x2050, 11 bytes
  {
    .entrypoint
    .maxstack 8
    IL_0000: ldstr "Hello, World!"
    IL_0005: call void [System.Console]System.Console::WriteLine(string)
    IL_000a: ret
  }
  .method instance void .ctor()   // RVA 0x205c, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}
