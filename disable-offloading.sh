#!/bin/bash
# https://access.redhat.com/solutions/3425461
ethtool -K bond0  rx off gro off lro off
ethtool  -K ens1f0  rx off gro off lro off
ethtool  -K eno5  rx off gro off lro off

