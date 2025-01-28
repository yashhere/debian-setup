function ips -d 'Display all ip addresses for this host'
	command ip a | grep "inet " | awk '{ print $2 }'
	echo "External: "(ext_ip)
end