#!/bin/bash
set +x
for JOBID in $(hammer --csv task list --search state=paused | egrep -i -v 'ID|HTTP|Response|html|title|head|proxy|response|body' | cut -d\, -f1 |sort|uniq |grep -v \" |xargs)
do
hammer task resume --task-ids ${JOBID}
done


