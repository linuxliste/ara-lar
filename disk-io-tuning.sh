#!/bin/bash
echo 5         > /proc/sys/vm/dirty_background_ratio
echo 20        > /proc/sys/vm/dirty_ratio
echo 50        > /proc/sys/vm/vfs_cache_pressure
echo 262144    > /proc/sys/vm/min_free_kbytes
echo always    > /sys/kernel/mm/transparent_hugepage/enabled
echo always    > /sys/kernel/mm/transparent_hugepage/defrag
# echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
# echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag

for dev in dm-0 dm-1 dm-2 dm-3 dm-4
do
	echo  deadline   > /sys/block/$dev/queue/scheduler
	echo  4096       > /sys/block/$dev/queue/nr_requests
	echo  32768      > /sys/block/$dev/queue/read_ahead_kb
	echo  32768      > /sys/block/$dev/queue/max_sector_kb
done
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo 1 >  /proc/sys/vm/zone_reclaim_mode


