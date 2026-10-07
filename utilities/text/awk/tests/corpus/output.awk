BEGIN {
	print "c\nb\na" | "sort"; close("sort")
	print "one" > "/dev/stdout"
	print "two" > "/dev/stderr"
	printf "%s\n", "three" > "/dev/stderr"
	print "x" > "/dev/null"; print "y" >> "/dev/null"
	print system("exit 3"), system("true"), system("echo from system")
	print "tr" | "tr a-z A-Z"; print "second" | "tr a-z A-Z"
	fflush(); print fflush("nope"), fflush("tr a-z A-Z")
	print "last"
}
