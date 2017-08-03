#!/bin/bash -e

#
# Print a yellow info message to stdout
#

message() {
	echo -e "\e[33m# $@\e[0m"
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
	sudo add-apt-repository -y ppa:ubuntu-lxc/lxd-stable
	sudo apt-get -qq update
	install_package lxd
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
		pip install ansible==$1
	else
		. .env_$1/bin/activate
	fi
}

#
# Hacky solution to parse the yaml file to a shell friendly format.
# Output is:
#   dependencies|dep1 dep2 (can be empty)
#   min_ansible_version|1.2.3
#   platforms|EL:6,7 ubuntu:trusty
#

simple_yaml_parser() {
	cat <<- EOF > simple_yaml_parser.py
		import yaml

		with open("$1", 'r') as stream:
		  try:
		    m = yaml.load(stream)
		    print("dependencies|{}".format(" ".join(m['dependencies'])))
		    print("min_ansible_version|{}".format(m['galaxy_info']['min_ansible_version']))
		    pl = []
		    for p in m['galaxy_info']['platforms']:
		      pl.append("{}:{}".format(p['name'], ",".join(map(lambda x: str(x), p['versions']))))
		    print("platforms|{}".format(" ".join(pl)))
		  except yaml.YAMLError as exc:
		    print(exc)
	EOF

	python simple_yaml_parser.py
}

#
# List all ansible versions, use PyPI API
#

ansible_versions() {
	curl -s https://pypi.python.org/pypi/ansible/json \
		| awk -F'"' '/"filename":/{print $4}' \
		| cut -f2 -d'-' | sed 's/.tar.gz//'
}

#
# Get min_ansible_version from meta/main.yml
#

min_ansible_version() {
	simple_yaml_parser meta/main.yml | awk -F'|' '/min_ansible_version/{print $2}'
}

#
# Get platforms from meta/main.yml
# The format is returned in lxd image format
#

platforms() {
	for i in $(simple_yaml_parser meta/main.yml | awk -F'|' '/platforms/{print $2}'); do
		dist="$(echo ${i,,} | awk -F':' '{print $1}')"
		versions="$(echo ${i,,} | awk -F':' '{print $2}' | tr ',' ' ')"

		if [ $dist == "el" ]; then
		  dist="centos"
		fi

		for v in $versions; do
			echo -n images:
			if [[ $v == "all" ]]; then
				find_image_name $dist
			else
				find_image_name $dist $v
			fi
		done
	done
}

#
# Find a image name from the remote images:
#

find_image_name() {
	sudo lxc image list images: \
		| grep x86_64 \
		| grep -i "$1/$2" \
		| head -1 \
		| tr -d '|' \
		| awk '{print $1}'
}

#
# Compare a version with another, true if $1 >= $2
#

compare_version() {
	[[ $(echo -e "$1\n$2" | sort -V | head -1) == "$1" ]] && return 1 || return 0
}

#
# A list of all Ansible versions >= min_ansible_version
#

ansible_versions_to_test_with() {
	mav=$(min_ansible_version)
	for v in $(ansible_versions); do
		if compare_version $v $mav; then
			echo $v
		fi
	done | sort
}

#
# Setup a LXD container
#

setup_containers() {
	for c in $(platforms); do
		name=$(echo $c | tr A-Z a-z | sed -e 's/[^a-z0-9]/-/g')
		if ! sudo lxc list | grep -q $name; then
			message "Setup $name with image $c"
			sudo lxc launch $c $name
			while ! sudo lxc list | grep $name | grep -q eth0; do
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
			sudo lxc exec $name -- chkconfig sshd on || :
			sudo lxc stop $name
			sudo lxc snapshot $name ${name}-snap
		else
			message "Container $name already running"
		fi
	done
}

#
# This step will stop, restore from snapshot, start containers
#

restore_containers() {
	for c in $(platforms); do
		name=$(echo $c | tr A-Z a-z | sed -e 's/[^a-z0-9]/-/g')
		message "Restore container $name"
		sudo lxc stop -f $name || :
		sudo lxc restore $name ${name}-snap
		sudo lxc start $name
		while ! sudo lxc list | grep $name | grep -q eth0; do
			sleep 1
		done
	done
}

#
# Generate a inventory from running LXD containers
# Make a backup if inventory.ini exists
#

inventoryini() {
	test -e inventory.ini && mv inventory.ini{,.org}
	sudo lxc list | awk '/RUNNING/{ print $2" ansible_host="$6" ansible_ssh_host="$6 }' > inventory.ini
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
		ansible-playbook \
			-i inventory.ini \
			--syntax-check \
			tests/$1.yml

		message "Run play in step $1"
		ansible-playbook \
			-i inventory.ini \
			--private-key=ssh-key \
			-u root \
			tests/$1.yml
	else
		message "Skipping step $1"
	fi
}

if [[ $1 == install ]]; then
	message "Start Ansible Role Tester ($0): Install mode"; ansiblecfg
	message "Install packages"; prep_packages
	message "Generate ssh keys"; gensshkeys
	message "Setup containers"; setup_containers
	message "Containers"; sudo lxc list

	for ver in $(ansible_versions_to_test_with); do
		message "Install Ansible version $ver"
		ansible_version $ver 2>&1 > ansible-install.out || cat ansible-install.out
	done
else
	message "Start Ansible Role Tester ($0): Test mode";
	message "meta/main.yml tells us that Ansible $(min_ansible_version) or newer is supported."

	for ver in $(ansible_versions_to_test_with); do
		message "Test with Ansible version $ver"
		restore_containers
		message "Generate inventory.ini"; inventoryini; cat inventory.ini
		ansible_version $ver
		step pre
		step main
		message "Test for role idempotence"
		step main | tee out.log; grep 'changed=0.*failed=0' out.log
		step post
	done
fi
