# Ansible Role Tester

Tests are awesome, especially to catch regressions. I have used Vagrant for this before but there are no good (and easy) way to test it together or with Travis. I also like to keep the project clean from most of the test logic so I created this ...

At a minimum you need a file called `tests/main.yml` that installs the role. After that execute `test.sh` or `lxc_test.sh`.

## Use LXC (Recommended)

Just use `lxc/lxc_test.sh` from this repo, it will use the distribution templates. To start two ubuntu trusty containers call it like:

```
./lxc_test.sh 2 "ubuntu -- -r trusty --packages=python,python-simplejson"
```

[Example from ansible-graphite](https://github.com/nsg/ansible-graphite/blob/master/.travis.yml)

## Docker

The Docker source images are inside `images/`, use `test.sh` to use them from your role. This works but may cause problems with some roles.

[Example from ansible-graphite commit 61bcfe8](https://github.com/nsg/ansible-graphite/blob/61bcfe8db8bee3612a6297657f6799ede2be6a33/.travis.yml)