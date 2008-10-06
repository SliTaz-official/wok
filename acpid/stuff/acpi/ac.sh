#!/bin/sh
##
## ac.sh
## 
## Made by Dominique Corbex
## Login   <domcox@users.sourceforge.net>
## 
## Started on  Mon Oct  6 12:56:58 2008 Dominique Corbex
## Last update 
##

# Disable laptop mode
# When laptop mode is enabled, the kernel will try to be smart
# about when to do IO, to give the disk and the SATA links as
# much time as possible in a low power state.

if [ -e /proc/sys/vm/laptop_mode ] ; then
    echo "Disabling laptop mode"
    echo 0 > /proc/sys/vm/laptop_mode
fi

# AC97 audio power saving mode
# The AC97 onboard audio chips support power saving, where the
# analog parts (codec) are powered down when no program is using
# the audio device.

if [ -e /sys/module/snd_ac97_codec/parameters/power_save ] ; then
    echo "Enabling AC97 audio power saving mode"
    echo 0 > /sys/module/snd_ac97_codec/parameters/power_save
fi

# The VM writeback time
# The VM subsystem caching allows the kernel to group consecutive
# writes into one big write, and to generally optimize the disk IO
# to be the most efficient. 

if [ -e /proc/sys/vm/dirty_writeback_centisecs ] ; then
    echo "Writeback time reset back to 500ms"
    echo 500 > /proc/sys/vm/dirty_writeback_centisecs
fi
