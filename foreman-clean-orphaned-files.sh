#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Script for initiating removal of orphaned content
foreman-rake katello:delete_orphaned_content RAILS_ENV=production 

# Script to refresh all alternate content sources
foreman-rake katello:refresh_alternate_content_sources 
