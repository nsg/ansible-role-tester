#!/bin/bash

set -x
set -e
set -o pipefail

message() {
	echo -e "\n###"
	echo -e "# $@"
	echo -e "###\n"
}

install() {
	export DEBIAN_FRONTEND=noninteractive
	message "Install $@"
	sudo apt-get install -y \
		-o Dpkg::Options::="--force-confdef" \
		-o Dpkg::Options::="--force-confold" \
		$@
}

ansiblecfg() {
	message "Setup ansible.cfg"
	echo "[defaults]"              >  ansible.cfg
	echo "roles_path = ../"        >> ansible.cfg
	echo "host_key_checking=False" >> ansible.cfg
	echo "[ssh_connection]"        >> ansible.cfg
	echo "scp_if_ssh=True"         >> ansible.cfg
}

install_ansible() {
	message "Install Ansible"
	type ansible || pip install ansible
}

run_tests() {
	if [ ! -f tests/main.yml ]; then
		echo "Failed, no tests/main.yml found"
		exit 1
	fi

	if [ $VERBOSE_TESTS ]; then
		EXTRA_PARAMS=" -vvv"
	fi

	message "Check syntax"
	ansible-playbook \
		--private-key=test_keys \
		-i inventory.ini \
		--syntax-check \
		$EXTRA_PARAMS \
		tests/main.yml

	message "Run pre steps | run pre.yml"
	[ -f tests/pre.yml ] && ansible-playbook \
		--private-key=test_keys \
		-i inventory.ini \
		-u root \
		$EXTRA_PARAMS \
		tests/pre.yml

	message "Run the tests | run main.yml"
	ansible-playbook \
		--private-key=test_keys \
		-i inventory.ini \
		-u root \
		$EXTRA_PARAMS \
		tests/main.yml

	message "Test for role idempotence | run main.yml"
	ansible-playbook \
		--private-key=test_keys \
		-i inventory.ini \
		-u root \
		$EXTRA_PARAMS \
		tests/main.yml | tee out.log
	grep 'changed=0.*failed=0' out.log

	message "Run post steps | run post.yml"
	[ -f tests/post.yml ] && ansible-playbook \
		--private-key=test_keys \
		-i inventory.ini \
		-u root \
		$EXTRA_PARAMS \
		tests/post.yml
}

make_containers() {
	message "Make LXC container based on $2"
	for n in $(seq 1 $1); do
		sudo lxc-create -n vm$n -t $2
		sudo mkdir -p /var/lib/lxc/vm$n/rootfs/root/.ssh
		sudo chmod 700 /var/lib/lxc/vm$n/rootfs/root/.ssh
		sudo cp test_keys.pub /var/lib/lxc/vm$n/rootfs/root/.ssh/authorized_keys
		sudo chmod 600 /var/lib/lxc/vm$n/rootfs/root/.ssh/authorized_keys
		sudo lxc-start -d -n vm$n
		sleep 5
		echo -n "vm$n ansible_user=root ansible_ssh_host=" >> inventory.ini
		sudo lxc-info -n vm$n -i | awk '{ print $NF }' >> inventory.ini
	done
}

patch_lxc_install() {
	message "Download a newer version of the $1 template"
	sudo wget -O /usr/share/lxc/templates/lxc-${1} \
		https://raw.githubusercontent.com/lxc/lxc/master/templates/lxc-${1}.in
}

[ -f test_keys ] || ssh-keygen -f test_keys -N ""
install lxc debootstrap sshpass yum
install_ansible
ansiblecfg
> inventory.ini
patch_lxc_install $(echo $2 | awk '{ print $1 }')
make_containers $1 "$2"
run_tests

exit 0
