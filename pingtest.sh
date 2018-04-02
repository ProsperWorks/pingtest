#
# pingtest.sh
#
# Measures latency to PG and Redis services.
#
# author: jhw@prosperworks.com
# incept: 2018-04-02
#

set -euo pipefail

NUM_SAMPLES="3"

# Measure time to Redis, if redis-cli is installed at suitable version
# and REDIS_URL or REDISCLOUD_URL is defined.
#
# We use the latency tests which are built in to redis-cli.
#
# Emits something like:
#
#   redis-cli 4.0.6
#   redis: 0 1 0.25 87
#   redis: 0 1 0.15 86
#   redis: 0 1 0.19 89
#
# ...one line per second: min max ave num, with time measured in milliseconds.
#
# We also do a redis-cli --intrinsic-latency run, whose output looks like:
#
#   Max latency so far: 1 microseconds.
#   Max latency so far: 10 microseconds.
#   Max latency so far: 11 microseconds.
#   Max latency so far: 920 microseconds.
#   
#   54192982 total runs (avg latency: 0.0554 microseconds / 55.36 nanoseconds per run).
#   Worst run took 16619x longer than the average latency.
#
# These numbers measured on my local Mac, connecting to localhost.
#
if [[ -z "${REDIS_URL:-${REDISCLOUD_URL:-}}" ]]
then
    echo "no REDIS_URL or REDISCLOUD_URL"
elif [[ ! -x `which redis-cli` ]]
then
    echo "redis-cli is not found or not an executable: `which redis-cli`"
elif ! redis-cli --version | grep -e 'redis.* 4'
then
    #
    # We need version 4 for 'redis-cli --latency --raw' to behave the
    # way we want.
    #
    # Also, the delightful -u option was only added in redis-cli 4.0.3.
    #
    echo "`which redis-cli`: not version 4"
else
    for i in `seq 1 $NUM_SAMPLES`
    do
        redis-cli -u "${REDIS_URL:-${REDISCLOUD_URL:-}}" --latency --raw | awk '{print "redis:",$0}'
    done
    redis-cli --intrinsic-latency 3
fi

# Measure time to Postgres, if psql is installed at suitable version
# and POSTGRES_URL is defined.
#
# We use '\d timing' together with five 'SELECT 1' statements.
#
# Emits something like:
#
#   psql (PostgreSQL) 10.1
#   postgres_1:  0.606 ms
#   postgres_2:  0.171 ms
#   postgres_3:  0.143 ms
#   postgres_4:  0.140 ms
#   postgres_5:  0.134 ms
#   postgres_1:  0.597 ms
#   postgres_2:  0.160 ms
#   postgres_3:  0.129 ms
#   postgres_4:  0.186 ms
#   postgres_5:  0.151 ms
#
# These numbers measured on my local Mac, connecting to localhost.
#
# I have noticed that the first of each group of 5 can take over 0.5
# ms even running against local host where the subsequent SELECT take
# only 0.1 ms, so the output includes the sample-number-per-execution
# so we can filter if desired.
#
#
if [[ -z "${POSTGRES_URL:-${DATABASE_URL_NO_PGBOUNCER:-${DATABASE_URL:-}}}" ]]
then
    echo "no POSTGRES_URL or DATABASE_URL_NO_PGBOUNCER or DATABASE_URL"
elif [[ ! -x `which psql` ]]
then
    echo "psql is not found or not an executable: `which psql`"
elif ! psql --version | grep -e 'psql.* 9\.6' -e 'psql.* 10\.'
then
    echo "`which psql`: improper version"
else
    for i in `seq 1 $NUM_SAMPLES`
    do
        psql "${POSTGRES_URL:-${DATABASE_URL_NO_PGBOUNCER:-${DATABASE_URL:-}}}" -c '\timing on' -c 'SELECT 1' -c 'SELECT 1' -c 'SELECT 1' -c 'SELECT 1' -c 'SELECT 1' 2>&1| grep Time: | sed -e 's/^Time://g' | awk '{printf "postgres_%d: %s\n",NR,$0}'
        sleep 1
    done
fi
