exception Empty

let first l = match l with [] -> raise Empty | x :: _ -> x

let handlers =
  [ (fun caps -> Log.say caps "hello\n");
    (fun _ -> Log.shout "bye\n") ]

let () =
  Cap.main (fun caps ->
    List.iter (fun h -> h caps) handlers;
    ignore (first []))
