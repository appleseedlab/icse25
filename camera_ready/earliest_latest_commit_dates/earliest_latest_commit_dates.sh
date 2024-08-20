git show $(cat unique_commits.txt) --format="%H %ci" --no-patch | sort -k 2 | awk 'NR==1{print "Earliest Commit: "$2" "$3}; END{print "Latest Commit: "$2" "$3}'

