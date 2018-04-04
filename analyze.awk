#!/usr/bin/env awk -f
#
# Parses the output of ./pingtest.sh to average up all the numbers
# nice and pretty.
#
BEGIN { 
    redis_sum   = 0.0
    redis_num   = 0
    pg_sum      = 0.0
    pg_num      = 0
    kernel_ave  = 0.0
    kernel_unit = "unknown"
}
{
    if ($0 ~ /^redis: /) {
        redis_sum += $4 * $5
        redis_num += $5
    }
    else if ($0 ~ /^postgres_3: /) {
        pg_sum    += $2
        pg_num    +=  1
    }
    else if ($0 ~ /total runs/) {
        kernel_ave  = $6
        kernel_unit = $7
    }
}
END {
    if (0 == pg_num) {
        printf "  pg_ave:     NO DATA!\n"
    }
    else {
        printf "  pg_ave:     %7.4f milliseconds\n",(pg_sum/pg_num)
    }
    if (0 == redis_num) {
        printf "  redis_ave:  NO DATA!\n"
    }
    else {
        printf "  redis_ave:  %7.4f milliseconds\n",(redis_sum/redis_num)
    }
    if ("unknown" == kernel_unit) {
        printf "  kernel_ave: NO DATA!\n"
    }
    else {
        printf "  kernel_ave: %7.4f %s\n",kernel_ave,kernel_unit
    }

}
