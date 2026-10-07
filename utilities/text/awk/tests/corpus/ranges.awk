NR==2, NR==3 { print "a", $1 }
/bob/, /carol/ { print "b", NR, $1 }
/alice/, /alice/ { print "c", $1 }
/dave/, /nothing/ { print "d", $1 }
NR==1, NR==2
