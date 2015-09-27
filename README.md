# Ansible Role Tester

Tests are awesome, especially to catch regressions. I have used
Vagrant for this before but there are no good (and easy) way to
test it together or with Travis. I also like to keep the project
clean from most of the test logic so I created this ...

At a minimum you need a file called `tests/main.yml` that install
the role. After that execute `test.sh` from this repo to download
everything you need. [Example from ansible-graphite](https://github.com/nsg/ansible-graphite/blob/master/.travis.yml)

## Images

The source Dockerfiles hosted at Docker Hub,

## Test

The test script.
