# Ansible Role Tester

## History

I wrote this script to test my Ansible Role [ansible-graphite](https://github.com/nsg/ansible-graphite/). I started off by using vangrant for local testing but soon I liked the idea with Travis CI for automatic tests.

The first implementation used Docker to spin up different containers with Ubuntu, CentOS and so on. The problem was that Systemd failed to work properly inside Docker and I had to do a lot of hacky workarounds. Later on I tinkered with the possibility to use LXC but never got networking working properly, the Travis build environment is annoying to debug.

Since then, LXD was backported to Ubuntu 14.04 and it works!

## How to use

Everything you need is the script `test.sh` here, it will install a few dependencies and assumes that you run it under Travis "new" trusty based infrastructure.

The script assumes that:

* You are testing an Ansible role
* That you have specified the env `CONTAINER_IMAGES` and `ANSIBLE_VERSIONS`.
* There is a folder called `tests/` with a file called `main.yml` that installs the role. Actual tests can be done in `post.yml`, and possible setup tasks can be done in 'pre.yml`.

First you need to prepare the build environment, do that by executing `./test.sh install`. This step will install packages, configure lxd, install containers and all Ansible versions.

The actual tests are then run by executing `./test.sh test`.

### Note

The install step installes the containers so with the following configuration:

    - CONTAINER_IMAGES="images:centos/7"
    - ANSIBLE_VERSIONS="2.1.6 latest"

The execusion order is:

* Install centos 7 container
* Run the tests with Ansible 2.1.6
* Run the tests against the same container with latest

The first test run has probably changed the state of the container with makes the 2nd test less useful. This maxtrix build will not have this problem:

    - CONTAINER_IMAGES="images:centos/7"
    - ANSIBLE_VERSIONS="2.1.6"
    - ANSIBLE_VERSIONS="latest"

You can also specify multiple versions of CONTAINER_IMAGES if you like. The syntax for the images are images:$DIST/$VERSION, for Ubuntu ubuntu:$VERSION also works.

## Example

[Live Example](https://github.com/nsg/ansible-graphite/blob/master/.travis.yml)

    ---

    sudo: required
    dist: trusty

    env:
      - CONTAINER_IMAGES="images:centos/7"
      - CONTAINER_IMAGES="ubuntu:16.04"
      - ANSIBLE_VERSIONS="2.1.6.0"
      - ANSIBLE_VERSIONS="2.2.3.0"
      - ANSIBLE_VERSIONS="latest"

    install:
      - ./test.sh install

    script:
      - ./test.sh test
