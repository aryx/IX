BEGIN { s = "hello world"; n = sub(/o/, "0", s); print n, s; n = gsub(/o/, "0", s); print n, s
s = "aaa"; gsub(/a/, "&&", s); print s
s = "abc"; gsub(/b/, "[\\&]", s); print s
s = "abc"; gsub(/x*/, "-", s); print s
s = "abc"; gsub(//, "-", s); print s
s="hello"; gsub(/l+/, "L", s); print s
s = "a.b.c"; gsub(/\./, "", s); print s
s = "abc"; sub(/$/, "!", s); print s; sub(/^/, ">", s); print s
s = "foo bar"; gsub(/o|a/, "", s); print s; t = "x"; print sub("x", "y", t), t
s = "abc"; gsub(/b*/, "X", s); print s
s = "abc"; gsub(/$/, "X", s); print s
s = "abc"; gsub(/^/, "X", s); print s
s = "a b"; gsub(/ /, "\\\\&", s); print s
s = "aXb"; gsub(/X/, "\\\\\\&", s); print s
s = ""; print gsub(/x*/, "-", s), s
s = "héllo"; gsub(/é/, "e", s); print s
s = "abab"; print gsub("ab", "c", s), s, sub(/z/, "y", s), s
}
{ gsub(/a/, "A"); print; n = sub(/o/, "0"); print n, $0, $1; sub(/A/, "a", $1); print; print NF }
