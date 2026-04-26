#!/usr/bin/env bash

# Grab first line of /proc stat (aggregate of all cpus)

function get_data() {
    # mapfile -t cpu < <(head -n1 /proc/stat) # FIXME why does this not work as expected
    cpu_now=($(head -n1 /proc/stat))

    # Remove -f1 and aggregate the rest with parameter expansion
    cpu_sum="${cpu_now[@]:1}"

    # Replace column separater with '+'; then summate
    cpu_sum=$((${cpu_sum// /+}))

    # Get delta between two reads
    cpu_delta=$((cpu_sum - cpu_last_sum))

    # Get the idle time delta
    cpu_idle=$((cpu_now[4] - cpu_last[4]))

    # calc time spent working
    cpu_used=$((cpu_delta - cpu_idle))

    # calc %
    cpu_usage=$((100 * cpu_used / cpu_delta))

    # cpu_last for next read
    cpu_last=(${cpu_now[@]})
    cpu_last_sum=$cpu_sum

    echo "$cpu_usage"

    sleep 1
}

while :; do
    get_data
done
