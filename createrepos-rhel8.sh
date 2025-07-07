reposync --setopt=repo_id.module_hotfixes=1 --downloadcomps --download-metadata -p /var/www/html/rhel8/
exit 0
for reponame in `cat repolist.txt` 
do
#	createrepo $reponame
	createrepo_c $reponame
done
#!/bin/sh
reposync --setopt=repo_id.module_hotfixes=1 --downloadcomps --download-metadata -p /var/www/html/rhel8
