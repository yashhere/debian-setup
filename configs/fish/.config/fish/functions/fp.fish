function fp -d 'Find and list processes matching a case-insensitive fuzzy-match string'
	set -l options "f/fuzzy"

	argparse $options -- $argv

	set -l needle $argv
	if set -q _flag_fuzzy
		set needle (__regex_from_args -f $needle)
	end

    command ps -eo pid,comm | awk 'NR>1 {print $2": "$1}' | grep -iE $needle | grep -v grep
end