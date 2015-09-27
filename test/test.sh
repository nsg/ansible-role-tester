#!/bin/bash -e

# Call it like this
# ./test.sh "ubuntu:latest debian:7"

TEST_AT_IMAGES="$1"

message() {
	echo -e "\n###"
	echo -e "# $@"
	echo -e "###\n"
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
	echo -e ${image%%:*}_${image##*:} ansible_ssh_port=$(port) ansible_ssh_host=127.0.0.1 >> inventory.ini
}

ansiblecfg() {
	echo -e "[defaults]\nroles_path = ../" > ansible.cfg
}

setup_ssh() {
	wget -c https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant
	chmod 600 vagrant
}

rm inventory.ini
for image in $TEST_AT_IMAGES; do
	boot $image
done

rm ansible.cfg
ansiblecfg
setup_ssh

type ansible || pip install ansible

if [ ! -f tests/main.yml ]; then
	echo "Failed, no tests/main.yml found"
	exit 1
fi

message "Prepare the system | run prep.yml"
[ -f tests/prep.yml ] && ansible-playbook --private-key=vagrant -i inventory.ini -u root tests/prep.yml

message "Run pre steps | run pre.yml"
[ -f tests/pre.yml ] && ansible-playbook --private-key=vagrant -i inventory.ini -u root tests/pre.yml

message "Run the tests | run main.yml"
ansible-playbook --private-key=vagrant -i inventory.ini -u root tests/main.yml

message "Test for role idempotence | run main.yml"
ansible-playbook --private-key=vagrant -i inventory.ini -u root tests/main.yml \
  | grep -q 'changed=0.*failed=0'

message "Run post steps | run post.yml"
[ -f tests/post.yml ] && ansible-playbook --private-key=vagrant -i inventory.ini -u root tests/post.yml
