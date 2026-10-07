BEGIN { OFS = "-" }
NR == 1 { $2 = $2 * 2; print; print NF }
NR == 2 { $5 = "x"; print; print NF }
NR == 3 { NF = 2; print; $1 = $1; print }
NR == 4 { $0 = "a b c d"; print NF, $4; $2 = ""; print; print NF; $(NF+2) = "q"; print; print NF }
END { $3 = "c"; print $0 "|" NF; print $1 "|" }
