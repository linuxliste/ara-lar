#!/bin/sh -e
#
grep MHz /proc/cpuinfo

az()
               {
                for i in `seq 0 7`
                do
                echo userspace > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
                cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed 

                echo userspace > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
                cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq > /sys/devices/system/cpu/cpu1/cpufreq/scaling_setspeed 
               done
               }

cok()
     {
      for i in `seq 0 7`
      do
      echo userspace > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
      cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_setspeed
      echo userspace > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
      cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_setspeed
      done
     }

oto ()
           {
            for i in `seq 0 7`
            do            
            echo ondemand  > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
            echo ondemand  > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
            done
           }


case "$1" in
             az) az ;;
             cok) cok ;;
             oto) oto ;;
             *) echo "./hiz.sh az | cok | oto seklinde kullanmak gerekiyor." ;;
esac

grep MHz /proc/cpuinfo

