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

	if [[ $image == "debian:8" ]] || [[ $image == "centos:7" ]]; then
		docker run \
			-dp 127.0.0.1:$(port):2222 \
			--privileged \
			-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
			--env=container=docker \
			nsgb/ansible-test-$image \
			/lib/systemd/systemd --system
	else
		docker run \
			-dp 127.0.0.1:$(port):2222 \
			nsgb/ansible-test-$image
	fi

	echo -e ${image%%:*}_${image##*:} ansible_ssh_port=$(port) ansible_ssh_host=127.0.0.1 >> inventory.ini
}

ansiblecfg() {
	echo -e "[defaults]\nroles_path = ../\n[ssh_connection]\nscp_if_ssh=True" > ansible.cfg
}

setup_ssh() {
	wget -c https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant
	chmod 600 vagrant
}

[ -f inventory.ini ] && rm inventory.ini
for image in $TEST_AT_IMAGES; do
	boot $image
done

[ -f ansible.cfg ] && rm ansible.cfg
ansiblecfg
setup_ssh

type ansible || pip install ansible

if [ ! -f tests/main.yml ]; then
	echo "Failed, no tests/main.yml found"
	exit 1
fi

if [ $VERBOSE_TESTS ]; then
	EXTRA_PARAMS=" -vvv"
fi

message "Check syntax"
ansible-playbook \
	-i inventory.ini \
	--syntax-check \
	$EXTRA_PARAMS \
	tests/main.yml

message "Run pre steps | run pre.yml"
[ -f tests/pre.yml ] && ansible-playbook \
	--private-key=vagrant \
	-i inventory.ini \
	-u root \
	$EXTRA_PARAMS \
	tests/pre.yml

message "Run the tests | run main.yml"
ansible-playbook \
	--private-key=vagrant \
	-i inventory.ini \
	-u root \
	$EXTRA_PARAMS \
	tests/main.yml

message "Test for role idempotence | run main.yml"
ansible-playbook \
	--private-key=vagrant \
	-i inventory.ini \
	-u root \
	$EXTRA_PARAMS \
	tests/main.yml | tee out.log
grep 'changed=0.*failed=0' out.log

message "Run post steps | run post.yml"
[ -f tests/post.yml ] && ansible-playbook \
	--private-key=vagrant \
	-i inventory.ini \
	-u root \
	$EXTRA_PARAMS \
	tests/post.yml
