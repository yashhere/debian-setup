#!/usr/bin/env fish

# Touch, make executable and start editing a new script
# $ newscript my_new_script.sh
# edit default shebangs within the function
# include additional skeleton files as [extension].txt
# in the $defaults_txt folder defined in config
function newscript
	# Config
	# where your scripts are stored
	set -l scriptdir ~/scripts/
	# if no extension is provided, default to
	set -l default_ext rb
	# optional, where skeleton scripts (e.g. rb.txt) are stored
	set -l defaults_txt ~/.newscript_defaults/
	# End config

	if test (count $argv) -eq 0
		# no argument, display help and exit
		echo -e "newscript: touch, make executable and \
start editing a new script.\n\033[31;1mError:\033[37;1m Missing filename\033[0m\n\n\
Usage: mynewscript SCRIPT_NAME.ext\n"
		return 1
	end

    set -l filename (string replace -r '\/$' '' $scriptdir)"/$argv[1]"

	# get the extension from the filename
	set -l ext (string replace -r '^.*\.' '' $filename)
	# if there's no extension, add default
	if test "$ext" = "$filename"
		set ext $default_ext
		set filename "$filename.$ext"
	end

	# if no script with this name already exists
	if not test -f "$filename"

		# create a file for the given extension with appropriate shebang
		switch $ext
			case rb
				echo -e "#!/usr/bin/env ruby" >> "$filename"
			case py
				echo -e "#!/usr/bin/env python" >> "$filename"
			case pl
				echo -e "#!/usr/bin/env perl" >> "$filename"
			case sh bash
				echo -e "#!/bin/bash" >> "$filename"
            case zsh
				echo -e "#!/bin/zsh" >> "$filename"
			case '*'
				touch "$filename" # any other extension create blank file
		end

		# if skeleton files directory and a txt for the given extension exist
		if test -d (string replace -r '\/$' '' $defaults_txt)
            and test -f (string replace -r '\/$' '' $defaults_txt)"/$ext.txt"
			# concatenate it to the file
			cat (string replace -r '\/$' '' $defaults_txt)"/$ext.txt" >> "$filename"
		end

		# Add trailing newline to the new script
		echo -ne "\n" >> "$filename"
		# Make it executable
		chmod a+x "$filename"
		echo -e "\033[32;1m$filename\033[0m"
	else # Specified filename already exists
		echo -e "\033[31;1mFile exists: $filename\033[0m"
	end

	# Edit the script
	if test -n "$EDITOR"
    	$EDITOR "$filename"
    else
        echo "EDITOR environment variable not set."
    end
end

newscript $argv