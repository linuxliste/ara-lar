#!/bin/bash

#hammer user list
OWNER_ID=19

hammer host list | awk '{print $1}' |grep -v \- > host_id_lists.txt


for HOST_ID in $(cat host_id_lists.txt);
do
echo hammer host update --owner-id  $OWNER_ID --id $HOST_ID
hammer host update --owner-id  $OWNER_ID --id $HOST_ID
done

