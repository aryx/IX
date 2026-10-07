BEGIN { FS = ":"; printf "%-10s %6s %8s\n", "name", "qty", "total"; printf "%-10s %6s %8s\n", "----", "---", "-----" }
/^#/ { next }
NF != 3 { bad++; next }
{ total = $2 * $3; sum += total; printf "%-10s %6d %8.2f\n", $1, $2, total; if (total > max) { max = total; who = $1 } }
END { printf "%-10s %6s %8.2f\n", "sum", "", sum; print "largest:", who, max; print "bad lines:", bad + 0; print "average:", sum / (NR - bad - 1) }
