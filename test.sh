#!/bin/bash -e

#
# Print a yellow info message to stdout
#

message() {
	echo -e "\e[33m# $@\e[0m"
}

fold() {
  local state="$1"; shift
  local name="$@"

  if [ x$state == xstart ]; then
    echo "travis_fold:start:$name"
  else
    echo "travis_fold:end:$name"
  fi
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
	fold start install_snapd_and_lxd
	sudo apt-get -qq update
	install_package snapd
	sudo snap install lxd
	while [ ! -S /var/snap/lxd/common/lxd/unix.socket ]; do
		echo "Waiting for LXD socket...";
		sleep 1;
	done;
	export PATH=$PATH:/snap/bin
	sudo lxd init --auto --storage-backend=dir || :
	sudo lxc network create testbr0
	sudo lxc network attach-profile testbr0 default eth0
	fold end install_snapd_and_lxd

	fold start install_ansible_deps
	install_package python-dev
	install_package python-virtualenv
	install_package libssl-dev
	install_package libffi-dev
	install_package gcc
	install_pip pyyaml
	fold end install_ansible_deps
}

#
# Setup a env with a specific version of Ansible.
# If the env is already there, just activate it.
#

ansible_version() {
	if [ ! -e .env_$1 ]; then
		fold start ansible_env_$1
		message "Setup a virtualenv for Ansible $1"
		virtualenv .env_$1
		. .env_$1/bin/activate
		if [[ $1 == latest ]]; then
			pip install ansible
		else
			pip install ansible==$1
		fi
		fold end ansible_env_$1
	else
		. .env_$1/bin/activate
	fi
}

#
# Run a LXC command at a running container
#
at_lxc() {
  local fold="$1"; shift
  local name="$1"; shift
  local cmd="$@"
  local slug="$(echo $cmd | sed 's/[^a-z0-9]/_/g')"

  [ x$fold == xfold ] && fold start $slug
  message $name - $cmd
  sudo lxc exec $name -- $cmd
  [ x$fold == xfold ] && fold end $slug
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

		message "Push script $0 to container $name"
		sudo lxc file push --uid=0 --gid=0 --mode=0755 $0 $name/root/test.sh

		message "Prepare the container $name"
		at_lxc fold $name /root/test.sh container

		message "Push ssh-key.pub to authorized_keys"
		sudo lxc file push --uid=0 --gid=0 --mode=0600 ssh-key.pub $name/root/.ssh/authorized_keys
	else
		message "Container $name already running"
	fi
}

#
# Install and prep container
#
prep_container() {
	# This is exectued _inside_ the container

	mkdir -p /root/.ssh
	chmod 700 /root/.ssh

	if grep -q '14.04' /etc/lsb-release; then
		apt-get install -y --no-install-recommends openssh-server python
	elif test -f /etc/debian_version; then
		if grep -qE '^8' /etc/debian_version; then
			# Workaround for "Could not enumerate links: Connection timed out"
			systemctl stop systemd-networkd
		fi
		apt-get install -y --no-install-recommends openssh-server python
		systemctl start ssh
	elif hostnamectl status | grep -q CentOS; then
		yum install -y openssh-server
		systemctl start sshd
	elif hostnamectl status | grep -q Fedora; then
		dnf install -y openssh-server python
		systemctl start sshd
	else
		hostnamectl status
	fi

	echo "Container prep complete"
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
	fold start gen-ssh-keys
	ssh-keygen -N "" -f ssh-key
	fold end gen-ssh-keys
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

# This step is only executed _inside_ the containers
if [[ $1 == container ]]; then
	prep_container
	exit 0
fi

export PATH=$PATH:/snap/bin

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
