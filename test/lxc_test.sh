#!/bin/bash

install() {
	export DEBIAN_FRONTEND=noninteractive
	sudo apt-get install -y \
		-o Dpkg::Options::="--force-confdef" \
		-o Dpkg::Options::="--force-confold" \
		$@
}

install lxc debootstrap
for n in $(seq 1 $1); do
	sudo lxc-create \
		-n vm$n \
		-t $2
	sudo lxc-start -d \
		-n vm$n
done

sudo lxc-ls
sudo ip a
sudo ip r
sudo iptables -L
sudo iptables -t nat -L
sudo brctl show

for n in $(seq 1 $1); do
	sudo lxc-execute -n vm$n -- ping -c 5 google.com
done
