(* outside, model is Prog.model; here int list: the two names one type *)
type model = int list
let step (m : model) : model = 0 :: m
let unused (m : model) : model = m
let program : model App.app = { start = []; step }
