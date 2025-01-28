function serve --description 'Start a local server for the current directory'
	set -l port 8080
	if test (count $argv) -eq 1
		set port $argv[1]
	end
	python3 -m http.server $port
end