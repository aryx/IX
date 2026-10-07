$2 > 28
$3 == "paris" { n++; s += $2 }
/o/ { print "o:", $1 }
!/o/ { print "no o:", $1 }
$1 ~ /^[a-c]/ { print NR ": " $0 }
$1 !~ /a/ { print "no a:", $1 }
$0 ~ "^a" { print "dyn", $0 }
NR % 2 == 0 && $2 < 30 || /rome/ { print "bool", $1 }
END { print n, s, s/n }
