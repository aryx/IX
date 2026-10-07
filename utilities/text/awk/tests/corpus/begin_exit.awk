BEGIN { print "begin"; exit; print "not" }
{ print "never" }
END { print "end after begin exit" }
