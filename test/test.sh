#!/bin/bash -e

TEST_AT_IMAGES=$1

message() {
	echo -e $@
}

next_port() {
	[ ! -f .ports ] && echo 10000 > .ports
	echo $(( $(cat .ports) + 1 )) > .ports
}

port() {
	cat .ports
}

boot() {
	local image=$1
	next_port
	docker run -dp 127.0.0.1:$(port):2222 nsgb/ansible-test-$image
	echo -e ${image%%:*} ansible_ssh_port=$(port) ansible_ssh_host=127.0.0.1 >> inventory.ini
}

ansiblecfg() {
	echo -e "[defaults]\nroles_path = ../" > ansible.cfg
}

setup_ssh() {
	wget https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant
	chmod 600 vagrant
}

for image in $TEST_AT_IMAGES; do
	boot $image
done

ansiblecfg
setup_ssh
