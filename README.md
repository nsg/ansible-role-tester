# Ansible Role Tester

Tests are awesome, especially to catch regressions. I have used
Vagrant for this before but there are no good (and easy) way to
test it together or with Travis. I also like to keep the project
clean from most of the test logic so I created this ...

At a minimum you need a file called `tests/main.yml` that install the role. After that execute `test.sh` or `lxc_test.sh` from this repo to download everything you need. [Example from ansible-graphite](https://github.com/nsg/ansible-graphite/blob/master/.travis.yml)

## Use LXC (Recommended)

Just use `lxc/lxc_test.sh` from this repo, it will use the distribution templates. To start two ubuntu trusty containers call it like:

```
./lxc_test.sh 2 "ubuntu -- -r trusty --packages=python,python-simplejson"
```

## Docker

The Docker source images are inside `images/`, use `test.sh` to use them from your role. This works but may cause problems with some roles.