cat /proc/$$/smaps | awk '
/Shared_Clean/ {SHCL+=$2} 
/Shared_Dirty/ {SHDT+=$2} 
/Private_Clean/ {PRCL+=$2} 
/Private_Dirty/ {PRDT+=$2} 
END { 
  print "Total Clean:", SHCL + PRCL 
  print "Total Dirty:", SHDT + PRDT 
}'
