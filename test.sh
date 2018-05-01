#!/bin/bash -e

#
# Print a yellow info message to stdout
#

message() {
	echo -e "\e[33m# $@\e[0m"
}

#
# Retry a step a few times
#
retry_step() {
  $@ || ($@ || $@)
}

#
# Write a ansible.cfg config file for our build
# If there already is an ansible.cfg, backup it
#

ansiblecfg() {
	if [ -f ansible.cfg ]; then
		message "Rename existing ansible.cfg"
		mv ansible.cfg{,.org}
	fi
	cat <<- EOF > ansible.cfg
		[defaults]
		roles_path = ../
		host_key_checking = False
		[ssh_connection]
		scp_if_ssh=True
	EOF
}

#
# Install a deb package from repo
#

install_package() {
	if ! dpkg -s $1 2>&1 > /dev/null; then
		message "Install package $1 ($@)"
		sudo apt-get install $@
	fi
}

#
# Install a pip package
#

install_pip() {
	pip freeze | grep -q $1 || pip install $1
}

#
# Prep the enironment with apps and deps
#

prep_packages() {
	sudo apt-get -qq update
	sudo apt-get install -y -t trusty-backports lxd lxd-client
	sudo lxd init --auto --storage-backend=dir || :
	sudo lxc network create testbr0
	sudo lxc network attach-profile testbr0 default eth0

	install_package python-dev
	install_package python-virtualenv
	install_package libssl-dev
	install_package libffi-dev
	install_package gcc
	install_pip pyyaml
}

#
# Setup a env with a specific version of Ansible.
# If the env is already there, just activate it.
#

ansible_version() {
	if [ ! -e .env_$1 ]; then
		message "Setup a virtualenv for Ansible $1"
		virtualenv .env_$1
		. .env_$1/bin/activate
		if [[ $1 == latest ]]; then
			pip install ansible
		else
			pip install ansible==$1
		fi
	else
		. .env_$1/bin/activate
	fi
}

#
# Setup a LXD container
#

setup_container() {
	local image_name=$1

	name=$(echo $image_name | tr A-Z a-z | sed -e 's/[^a-z0-9]/-/g')
	if ! sudo lxc list | grep -q $name; then
		message "Setup $name with image $image_name"
		retry_step sudo lxc launch $image_name $name
		while ! sudo lxc list -c 4 $name | grep -q eth0; do
			sleep 1
		done
		message "Install packages and ssh keys for container $name"
		sudo lxc exec $name -- dnf install -y openssh-server || :
		sudo lxc exec $name -- yum install -y openssh-server || :
		sudo lxc exec $name -- apt-get install -y openssh-server || :
		sudo lxc exec $name -- apt-get install -y python || :
		sudo lxc exec $name -- dnf install -y python || :
		sudo lxc exec $name -- mkdir -p /root/.ssh
		sudo lxc exec $name -- chmod 700 /root/.ssh
		sudo lxc file push --uid=0 --gid=0 --mode=0400 \
			ssh-key.pub $name/root/.ssh/authorized_keys
		sudo lxc exec $name -- service sshd start || :
		sudo lxc exec $name -- service ssh start || :
	else
		message "Container $name already running"
	fi
}

#
# Generate a inventory from running LXD containers
#

inventoryini() {
	sudo lxc list \
	  | awk '/RUNNING/{ print $2" ansible_host="$6" ansible_ssh_host="$6 }' \
	  > inventory.ini
}

#
# Generate local ssh keys
#
gensshkeys() {
	ssh-keygen -N "" -f ssh-key
}

#
# Run a step
#

step() {
	if [ -f tests/$1.yml ]; then
		message "Syntax check step $1"
		ansible-playbook $RUN_EXTRA_VARS_LIST \
			-i inventory.ini \
			--syntax-check \
			tests/$1.yml

		message "Run play in step $1"
		ansible-playbook $RUN_EXTRA_VARS_LIST \
			-i inventory.ini \
			--private-key=ssh-key \
			-u root \
			tests/$1.yml
	else
		message "Skipping step $1"
	fi
}

if [[ -z $CONTAINER_IMAGES ]]; then
	message "CONTAINER_IMAGES environment not set"
	exit 1
fi

if [[ -z $ANSIBLE_VERSIONS ]]; then
	message "ANSIBLE_VERSIONS environment not set"
	exit 1
fi

if [[ -n $ANSIBLE_EXTRA_VARS_LIST ]]; then
	message "ANSIBLE_EXTRA_VARS_LIST is set, I will add these params to all plays:"
	RUN_EXTRA_VARS_LIST=""
	for e in $(echo $ANSIBLE_EXTRA_VARS_LIST | tr ':' ' '); do
		RUN_EXTRA_VARS_LIST="${RUN_EXTRA_VARS_LIST} -e $e "
	done
	echo "$RUN_EXTRA_VARS_LIST"
fi

if [[ $1 == install ]]; then
	message "Start Ansible Role Tester: Install mode"; ansiblecfg
	message "Install packages"; prep_packages
	message "Generate ssh keys"; gensshkeys

	message "Setup containers";
	for c in $CONTAINER_IMAGES; do
		setup_container $c
	done
	message "Containers"; sudo lxc list

	for ver in $ANSIBLE_VERSIONS; do
		message "Install Ansible version $ver (in background)"
		(ansible_version $ver 2>&1 > ansible-install.out || cat ansible-install.out)&
	done
	message "Wait for Ansible installs"
	wait

	message "Generate inventory.ini"; inventoryini; cat inventory.ini
else
	message "Start Ansible Role Tester: Test mode";

	for ver in $ANSIBLE_VERSIONS; do
		message "Test with Ansible version $ver"
		ansible_version $ver
		step pre
		step main
		message "Test for role idempotence"
		step main | tee out.log; grep 'changed=0.*failed=0' out.log
		step post
	done
fi
