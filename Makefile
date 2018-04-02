#
# Makefile to drive the pingtest.
#
# author: jhw@prosperworks.com
# incept: 2018-04-02
#

.SUFFIXES:
SHELL   := bash
DESTDIR := build

.PHONY: all
all:
	echo not implemented
	false


.PHONY: clean
clean:
	rm -rf $(DESTDIR)

.PHONY: peek
peek:
	docker images | sort -n | grep -v '^<'

.PHONY: gc
gc: clean
	docker container ls --all --quiet | xargs docker rm

.PHONY: prune # soft purge of all volumes not used by a container
prune: clean
	docker volume prune

.PHONY: sweep # soft purge of all dead containers and dangling images
sweep: clean
	docker ps -q -f 'status=exited' | xargs docker rm
	docker images -q -f 'dangling=true' | xargs docker rmi

.PHONY: purge # hard purge of all local docker containers and images
purge: clean gc sweep prune
	docker images -q | xargs docker rmi
