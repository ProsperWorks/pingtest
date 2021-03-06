#
# Makefile to drive the pingtest.
#
# author: jhw@prosperworks.com
# incept: 2018-04-02
#

.SUFFIXES:
SHELL   := bash
DESTDIR := build

# Test resources.
#
# I created some test resources like so:
#
#   $ heroku apps:create --app jhw-pingtest --org prosperworks
#   $ heroku addons:create --app jhw-pingtest heroku-postgresql:standard-0
#   $ heroku addons:create --app jhw-pingtest rediscloud:30
#
# I waited a bit for the resources to spin up, then I got target URLs
# like so:
#
#   $ heroku config:get --app jhw-pingtest DATABASE_URL    # as POSTGRES_URL
#   $ heroku config:get --app jhw-pingtest REDISCLOUD_URL  # as REDIS_URL
#
# PINGTEST_POSTGRES_URL and PINGTEST_REDIS_URL are expected to be set
# in the environment as per those commands.  The values themselves
# have been left out of this Makefile and out of this project to avoid
# leaking secrets through GitHub.
#
# Still, after we are done testing today (2018-09-13) I should clean
# up with:
#
#   $ heroku apps:destroy --app jhw-pingtest --confirm jhw-pingtest
#
# We will create VMs and containers and dynos in a variety of clouds
# and run pingtest.sh to communicate with these resources.
#
POSTGRES_URL := $(PINGTEST_POSTGRES_URL)
REDIS_URL    := $(PINGTEST_REDIS_URL)

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
	@echo $@ happy

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

# Run pingtest.sh locally.
#
.PHONY: pingtest-local
pintest: pingtest-local
pingtest-local: $(DESTDIR)/pingtest/local
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/local:
	@mkdir -p $(dir $@)
	env REDIS_URL=$(REDIS_URL) POSTGRES_URL=$(POSTGRES_URL) ./pingtest.sh | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh in a Docker container locally.
#
.PHONY: pingtest-docker
pintest: pingtest-docker
pingtest-docker: $(DESTDIR)/pingtest/docker
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/docker: Dockerfile ./pingtest.sh
	@mkdir -p $(dir $@)
	time -p docker build . --tag pingtest:latest
	set -o pipefail ; docker run --rm --env REDIS_URL=$(REDIS_URL) --env POSTGRES_URL=$(POSTGRES_URL) pingtest:latest pingtest.sh | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh in onebox-pw on a Standard-1X or a Performance-L.
#
.PHONY: pingtest-onebox-pw-1x
pingtest: pingtest-onebox-pw-1x
pingtest-onebox-pw-1x: $(DESTDIR)/pingtest/onebox-pw-1x
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/onebox-pw-1x:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Standard-1X --app onebox-pw --env "REDIS_URL=$(REDIS_URL);POSTGRES_URL=$(POSTGRES_URL)" -- bash - | tee $@.tmp
	@mv $@.tmp $@
.PHONY: pingtest-onebox-pw-l
pingtest: pingtest-onebox-pw-l
pingtest-onebox-pw-l: $(DESTDIR)/pingtest/onebox-pw-l
	cat $< | ./analyze.awk
$(DESTDIR)/pingtest/onebox-pw-l:
	@mkdir -p $(dir $@)
	set -o pipefail ; cat pingtest.sh | heroku run --no-tty --exit-code --size Performance-L --app onebox-pw --env "REDIS_URL=$(REDIS_URL);POSTGRES_URL=$(POSTGRES_URL)" -- bash - | tee $@.tmp
	@mv $@.tmp $@

# Run pingtest.sh on an EC2s instances under account
# prosperworks-sandbox (726992017616).
#
#   https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:search=i-01471136efe3726ce;sort=desc:dnsName
#
# These are m4.xlarge or m5.xlarge (4 vCPU 16 GB RAM) Ubuntu Server
# 16.04 LTS instances, initialized as per "make setup".
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
	@mkdir -p $$(dir $$@)
	set -o pipefail ; cat pingtest.sh | ssh -i $3 ubuntu@$2 "env REDIS_URL=$(REDIS_URL) POSTGRES_URL=$(POSTGRES_URL) bash -" | tee $$@.tmp
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
hostname-ec2-$1:
	ssh -i $3 ubuntu@$2 hostname
endef
$(eval $(call EC2_TEST,jhw-pingtest-aws-us-east-1,ec2-34-205-18-34.compute-1.amazonaws.com,~/.ssh/jhw-pingtest.pem))
$(eval $(call EC2_TEST,jhw-pingtest-aws-us-west-1,ec2-54-183-146-90.us-west-1.compute.amazonaws.com,~/.ssh/jhw-pingtest-us-west-1pem.pem))

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
	set -o pipefail ; cat pingtest.sh | ssh -i $3 $2 "env REDIS_URL=$(REDIS_URL) POSTGRES_URL=$(POSTGRES_URL) bash -" | tee $$@.tmp
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
$(eval $(call GCP_TEST,jhw-pingtest-gcp-us-east1,35.229.16.35,~/.ssh/id_rsa))
$(eval $(call GCP_TEST,jhw-pingtest-gcp-us-east4,35.230.160.36,~/.ssh/id_rsa))
