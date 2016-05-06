#!/bin/bash

install() {
	export DEBIAN_FRONTEND=noninteractive
	sudo apt-get install -y \
		-o Dpkg::Options::="--force-confdef" \
		-o Dpkg::Options::="--force-confold" \
		$@
}

ansiblecfg() {
	echo "[defaults]"       >  ansible.cfg
	echo "roles_path = ../" >> ansible.cfg
	echo "[ssh_connection]" >> ansible.cfg
	echo "scp_if_ssh=True"  >> ansible.cfg
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

sleep 8

for n in $(seq 1 $1); do
	sudo lxc-info -n vm$n
done
