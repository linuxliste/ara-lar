
dd if=//dev/zero of=loop-disk.img bs=1M count=1000

modprobe loop

#losetup -f -P  loop-disk.img
losetup  -P /dev/loop7 loop-disk.img
fdisk -l /dev/loop7



# loop diski  kullanimdan cikartmak icin 
# losetup -d /dev/loop7
