NR == 1 { getline; print "after getline:", $0, NR }
NR == 3 { getline x; print "var:", x, $0, NR }
NR == 4 { while ((getline line) > 0) n++; print "left", n + 0, NR, (getline), $0 "|" }
END {
	"echo hello; echo world" | getline x; print x
	"echo hello; echo world" | getline y; print y
	close("echo hello; echo world")
	"echo hello; echo world" | getline z; print z
	while (("echo a; echo b 2" | getline) > 0) print "got", $0, NF
	while ((getline line < "print_fields.in") > 0) c++; print c
	print (getline x < "/nonexistent/file")
	close("print_fields.in"); getline < "print_fields.in"; print $2, NR
}
