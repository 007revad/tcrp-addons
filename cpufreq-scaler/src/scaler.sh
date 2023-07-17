#!/bin/bash

# Make things safer
set -euo pipefail

# Ensure root user
#if [ "$EUID" -ne 0 ]; then
#  echo "Please run as root"
#  exit
#fi

# Ensure acpi-cpufreq kernel module is loaded
#if ! modprobe acpi-cpufreq; then
#  pushd /lib/modules
#  insmod acpi-cpufreq.ko
#  popd
#fi

# Frequency scaling function
function main {

  if [ $(cat /proc/cpuinfo |grep Intel |wc -l) -gt 0 ]; then
    CPU="INTEL"
  else
    CPU="AMD"
  fi

  # Get cpu cores count minus 1, to allow maping from 0
  cpucorecount=$(cat /proc/cpuinfo | grep processor | wc -l)
  cpucorecount=$((cpucorecount - 1))
  governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

  # Rereive allowed cpu freq on the system
  IFS=" " read -r -a freqlist <<<"$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies)"

  # Set min and max frequencies, this user overidable
  scalingminfreq=${scalingminfreq:=${freqlist[-1]}}
  scalingmaxfreq=${scalingmaxfreq:=${freqlist[0]}}

  # This will set user defined min and max frequencies
  if [ "$governor" = "userspace" ]; then
    for i in $(seq 0 "${cpucorecount}"); do
      echo "$scalingminfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_min_freq
      echo "$scalingmaxfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_max_freq
    done
  fi

  if [ "$CPU" = "INTEL" ]; then
    # Get current and max cpu temps for Intel
    currtemp=$(cat /sys/bus/platform/devices/coretemp.0/hwmon/hwmon0/temp1_input)
    maxtemp=$(cat /sys/bus/platform/devices/coretemp.0/hwmon/hwmon0/temp1_max)

    # Frequencies steps definitions (only for Intel)
    coolfreq=${freqlist[3]}
  fi

  # Frequencies steps definitions
  minfreq=${freqlist[-1]}
  midfreq=${freqlist[$((${#freqlist[*]} / 2))]}
  maxfreq=${freqlist[0]}

  # Get average load over 5m in base10 integer format
  loadavg=$(awk -F . '{print $1 substr($2,1,2)}' </proc/loadavg)

  # Set load steps to trigger frequencies scaling, this user overidable
  lowload=$(grep cores /proc/cpuinfo | sort -u | awk '{ print $4 * 0.3 * 100 }')
  midload=$(grep cores /proc/cpuinfo | sort -u | awk '{ print $4 * 0.6 * 100 }')

  if [ "$CPU" = "INTEL" ]; then
    if [ "$currtemp" -lt "$maxtemp" ]; then
      for i in $(seq 0 "${cpucorecount}"); do
        if [ "$loadavg" -le $((10#$lowload)) ]; then
          echo "$minfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_setspeed
        elif [ "$loadavg" -ge $((10#$lowload)) ] && [ "$loadavg" -le $((10#$midload)) ]; then
          echo "$midfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_setspeed
        elif [ "$loadavg" -ge $((10#$midload)) ]; then
          echo "$maxfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_setspeed
        fi
      done
    else
      for i in $(seq 0 "${cpucorecount}"); do
        echo "$coolfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_setspeed
      done
      sleep 30
    fi
  elif [ "$CPU" = "AMD" ]; then  
      for i in $(seq 0 "${cpucorecount}"); do
        if [ "$loadavg" -le $((10#$lowload)) ]; then
          echo "$minfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_setspeed
        elif [ "$loadavg" -ge $((10#$lowload)) ] && [ "$loadavg" -le $((10#$midload)) ]; then
          echo "$midfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_setspeed
        elif [ "$loadavg" -ge $((10#$midload)) ]; then
          echo "$maxfreq" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_setspeed
        fi
      done
  fi
}

# Deamonize the main function...
while true; do

  if [ -f /usr/sbin/stopscale ]; then
      exit 0
  fi
  # Get cpu cores count minus 1, to allow maping from 0
  cpucorecount=$(cat /proc/cpuinfo | grep processor | wc -l)
  cpucorecount=$((cpucorecount - 1))
  governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

  # Set correct cpufreq governor to allow user defined frequency scaling
  if [ "$governor" != "userspace" ]; then
    for i in $(seq 0 "${cpucorecount}"); do
      echo "userspace" >/sys/devices/system/cpu/cpu"${i}"/cpufreq/scaling_governor
    done
  fi
  
  governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
  if [ "$governor" = "userspace" ]; then
    main
  fi
  sleep 0.5
done
