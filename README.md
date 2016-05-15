# Ansible Role Tester

Tests are awesome, especially to catch regressions. I have used Vagrant for this before but there are no good (and easy) way to test it together or with Travis. I also like to keep the project clean from most of the test logic so I created this ...

At a minimum you need a directory called `tests` inside your role. After that execute `test.sh` or `lxc_test.sh`.

## Use LXC (Recommended)

Just use `lxc/lxc_test.sh` from this repo, it will use the distribution templates. To start two ubuntu trusty containers call it like:

```
./lxc_test.sh 2 "ubuntu -- -r trusty --packages=python,python-simplejson"
```

[Example from ansible-graphite](https://github.com/nsg/ansible-graphite/blob/master/.travis.yml)

## Docker

Before LXC I used Docker for this, it's a litte tricky with systemd so I moved on. But for some usecases Docker can still be useful so I have kept the files for that here.

The Docker source images are inside `images/`, use `test/test.sh` to use them from your role. This works but may cause problems with some roles.

For an [example see commit 61bcfe8 from ansible-graphite](https://github.com/nsg/ansible-graphite/blob/61bcfe8db8bee3612a6297657f6799ede2be6a33/.travis.yml). I used this to test Debian 7/8, Ubuntu 14.04 and CentOS 6/7.

## The directory tests/

### main.yml
The main file, this is the only required file. This file is supposed to install your role.

### pre.yml
Prepare the environment _before_ the role is installed. For example if the test environment is not equal to your target distribution you can use this role to normalize the installation.

### post.yml
This is a good place for tests that verifies that the install was successful, check urls, logs, and so on ...

## Order of execution

* pre.yml
* main.yml
* main.yml (verify idempotence, this must cause 0 changes)
* post.yml
