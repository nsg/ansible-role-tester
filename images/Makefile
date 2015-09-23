PREFIX = nsgb/ansible-test

all: build tag push
	:

build:
	docker build -t ${PREFIX}-ubuntu:1404 -f Dockerfile-ubuntu1404 .
	docker build -t ${PREFIX}-debian:7 -f Dockerfile-debian7 .
	docker build -t ${PREFIX}-centos:6 -f Dockerfile-centos6 .

tag:
	docker tag -f ${PREFIX}-ubuntu:1404 nsgb/ansible-test-ubuntu:latest
	docker tag -f ${PREFIX}-debian:7 nsgb/ansible-test-debian:latest
	docker tag -f ${PREFIX}-centos:6 nsgb/ansible-test-centos:latest

push:
	docker push ${PREFIX}-ubuntu:1404
	docker push ${PREFIX}-ubuntu:latest
	docker push ${PREFIX}-debian:7
	docker push ${PREFIX}-debian:latest
	docker push ${PREFIX}-centos:6
	docker push ${PREFIX}-centos:latest
