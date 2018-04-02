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

# Run pingtest.sh against ALI-style local development services.
#
.PHONY: local
local: $(DESTDIR)/local.out
$(DESTDIR)/local.out:
	@mkdir -p $(dir $@)
	env REDIS_URL=redis://localhost:7379 POSTGRES_URL=postgres://localhost:9750/crm_dev ./pingtest.sh | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest natively in ali-integration.
#
.PHONY: ali-integration
ali-integration: $(DESTDIR)/ali-integration.out
$(DESTDIR)/ali-integration.out:
	@mkdir -p $(dir $@)
	cat pingtest.sh | heroku run --no-tty --exit-code --size Standard-2X --app ali-integration -- bash - | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh in onebox-pw but against ali-integrations's services
# on a Standard-1X or on a Performance-L.
#
.PHONY: onebox-pw-1x
onebox-pw-1x: $(DESTDIR)/onebox-pw-1x.out
$(DESTDIR)/onebox-pw-1x.out:
	@mkdir -p $(dir $@)
	cat pingtest.sh | heroku run --no-tty --exit-code --size Standard-1X --app onebox-pw --env "REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL`;POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL`" -- bash - | tee $@.tmp
	@mv $@.tmp $@
.PHONY: onebox-pw-l
onebox-pw-l: $(DESTDIR)/onebox-pw-l.out
$(DESTDIR)/onebox-pw-l.out:
	@mkdir -p $(dir $@)
	cat pingtest.sh | heroku run --no-tty --exit-code --size Performance-L --app onebox-pw --env "REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL`;POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL`" -- bash - | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh on ali-jenkins but against ali-integrations's
# services.
#
.PHONY: ali-jenkins
ali-jenkins:
	@mkdir -p $(dir $@)
	false # TODO
	@mv $@.tmp $@

.PHONY: analyze
analyze: $(DESTDIR)/local.out
analyze: $(DESTDIR)/ali-integration.out
analyze: $(DESTDIR)/onebox-pw-1x.out
analyze: $(DESTDIR)/onebox-pw-l.out
	@ls -l $^
	grep '^redis: ' $(sort $^)
	grep 'avg latency' $(sort $^)
	grep '^postgres_3: ' $(sort $^)
