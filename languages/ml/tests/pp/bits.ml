(* mlpp's bit fields (pp/Bits): an ARM multiply long and a branch
 * decoded, and encoded back *)

type insn =
  | Mull of int * bool * bool * bool * int * int * int * int
  | B of int * bool * int
  | Clrex
  | Undefined of int

(* mlpp: the encodings, as ARM's manual draws them *)
let decode w =
  match w with
  | [%bits "11110101011111111111000000011111"] -> Clrex
  | [%bits "c:4 000 01 signed:b acc:b s:b rdhi:4 rdlo:4 rs:4 1001 rm:4"] when c <> 15 ->
      Mull (c, signed, acc, s, rdhi, rdlo, rs, rm)
  | [%bits "c:4 101 link:b off:s24"] when c <> 15 && off <> 0 -> B (c, link, off)
  | _ -> Undefined w

let encode = function
  | Mull (c, signed, acc, s, rdhi, rdlo, rs, rm) ->
      [%bits "c:4 000 01 signed:b acc:b s:b rdhi:4 rdlo:4 rs:4 1001 rm:4"]
  | B (c, link, off) -> [%bits "c:4 101 link:b off:s24"]
  | Clrex -> [%bits "1111 0101 0111 1111 1111 0000 0001 1111"]
  | Undefined w -> w

let show = function
  | Mull (c, signed, acc, s, rdhi, rdlo, rs, rm) ->
      Printf.sprintf "Mull (%d, %b, %b, %b, %d, %d, %d, %d)" c signed acc s rdhi rdlo rs rm
  | B (c, link, off) -> Printf.sprintf "B (%d, %b, %d)" c link off
  | Clrex -> "Clrex"
  | Undefined w -> Printf.sprintf "Undefined 0x%x" w

let () =
  List.iter (fun w ->
    let i = decode w in
    Printf.printf "0x%08x %s 0x%08x\n" w (show i) (encode i))
    [ 0xe0c12394; 0xe0a54392; 0xeafffffe; 0xeb000010; 0xf57ff01f; 0xe1a00000 ]
