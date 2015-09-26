#!/bin/bash -e

# Call it like this
# ./test.sh "ubuntu:latest debian:7"
# or maybe like this
# ./test.sh "centos debian:7" "myrole_var: 1, var2: True"

ROLE_NAME="$(basename $(pwd))"
TEST_AT_IMAGES=$1
ROLE_PARAMS="$2"

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

siteyml() {
	if [ -z $3 ]; then
	cat <<EOT > $1
---

- hosts: all
  roles:
    - $2

EOT
	else
	cat <<EOT > $1
---

- hosts: all
  roles:
    - { role: $2, $3 }

EOT
	fi
}

for image in $TEST_AT_IMAGES; do
	boot $image
done

ansiblecfg
setup_ssh
siteyml site.yml "$ROLE_NAME" "$ROLE_PARAMS"

type ansible || pip install ansible
ansible-playbook --private-key=vagrant -i inventory.ini -u root site.yml
