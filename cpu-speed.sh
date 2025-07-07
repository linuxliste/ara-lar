#!/bin/bash
# islemci kullanim durumunu ayarlamak icin yazilmistir.
# Remzi AKYUZ
# remzi@akyuz.tech

id=`id -u`

if [ $id -eq 0  ]

		then
		# gerekli kernel modullerini yukluyoruz
                modprobe cpufreq_conservative
                modprobe cpufreq_ondemand
                modprobe cpufreq_powersave
                modprobe cpufreq_stats

		echo  Calisma tipi:  $1 

		cores=`grep processor  /proc/cpuinfo  | tail -n 1 |cut -d\: -f 2`
               
                cs=$(($cores+1))

                echo cekirdek sayisi $cs

                if ([[ "$1" == "powersave" ]] ||  [[ "$1" == "ondemand" ]] || [[ "$1" == "conservative" ]] || [[ "$1" == "performance" ]] )
                                                                                                                             then
		for cpu in `seq 0 "$cores"`

			do 
                           printf "\nCekirdek cpu"$cpu" calisma modu ( eski ) : "
                           cat  /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor

			   echo  $1  > /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor
                           printf "\nCekirdek cpu"$cpu" calisma modu ( yeni ) : "
                           cat  /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor

			   #echo  1200000    > /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_max_freq
                           #cat /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_max_freq
			done
                 else
                     printf  "\n\n\nCalisma modunu yalnis girdiniz.\n\n\n"
                     printf  "Lutfen \n\n\n\t\t\t"
                     printf   "sudo ./cpu-speed.sh performace |ondemand |powersave\n\n\n"
                     printf   "Seklinde kullaniniz.\n\nTesekkurler.\n\n\n"
                 fi
else

	printf "\n\n\n Root Olmaniz gerekiyor!!!  \n\n\n"

fi
