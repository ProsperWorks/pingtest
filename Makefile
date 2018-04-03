#
# Makefile to drive the pingtest.
#
# author: jhw@prosperworks.com
# incept: 2018-04-02
#

.SUFFIXES:
SHELL   := bash
DESTDIR := build

# Runs pingtest.sh on all the environments and reports summary
# analysis for each.
#
.PHONY: all
all:
	@echo all done

# Sets up some test nodes.
#
.PHONY: setup
setup:
	@echo setup done

.PHONY: clean
clean:
	rm -rf $(DESTDIR)

# Run pingtest.sh locally against ali-integration's services.
#
.PHONY: local
all: local
local: $(DESTDIR)/local.out
	cat $< | ./analyze.awk
$(DESTDIR)/local.out:
	@mkdir -p $(dir $@)
	env REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL` POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL` ./pingtest.sh | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest natively in ali-integration.
#
.PHONY: ali-integration
all: ali-integration
ali-integration: $(DESTDIR)/ali-integration.out
	cat $< | ./analyze.awk
$(DESTDIR)/ali-integration.out:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Standard-2X --app ali-integration -- bash - | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh in onebox-pw but against ali-integrations's services
# on a Standard-1X or on a Performance-L.
#
.PHONY: onebox-pw-1x
all: onebox-pw-1x
onebox-pw-1x: $(DESTDIR)/onebox-pw-1x.out
	cat $< | ./analyze.awk
$(DESTDIR)/onebox-pw-1x.out:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Standard-1X --app onebox-pw --env "REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL`;POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL`" -- bash - | tee $@.tmp
	@mv $@.tmp $@
.PHONY: onebox-pw-l
all: onebox-pw-l
onebox-pw-l: $(DESTDIR)/onebox-pw-l.out
	cat $< | ./analyze.awk
$(DESTDIR)/onebox-pw-l.out:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Performance-L --app onebox-pw --env "REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL`;POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL`" -- bash - | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh on an EC2 us-east-1a instance under account
# 5846-3632-4655, with ali-integration services.
#
#   https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:search=i-01471136efe3726ce;sort=desc:dnsName
#
# This is a Ubuntu instance on which I ran:
#
#  echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' | sudo tee -a /etc/apt/sources.list.d/pgdg.list
#  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
#  sudo apt-get update
#  sudo apt-get install -y postgresql-10
#  sudo apt-get install -y build-essential tcl
#  wget http://download.redis.io/releases/redis-4.0.9.tar.gz
#  tar xvzf redis-4.0.9.tar.gz
#  make -C redis-4.0.9 -j 5 && sudo make -C redis-4.0.9 install
#
# ./pingtest.sh needs redis-cli 4.0.3 or higher and psql 9.6 or higher.
#
.PHONY: jhw-ec2
all: jhw-ec2
jhw-ec2: $(DESTDIR)/jhw-ec2
	cat $< | ./analyze.awk
$(DESTDIR)/jhw-ec2:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | ssh -i ~/.ssh/jhw-temp-instance-aaapem.pem ubuntu@ec2-54-164-201-17.compute-1.amazonaws.com "env REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL` POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL` bash -" | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh on GCP instances, connecting to ali-integration services.
#
#   https://console.cloud.google.com/compute/instances?project=industrial-joy-526
#
# These are 4 vCPU 15 GB RAM Debian GNU/Linux 9 instances, initialized
# as per "make setup".
#
# ./pingtest.sh needs redis-cli 4.0.3 or higher and psql 9.6 or higher.
#
# GCP_TEST expects $1 to be a pretty name and $2 to be a matched IP
# address or host name.
#
define GCP_TEST
.PHONY: jhw-gcp-$1
all: jhw-gcp-$1
jhw-gcp-$1: $(DESTDIR)/jhw-gcp/$1
	cat $$< | ./analyze.awk
$(DESTDIR)/jhw-gcp/$1: $(DESTDIR)/setup/$1
	@mkdir -p $$(dir $$@)
	set -o pipefail ; cat pingtest.sh | ssh -i ~/.ssh/id_rsa $2 "env REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL` POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL` bash -" | tee $$@.tmp
	@mv $$@.tmp $$@
.PHONY: setup-$1
setup: setup-$1
setup-$1: $(DESTDIR)/setup/$1
$(DESTDIR)/setup/$1:
	@mkdir -p $$(dir $$@)
	ssh -i ~/.ssh/id_rsa $2 "sudo apt-get install -y postgresql build-essential tcl && rm -rf redis-4.0.9* && wget http://download.redis.io/releases/redis-4.0.9.tar.gz && tar xvzf redis-4.0.9.tar.gz && make -C redis-4.0.9 -j 5 && sudo make -C redis-4.0.9 install"
	@touch $$@
.PHONY: hostname-$1
hostname: hostname-$1
hostname-$1:
	ssh -i ~/.ssh/id_rsa $2 hostname
endef
$(eval $(call GCP_TEST,us-east4-a,35.188.225.101))
$(eval $(call GCP_TEST,us-central1-f,104.154.255.179))
$(eval $(call GCP_TEST,us-west1-c,35.197.56.181))
$(eval $(call GCP_TEST,europe-west1-d,130.211.108.218))
$(eval $(call GCP_TEST,australia-southeast1-a,35.189.2.112))
