#!/bin/sh
# /etc/acpi/power-supply.sh - Managing power events for SliTaz
# For Tips & Tricks see http://www.lesswatts.org

# This script turns off power savings mode on ac or when the 
# battery almost runs out in a attempt to limit data loss in
# a case of power failure.

ENABLED=1
DISABLED=0

# AC status (from /sys/class/power_supply/online)
ON_LINE=1
OFF_LINE=0

# Battery status 
LOW_BAT=0
HIGH_BAT=1

# Determining the power state.

ac_status()
{
	POWER_SUPPLY_MAINS=$DISABLED
	AC_STATUS=$OFF_LINE
	for POWER_SUPPLY in /sys/class/power_supply/* ; do
		if [ -f $POWER_SUPPLY/type ] ; then
			if [ "$(cat $POWER_SUPPLY/type)" = "Mains" ] ;then
				echo -n "Determining power state from $POWER_SUPPLY: "
				POWER_SUPPLY_MAINS=$ENABLED
				if [ "$(cat $POWER_SUPPLY/online)" = 1 ] ; then
					AC_STATUS=$ON_LINE
					echo "on-line"
				else
					echo "off-line"
				fi
			fi
		fi
	done
	if [ $POWER_SUPPLY_MAINS -eq $DISABLED ] ; then
		$AC_STATUS=$ON_LINE
	fi
}

# Determining the battery state.

battery_status()
{
	BATTERY_STATUS=$LOW_BAT
	for BATT in /sys/class/power_supply/* ; do
		BATT_TYPE=$(cat $BATT/type)
		echo "$BATT is of type $BATT_TYPE."
		if [ "$BATT_TYPE" = "Battery" ] ; then
			echo "  Checking levels for $BATT."
			# Only do if the battery is present
	        if [ $(cat $BATT/present) -eq 1 ] ; then

				# Get the remaining capacity.
				if [ -f $BATT/charge_now ] ; then
					REMAINING=$(cat $BATT/charge_now)
				elif [ -f $BATT/energy_now ] ; then
					REMAINING=$(cat $BATT/energy_now)
				else
					REMAINING=0
				fi
				if [ -z "$REMAINING" -o "$REMAINING" -eq 0 ] ; then
					echo "  Battery does not report remaining charge. Perhaps it is not present?"
				else
					echo "  Remaining charge: $REMAINING"

					# Get the alarm level
					ALARM_LEVEL=$(cat $BATT/alarm)
					if [ "$ALARM_LEVEL" -eq 0 ] ; then

						# Get the full capacity.

						if [ -f $BATT/charge_full_design ] ; then
							CAPACITY=$(cat $BATT/charge_full_design)
						elif [ -f $BATT/energy_full_design ] ; then
							CAPACITY=$(cat $BATT/energy_full_design)
						else
							CAPACITY=0
						fi
						if [ -z "$CAPACITY" -o "$CAPACITY" -eq 0 ] ; then
							echo "  Battery does not report design full charge, using non-design full charge."

							if [ -f $BATT/charge_full ] ; then
								CAPACITY=$(cat $BATT/charge_full)
							elif [ -f $BATT/energy_full_design ] ; then
								CAPACITY=$(cat $BATT/energy_full)
							else
								CAPACITY=0
							fi
							if [ -z "$CAPACITY" -o "$CAPACITY" -eq 0] ; then
								echo "  Battery does not report non-design full charge."
							fi
						fi
						echo "  Full capacity: $CAPACITY"
						ALARM_LEVEL=$((CAPACITY*5/100))
					fi
					echo "  Alarm level: $ALARM_LEVEL"
					if [ "$ALARM_LEVEL" -ne 0 ] ; then
						if [ "$REMAINING" -ge "$ALARM_LEVEL" ] ; then
							# this battery does count as having enough charge.
							BATTERY_STATUS=$HIGH_BAT
							echo "  Battery status: high"
						else
							echo "  Battery status: low"
						fi
					fi
				fi
			else
				echo "Battery is not present."
			fi
		fi
	done
}

online_mode()
{
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
		echo "Disabling AC97 audio power saving mode"
		echo 0 > /sys/module/snd_ac97_codec/parameters/power_save
	fi

	# The VM writeback time
	# The VM subsystem caching allows the kernel to group consecutive
	# writes into one big write, and to generally optimize the disk IO
	# to be the most efficient. 

	if [ -e /proc/sys/vm/dirty_writeback_centisecs ] ; then
		echo "Writeback time reset to 500ms"
		echo 500 > /proc/sys/vm/dirty_writeback_centisecs
	fi
}

offline_mode()
{
	# Enable laptop mode
	# When laptop mode is enabled, the kernel will try to be smart
	# about when to do IO, to give the disk and the SATA links as
	# much time as possible in a low power state. 

	if [ ! -e /proc/sys/vm/laptop_mode ] ; then
		echo "Kernel does not have support for laptop mode." 
	else
		echo "Enabling laptop mode"
		echo 5 > /proc/sys/vm/laptop_mode
	fi

	# AC97 audio power saving mode
	# The AC97 onboard audio chips support power saving, where the
	# analog parts (codec) are powered down when no program is using
	# the audio device.

	if [ -e /sys/module/snd_ac97_codec/parameters/power_save ] ; then
		echo "Enabling AC97 audio power saving mode"
		echo 1 > /sys/module/snd_ac97_codec/parameters/power_save
		echo 1 > /dev/dsp
	fi

	# The VM writeback time
	# The VM subsystem caching allows the kernel to group consecutive
	# writes into one big write, and to generally optimize the disk IO
	# to be the most efficient.

	if [ -e /proc/sys/vm/dirty_writeback_centisecs ] ; then
		echo "Writeback time set to 1500ms"
		echo 1500 > /proc/sys/vm/dirty_writeback_centisecs
	fi
}

power_status()
{
	if [ $(cat /proc/sys/vm/dirty_writeback_centisecs) -gt 1000 ]; then
		POWER_SAVINGS=$ENABLED
		echo "power-savings-mode enabled"
	else
		POWER_SAVINGS=$DISABLED
		echo "power-savings-mode disabled"
	fi
}

custom_scripts()
{
	# Custom scripts in /etc/acpi/ac.d

	if [ -d /etc/acpi/ac.d ]; then
		for SCRIPT in /etc/acpi/ac.d/*.sh; do
			. $SCRIPT $AC_STATUS $BATTERY_STATUS $0
		done
	fi

	# Custom scripts in /etc/acpi/battery.d

	if [ -d /etc/acpi/battery.d ]; then
		for SCRIPT in /etc/acpi/battery.d/*.sh; do
			. $SCRIPT $AC_STATUS $BATTERY_STATUS $0
		done
	fi
}

ac_status
battery_status
power_status
case "$AC_STATUS+$BATTERY_STATUS" in
	"$OFF_LINE+$HIGH_BAT")
		if [ $POWER_SAVINGS = $DISABLED ]; then 
			logger "Start power savings mode"
			offline_mode
		fi
	;;
	*)
		if [ $POWER_SAVINGS = $ENABLED ]; then
			logger "Stop power savings mode"
			online_mode
		fi
	;;
esac
custom_scripts