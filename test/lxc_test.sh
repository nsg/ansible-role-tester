#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y \
	-o Dpkg::Options::="--force-confdef" \
	-o Dpkg::Options::="--force-confold" \
	lxc debootstrap

sudo lxc-create -t debian -n debian8
