#
# pingtest.sh
#
# Measures latency to PG and Redis services.
#
# author: jhw@prosperworks.com
# incept: 2018-04-02
#

set -euo pipefail

# Measure time to Redis, if redis-cli is installed at suitable version
# and REDIS_URL or REDISCLOUD_URL is defined.
#
if [[ -z "${REDIS_URL:-${REDISCLOUD_URL:-}}" ]]
then
    echo "no REDIS_URL or REDISCLOUD_URL"
elif [[ ! -x `which redis-cli` ]]
then
    echo "redis-cli is not found or not an executable: `which redis-cli`"
elif ! redis-cli --version | grep -e 'redis.* 3' -e 'redis.* 4'
then
    echo "`which redis-cli`: improper version"
else
    for i in `seq 1 10`
    do
        redis-cli -u "${REDIS_URL:-${REDISCLOUD_URL:-}}" --latency --raw | awk '{print "redis:",$0}'
    done
fi
