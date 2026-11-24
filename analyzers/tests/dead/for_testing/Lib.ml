(* mini-analyze -dead on [@@for_testing]: a function only the tests call
 * is a root, and so is not dead, nor what it calls; a program that calls
 * one is reported *)

let used x = x + 1

(* only for_tests calls it: live *)
let helper x = x * 2
let for_tests x = helper x + 1 [@@for_testing]

(* Main calls it: reported where Main does *)
let misused x = x - 1 [@@for_testing]

(* nothing calls it, and it is not for the tests: dead *)
let unused x = x + 3
