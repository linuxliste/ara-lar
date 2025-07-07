#!/bin/bash
# Remzi AKYUZ
# remzi@akyuz.tech
export name=$1

genisoimage -U -r -v -T -allow-limited-size  -input-charset iso8859-9 --joliet -joliet-long -V $name -volset $name  -o $name.iso  $name/
