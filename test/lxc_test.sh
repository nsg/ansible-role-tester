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
		-t $2 \
		-n vm$n
	sudo lxc-start -d \
		-n vm$n
done

sudo lxc-ls
