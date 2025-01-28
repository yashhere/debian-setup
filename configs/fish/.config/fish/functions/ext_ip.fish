function ext_ip -d "Get external IP address"
	curl -Ss icanhazip.com
end