BEGIN {
	print match("foobar", /o+/), RSTART, RLENGTH
	print match("foobar", "z"), RSTART, RLENGTH
	print match("aaa", /a*/), RLENGTH
	print match("xyz", /^/), RSTART, RLENGTH
	print match("xyz", /$/), RSTART, RLENGTH
	print match("héllo", /l+/), RSTART, RLENGTH
	print match("a.b", /\./), match("ab", /a|b/), match("ab", /(a|b)+/), RLENGTH
	print match("abc", /[b-z]+/), RLENGTH, match("a-b", /[-]/), match("a]b", /[]]/)
	print match("x()", /()/), match("tab\there", /\t/), match("a1", /[0-9]/), match("AbC", /[A-Z][a-z]/)
}
/a\/b/ { print "slash" } /\./ { print "dot" } /a|b/ { print "ab" } /^$/ { print "empty" }
{ print ($1 ~ $2) }
