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

echo "Running on ${dev}..."

echo "  Randread, 4KB, QD=32, 1 job"
run_fio "Randread-4k-1x32" "randread" 4096 32 1 10

echo "  Randread, 4KB, QD=32, 4 jobs"
run_fio "Randread-4k-4x32" "randread" 4096 32 4 10

echo "  Randwrite, 4KB, QD=32, 1 job"
run_fio "Randwrite-4k-1x32" "randwrite" 4096 32 1 10

echo "  Seq read, 512KB, QD=32, 1 job"
run_fio "Seqread-512k-1x32" "read" 524288 32 1 10

echo "  Seq write, 128KB, QD=32, 1 job"
run_fio "Seqwrite-128k-1x32" "write" 131072 32 1 10

echo "  Seq read, 1MB, QD=32, 1 job"
run_fio "Seqread-1M-1x32" "read" 1048576 32 1 10

echo "  Rand read/write, rand size 4K..1MB @ QD=8, 4 jobs"
run_fio "Randreadwrite-4k-1M-4x8" "randrw" "4096-1048576" 8 4 20
