BEGIN {
	print length("hello"), length(), length(12345), length("héllo")
	print substr("hello", 2), substr("hello", 0, 2), substr("hello", -1, 3), substr("hello", 4, 100), substr("hello", 2, 0) "|", substr("hello", 1.9, 2.9), substr("", 1, 2) "|", substr("héllo", 2, 2)
	print index("hello", "l"), index("hello", "xyz"), index("hello", ""), index("", "a"), index("héllo", "l")
	print toupper("Hello, World 123 é"), tolower("Hello, World 123 É"), utf(233), utf(65)
	print "tab\there", "nl\\n", "q\"q", "oct\101", "hex\x41", "bs\\", "a\/b", "\q"
	s = "x"; s = s s; s = s s; print s, length(s)
}
{ print substr($0, 2); print toupper(substr($1, 1, 1)) substr($1, 2) }
