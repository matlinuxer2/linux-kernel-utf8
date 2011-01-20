#!/bin/ash
#Mount things needed by this script
mount -t proc proc /proc
mount -t sysfs sysfs /sys

# Using "mdev" to active /dev/* node automatically
mdev -s
echo /bin/mdev > /proc/sys/kernel/hotplug
                                                                                                                             
#Create all the symlinks to /bin/busybox
busybox --install -s


# Start our customization section...
cat << EOF

/* 
 * This kernel is customized for UTF-8 built-in support.
 * Original from: 
 *
 *      http://blogold.chinaunix.net/u/13265/showart.php?id=1008020
 */

EOF


echo "==== Sample display ===="
echo "  你好世界 繁體中文 简体中文"
echo "  こんにちは世界"
echo "  안녕하세요"
echo "  прывітанне свет"
echo "  Γεια σας κόσμο"
echo "========================"

cat << EOF

Starting shell...

EOF

exec sh
