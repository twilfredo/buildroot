#!/bin/bash

dev="$(ls /dev/disk/by-id/* | grep Linux | head -1)"
dev="$(realpath ${dev})"
if [ "${dev}" == "" ]; then
	echo "No NVMe EPF device found"
	exit 1
fi

function run_fio()
{
	local name="$1"
	local rw="$2"
	local bs="$3"
	local qd="$4"
	local nrjobs="$5"
	local rt="$6"

	fiocmd="fio --name=\"${name}\" --filename=${dev}"
	fiocmd+=" --rw=${rw} --direct=1"
	fiocmd+=" --ioengine=io_uring --iodepth=${qd}"

	range=$(echo ${bs} | grep -c "-")
	if [ ${range} == 0 ]; then
		fiocmd+=" --bs=${bs}"
	else
		fiocmd+=" --bsrange=${bs}"
	fi

	if [ ${nrjobs} > 1 ]; then
		fiocmd+=" --numjobs=${nrjobs}"
		fiocmd+=" --cpus_allowed=0-$(( $(nproc) - 1 ))"
		fiocmd+=" --cpus_allowed_policy=split"
		fiocmd+=" --group_reporting=1"
	fi

	fiocmd+=" --runtime=${rt}"

	log="${name}.log"
	echo "  ${fiocmd}" > "${log}" 2>&1
	eval "${fiocmd}" >> "${log}" 2>&1

	grep IOPS "${log}" | sed -e 's/^/    ->/'
}

echo "Note: this test will take at minimum ~36 minutes to finish running"

echo "Running on ${dev}..."
echo "  Running fio (Randread, 4KB, QD=32) with increasing delays to check the PCIe link stays in L0"
run_fio "Randread-4k-1x32" "randread" 4096 32 1 10

echo "Sleep for 1 minute"
sleep 60
run_fio "Randread-4k-1x32" "randread" 4096 32 1 10

echo "Sleep for 5 minutes"
sleep 300
run_fio "Randread-4k-1x32" "randread" 4096 32 1 10

echo "Sleep for 10 minutes"
sleep 600
run_fio "Randread-4k-1x32" "randread" 4096 32 1 10

echo "Sleep for 20 minutes"
sleep 1200
run_fio "Randread-4k-1x32" "randread" 4096 32 1 10