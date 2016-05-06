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
> inventory.ini
for n in $(seq 1 $1); do
	sudo lxc-create \
		-n vm$n \
		-t $2
	sudo lxc-start -d \
		-n vm$n
	echo -n "vm$n ansible_user=root ansible_ssh_pass=root ansible_ssh_host=" >> inventory.ini
	sudo lxc-info \
		-n vm$n -i \
		| awk '{ print $NF }' \
		>> inventory.ini
done

cat inventory.ini
cat ansible.cfg
