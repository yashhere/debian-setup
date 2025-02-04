# Load environment variables from a bash-style KEY=VALUE .env file into fish shell
# Skip empty lines and comments
# Handle both quoted and unquoted values

if test -f ~/.env
    for line in (command cat ~/.env)
        # Skip empty lines and comments
        if test -n "$line" && not string match -q "#*" $line
            # Split on first = only
            set parts (string split --max 1 = $line)

            # Check if we got a valid key-value pair
            if test (count $parts) -eq 2
                # Remove surrounding quotes if present
                set value (string trim -c '"' -c "'" $parts[2])
                # Set as global exported variable
                set -gx $parts[1] $value
            end
        end
    end
end
