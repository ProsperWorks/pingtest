#
# Makefile to drive the pingtest.
#
# author: jhw@prosperworks.com
# incept: 2018-04-02
#

.SUFFIXES:
SHELL   := bash
DESTDIR := build

# 'make all' does it all.
#
# 'make hostname' does a quick ssh into each node.  This is
# recommended for acknowledging all the key fingerprints for new nodes
# and testing connectivity, nothing more.
#
# 'make setup -j' installs all the necessary software on all nodes.
#
# 'make pingtest -j && make pingtest' performs the test and prints out
# a summary.
#
.PHONY: all pingtest setup hostname
all: pingtest setup
all pingtest setup hostname:
	@echo $@ done

# 'make clean' purges all state, resets the project.
#
.PHONY: clean
clean:
	rm -rf $(DESTDIR)

# 'make cleantests' resets the tests, but does not purge the setup.
#
.PHONY: cleantests
cleantests:
	rm -rf $(DESTDIR)/pingtest

# Run pingtest.sh locally against ali-integration's services.
#
.PHONY: pingtest-local
pintest: pingtest-local
pingtest-local: $(DESTDIR)/pingtest/local
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/local:
	@mkdir -p $(dir $@)
	env REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL` POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL` ./pingtest.sh | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest natively in ali-integration.
#
.PHONY: pingtest-ali-integration
pingtest: pingtest-ali-integration
pingtest-ali-integration: $(DESTDIR)/pingtest/ali-integration
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/ali-integration:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Standard-2X --app ali-integration -- bash - | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh in onebox-pw but against ali-integrations's services
# on a Standard-1X or on a Performance-L.
#
.PHONY: pingtest-onebox-pw-1x
pingtest: pingtest-onebox-pw-1x
pingtest-onebox-pw-1x: $(DESTDIR)/pingtest/onebox-pw-1x
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/onebox-pw-1x:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Standard-1X --app onebox-pw --env "REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL`;POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL`" -- bash - | tee $@.tmp
	@mv $@.tmp $@
.PHONY: pingtest-onebox-pw-l
pingtest: pingtest-onebox-pw-l
pingtest-onebox-pw-l: $(DESTDIR)/pingtest/onebox-pw-l
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/onebox-pw-l:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Performance-L --app onebox-pw --env "REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL`;POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL`" -- bash - | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh on an EC2s instances under account 5846-3632-4655,
# with ali-integration services.
#
#   https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:search=i-01471136efe3726ce;sort=desc:dnsName
#
# These are 4 vCPU 16 GB RAM Ubuntu Server 16.04 LTS instances,
# initialized as per "make setup".
#
# ./pingtest.sh needs redis-cli 4.0.3 or higher and psql 9.6 or higher.
#
# EC2_TEST expects $1 to be a pretty name, $2 a matched IP address or
# host name, and $3 an ssh identity file.
#
define EC2_TEST
.PHONY: pingtest-ec2-$1
pingtest: pingtest-ec2-$1
pingtest-ec2-$1: $(DESTDIR)/pingtest/ec2/$1
	cat $$< | ./analyze.awk
$(DESTDIR)/pingtest/ec2/$1: $(DESTDIR)/setup/ec2/$1
n	@mkdir -p $$(dir $$@)
	set -o pipefail ; cat pingtest.sh | ssh -i $3 ubuntu@$2 "env REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL` POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL` bash -" | tee $$@.tmp
	@mv $$@.tmp $$@
.PHONY: setup-ec2-$1
setup: setup-ec2-$1
setup-ec2-$1: $(DESTDIR)/setup/ec2/$1
$(DESTDIR)/setup/ec2/$1:
	@mkdir -p $$(dir $$@)
	ssh -i $3 ubuntu@$2 "echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' | sudo tee -a /etc/apt/sources.list.d/pgdg.list && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get install -y postgresql-10 build-essential tcl && rm -rf redis-4.0.9* && wget http://download.redis.io/releases/redis-4.0.9.tar.gz && tar xvzf redis-4.0.9.tar.gz && make -C redis-4.0.9 -j 5 && sudo make -C redis-4.0.9 install"
	@touch $$@
.PHONY: hostname-ec2-$1
hostname: hostname-ec2-$1
hostname-$1:
	ssh -i $3 ubuntu@$2 hostname
endef
$(eval $(call EC2_TEST,us-east-1a,ec2-54-164-201-17.compute-1.amazonaws.com,~/.ssh/jhw-temp-instance-aaapem.pem))
$(eval $(call EC2_TEST,us-west-1b,ec2-18-144-40-232.us-west-1.compute.amazonaws.com,~/.ssh/jhw-temp-west.pem))
$(eval $(call EC2_TEST,ap-northeast-1a,13.231.164.243,~/.ssh/jhw-ap-northeast-1.pem))
$(eval $(call EC2_TEST,eu-west-1,52.19.236.61,~/.ssh/jhw-eu-west-1.pem))

# Run pingtest.sh on GCP instances, connecting to ali-integration services.
#
#   https://console.cloud.google.com/compute/instances?project=industrial-joy-526
#
# These are 4 vCPU 15 GB RAM Debian GNU/Linux 9 instances, initialized
# as per "make setup".
#
# ./pingtest.sh needs redis-cli 4.0.3 or higher and psql 9.6 or higher.
#
# GCP_TEST expects $1 to be a pretty name, $2 a matched IP address or
# host name, and $3 an ssh identity file.
#
define GCP_TEST
.PHONY: pingtest-gcp-$1
pingtest: pingtest-gcp-$1
pingtest-gcp-$1: $(DESTDIR)/pingtest/gcp/$1
	cat $$< | ./analyze.awk
$(DESTDIR)/pingtest/gcp/$1: $(DESTDIR)/setup/gcp/$1
	@mkdir -p $$(dir $$@)
	set -o pipefail ; cat pingtest.sh | ssh -i $3 $2 "env REDIS_URL=`heroku config:get --app ali-integration REDISCLOUD_URL` POSTGRES_URL=`heroku config:get --app ali-integration DATABASE_URL` bash -" | tee $$@.tmp
	@mv $$@.tmp $$@
.PHONY: setup-gcp-$1
setup: setup-gcp-$1
setup-gcp-$1: $(DESTDIR)/setup/gcp/$1
$(DESTDIR)/setup/gcp/$1:
	@mkdir -p $$(dir $$@)
	ssh -i $3 $2 "sudo apt-get update && sudo apt-get install -y postgresql build-essential tcl && rm -rf redis-4.0.9* && wget http://download.redis.io/releases/redis-4.0.9.tar.gz && tar xvzf redis-4.0.9.tar.gz && make -C redis-4.0.9 -j 5 && sudo make -C redis-4.0.9 install"
	@touch $$@
.PHONY: hostname-gcp-$1
hostname: hostname-gcp-$1
hostname-gcp-$1:
	ssh -i $3 $2 hostname
endef
$(eval $(call GCP_TEST,us-east4-a,35.188.225.101,~/.ssh/id_rsa))
$(eval $(call GCP_TEST,us-central1-f,104.154.255.179,~/.ssh/id_rsa))
$(eval $(call GCP_TEST,us-west1-c,35.197.56.181,~/.ssh/id_rsa))
$(eval $(call GCP_TEST,europe-west1-d,130.211.108.218,~/.ssh/id_rsa))
$(eval $(call GCP_TEST,australia-southeast1-a,35.189.2.112,~/.ssh/id_rsa))
