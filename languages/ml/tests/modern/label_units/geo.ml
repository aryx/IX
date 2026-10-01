let area ~w ~h = (w * 100) + h
let scale n ~by = n * by
let describe ~name ~size = name ^ ":" ^ string_of_int size
