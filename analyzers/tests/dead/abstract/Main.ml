let () =
  let p : Prog.model App.app = Prog.program in
  ignore (p.step p.start)
