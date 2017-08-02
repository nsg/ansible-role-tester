# Ansible Role Tester

This repo contains a simple bash script for Ansible Role Testing.

At a minimum you need a file called `tests/main.yml` that install the role.
After that execute `test.sh` from this repo to download everything you need.

[Example from ansible-graphite](https://github.com/nsg/ansible-graphite/blob/master/.travis.yml)

## Example

    ---

    sudo: required
    dist: trusty

    install:
      - ./test.sh install

    script:
      - ./test.sh test
