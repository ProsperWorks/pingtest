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

.PHONY: clean
clean:
	rm -rf $(DESTDIR)

# Run pingtest.sh against ALI-style local development services.
#
.PHONY: local
all: local
local: $(DESTDIR)/local.out
	cat $< | ./analyze.awk
$(DESTDIR)/local.out:
	@mkdir -p $(dir $@)
	env REDIS_URL=redis://localhost:7379 POSTGRES_URL=postgres://localhost:9750/crm_dev ./pingtest.sh | tee $@.tmp
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

# Run pingtest.sh on an GCP us-east-4a instance with ali-integration services.
#
#   https://console.cloud.google.com/compute/instancesDetail/zones/us-east4-a/instances/instance-1?project=industrial-joy-526&graph=GCE_CPU&duration=PT1H
#
# This is a Debian instance on which I ran:
#
#  sudo apt-get install -y postgresql build-essential tcl
#  wget http://download.redis.io/releases/redis-4.0.9.tar.gz
#  tar xvzf redis-4.0.9.tar.gz
#  make -C redis-4.0.9 -j 5 && sudo make -C redis-4.0.9 install
#
# ./pingtest.sh needs redis-cli 4.0.3 or higher and psql 9.6 or higher.
#
.PHONY: jhw-gcp
all: jhw-gcp
jhw-gcp: $(DESTDIR)/jhw-gcp
	cat $< | ./analyze.awk
$(DESTDIR)/jhw-gcp:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | ssh -i ~/.ssh/id_rsa 35.188.225.101 "env REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL` POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL` bash -" | tee $@.tmp
	@mv $@.tmp $@
