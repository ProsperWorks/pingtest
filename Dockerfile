#
# Describes a Docker image which runs pingtest.sh to a known resource.
#
# author: jhw@prosperworks.com
# incept: 2018-09-13

# memtier_benchmark stuff borrowed liberally from:
#
#   https://github.com/RedisLabs/memtier_benchmark/blob/master/Dockerfile
#
FROM ubuntu:16.04 as builder
RUN apt-get update -y
RUN apt-get install -yy build-essential autoconf automake libpcre3-dev
RUN apt-get install -yy libevent-dev pkg-config zlib1g-dev git
RUN apt-get install -yy libboost-all-dev cmake flex
RUN git clone https://github.com/RedisLabs/memtier_benchmark.git
WORKDIR /memtier_benchmark
RUN autoreconf -ivf && ./configure && make && make install

FROM ubuntu:16.04

COPY --from=builder /usr/local/bin/memtier_benchmark /usr/local/bin/memtier_benchmark
RUN apt-get update -y
RUN apt-get install -yy libevent-dev

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

RUN set -ex                                                              && \
    apt-get install -y pv cpipe

COPY pingtest.sh ./pingtest.sh
ENV  PATH="$PATH:."
