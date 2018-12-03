#!/bin/bash

chain_exists()
{
	[ $# -lt 1 -o $# -gt 2 ] && { 
		echo "Usage: chain_exists <chain_name> [table]" >&2
		return 1
	}
	local chain_name="$1" ; shift
	[ $# -eq 1 ] && local table="--table $1"
	iptables -t $table -n --list "$chain_name" >/dev/null 2>&1
}

iptables_rules() {
	# Add custom chain
	chain_exists REDSOCKS nat
	local CHAIN_EXISTS=$?
	if [ $CHAIN_EXISTS -ne 0 -a $1 = 'A' ]; then
		echo "Adding chain 'REDSOCKS'"
		iptables -t nat -N REDSOCKS
	fi

	# Exclude local and reserved addresses
	iptables -t nat -$1 REDSOCKS -d 0.0.0.0/8 -j RETURN
	iptables -t nat -$1 REDSOCKS -d 10.0.0.0/8 -j RETURN
	iptables -t nat -$1 REDSOCKS -d 127.0.0.0/8 -j RETURN
	iptables -t nat -$1 REDSOCKS -d 169.254.0.0/16 -j RETURN
	iptables -t nat -$1 REDSOCKS -d 172.16.0.0/12 -j RETURN
	iptables -t nat -$1 REDSOCKS -d 192.168.0.0/16 -j RETURN
	iptables -t nat -$1 REDSOCKS -d 224.0.0.0/4 -j RETURN
	iptables -t nat -$1 REDSOCKS -d 240.0.0.0/4 -j RETURN

	# Redirect all connections passed to the REDSOCKS chain
	iptables -t nat -$1 REDSOCKS -p tcp --destination-port 80 -j REDIRECT --to-ports 12346
	iptables -t nat -$1 REDSOCKS -p tcp -j REDIRECT --to-ports 12345

	# Redirect all HTTP and HTTPS outgoing packets through Redsocks
	iptables -t nat -$1 PREROUTING -p tcp -j REDSOCKS
	iptables -t nat -$1 OUTPUT -p tcp -j REDSOCKS
	
	if [ $CHAIN_EXISTS -eq 0 -a $1 = 'D' ]; then
		echo "Removing chain 'REDSOCKS'"
		iptables -t nat -X REDSOCKS
	fi
}

append_redsocks_conf() {
	local address=$1
	local port=$2

	# set env vars to config
	sed -e "s/\${HTTP_PROXY_HOST}/${address}/g" -e "s/\${HTTP_PROXY_PORT}/${port}/g" /etc/redsocks.conf.tmpl > /etc/redsocks.conf
}

stop() {
	echo "Cleaning iptables"
	iptables_rules D
	echo "Killing redsocks ($PID)..."
	kill -TERM $PID
}

interrupted() {
	echo "Interrupted, cleaning up..."
	trap - INT
	stop $1
	kill -INT $$
}

terminated () {
	echo 'Terminated, cleaning up...'
	trap - TERM
	stop $1
	kill -TERM $$
}

run() {
	if [ -z ${HTTP_PROXY_HOST+x} -o -z ${HTTP_PROXY_PORT+x} ]; then
		echo "Please specify the upstream proxy with HTTP_PROXY_HOST and HTTP_PROXY_PORT"
		return 1
	fi

	trap 'interrupted $PID' INT
	trap 'terminated $PID' TERM
	
	# Clean-up any inconsistent state
	chain_exists REDSOCKS nat
	local CHAIN_EXISTS=$?
	if [ $? -ne 0 ]; then
		iptables_rules D
	fi
	
	# Configure upstream proxy
	append_redsocks_conf $HTTP_PROXY_HOST $HTTP_PROXY_PORT
	iptables_rules A
	
	echo "Starting redsocks..."
	/bin/redsocks -c /etc/redsocks.conf &
	export PID=$!
	wait $PID
}

case "$1" in
    stop )  stop ;;
    * )     run ;;
esac
