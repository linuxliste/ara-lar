#!/usr/bin/python3
import os
[os.rename(dosya,dosya.replace(' ','_')) for dosya in os.listdir('/mnt/depo')]
