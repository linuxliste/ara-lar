#!/bin/bash
# Writen by Remzi AKYUZ
# remzi@akyuz.tech
# usage : ./rsync_only_one_file.sh  templates/avendor/css/custom.css
set +x

sfile="/var/www/html.git/$1" 
dfile="/var/www/html/$1" 
dhost="hedef_host_ip"
gitstatus=null

cd /var/www/html.git/
git fetch --all && git reset --hard origin/dev && git pull  && gitstatus="ok" 

if [ $gitstatus == "ok" ]
                        then 
                        printf "\n\nGit Status Okay"

if [[ $# -eq 1 ]] 
                then
                     if [[ -f $sfile ]]
                                          then
                                              # rsync -auvh --stats  $sfile root@10.60.1.247:$dfile
                                              scp   $sfile root@$dhost:$dfile
                     else
                         printf "\n File name or path incorrect!!!!"
                         printf "\nPlease say to me file name with path!"
                         printf "\nusage : ./rsync_only_one_file.sh  templates/avendor/css/custom.css \n\b"
                         printf "\nusege :  ./rsync_only_one_file.sh -d tmp/directory-name \n\n\b"
                         
                     fi

fi

if [[ $# -eq 2 ]] && [[ $2 == "-d" ]]

                                     then
                                         rsync -auvh --stats $sfile/ root@$dhost:$dfile/

                                     else
                                          printf "\n File name or path incorrect!!!!"
                                          printf "\nPlease say to me file name with path!"
                                          printf "\nusage : ./rsync_only_one_file.sh  templates/avendor/css/custom.css \n\b"
                                          printf "\nusege :  ./rsync_only_one_file.sh -d tmp/directory-name \n\n\b"

fi

else
    printf "\n\nPlease check git!\n\n"

fi
