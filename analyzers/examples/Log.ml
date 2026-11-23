let say (caps : < Cap.stdout; .. >) s = Console.print caps s
let shout s = print_string (String.uppercase_ascii s)
let unused () = shout "never"
