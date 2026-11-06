(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CapUnix.mli: the capability's type written, which -caps checks
 * against what the function does (capabilities.dl's lib_gate) *)

let fork (_ : < Cap.fork; .. >) = Unix.fork
let execv (_ : < Cap.exec; .. >) = Unix.execv
let execve (_ : < Cap.exec; .. >) = Unix.execve
let wait (_ : < Cap.wait; .. >) = Unix.wait
let waitpid (_ : < Cap.wait; .. >) = Unix.waitpid
let kill (_ : < Cap.kill; .. >) = Unix.kill
let chdir (_ : < Cap.chdir; .. >) = Unix.chdir
let environment (_ : < Cap.env; .. >) = Unix.environment
let gettimeofday (_ : < Cap.clock; .. >) = Unix.gettimeofday
let time (_ : < Cap.clock; .. >) = Unix.time
let sleepf (_ : < Cap.clock; .. >) = Unix.sleepf
let pipe (_ : < Cap.pipe; .. >) = Unix.pipe
let getpid (_ : < Cap.env; .. >) = Unix.getpid
let getcwd (_ : < Cap.env; .. >) = Unix.getcwd
let setitimer (_ : < Cap.signal; .. >) = Unix.setitimer
let _exit (_ : < Cap.exit; .. >) = Unix._exit
let mkfifo (_ : < Cap.open_out; .. >) = Unix.mkfifo
let getaddrinfo (_ : < Cap.network; .. >) = Unix.getaddrinfo
let socket (_ : < Cap.network; .. >) = Unix.socket
let connect (_ : < Cap.network; .. >) = Unix.connect
let bind (_ : < Cap.network; .. >) = Unix.bind
let listen (_ : < Cap.network; .. >) = Unix.listen
let accept (_ : < Cap.network; .. >) = Unix.accept
