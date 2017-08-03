# Ansible Role Tester

## History

I wrote this script to test my Ansible Role [ansible-graphite](https://github.com/nsg/ansible-graphite/). I started off by using vangrant for local testing but soon I liked the idea with Travis CI for automatic tests.

The first implementation used Docker to spin up different containers with Ubuntu, CentOS and so on. The problem was that Systemd fails to work properly inside Docker and I had to do a lot of hacky workarounds. Later on I tinkered with the possibility to use LXC but never got networking working properly, the Travis build environment is annoying to debug.

Since then, LXD was backported to Ubuntu 14.04 and it works!

## How to use

Everything you need is the script `test.sh` here, it will install a few dependencies and assumes that you run it under Travis "new" trusty based infrastructure.

The script assumes that:

* You are testing an Ansible role
* The role has a meta/main.yml file with at least `min_ansible_version`, `platforms` and `dependencies`.
* There is a folder called `tests/` with a file called `main.yml` that installs the role. Actual tests can be done in `post.yml`, and possible setup tasks can be done in 'pre.yml`.

First you need to prepare the build environment, do that by executing `./test.sh install`. This step will install packages, configure lxd, read `meta/main.yml` and install containers and all Ansible version after `min_ansible_version`.

The actual tests are then run by executing `./test.sh test`, this will provision all containers with the ordest supported version and run the tests. Restore the containers and try the next version and so on.

## Example

[Live Example](https://github.com/nsg/ansible-graphite/blob/master/.travis.yml)

    ---

    sudo: required
    dist: trusty

    install:
      - ./test.sh install

    script:
      - ./test.sh test
