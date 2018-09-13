#
# Describes a Docker image which runs pingtest.sh to a known resource.
#
# author: jhw@prosperworks.com
# incept: 2018-09-13

FROM ubuntu:16.04

RUN set -ex                                                              && \
    apt-get update -y                                                    && \
    apt-get install -y wget                                              && \
    echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main'    \
      | tee -a /etc/apt/sources.list.d/pgdg.list                         && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc    \
      | apt-key add -                                                    && \
    apt-get update -y                                                    && \
    apt-get install -y postgresql-10 build-essential tcl                 && \
    wget http://download.redis.io/releases/redis-4.0.9.tar.gz            && \
    sha256sum redis-4.0.9.tar.gz | grep df4f73bc318e2f9ffb2d169a922dec   && \
    tar xvzf redis-4.0.9.tar.gz                                          && \
    make -C redis-4.0.9 -j 5                                             && \
    make -C redis-4.0.9 install                                          && \
    rm -rf redis-4.0.9.tar.gz redis-4.0.9

COPY pingtest.sh ./pingtest.sh
ENV  PATH="$PATH:."
