#!/bin/bash
# Provide device to benchmark as argument
#
set -e

main () {
  if [ $# != 1 ]
  then
    echo "No device provided"
    exit 1
  fi
  dev=$1

  REQUIRED_PKG="fio"
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
  if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG."
    echo sudo apt-get --yes install $REQUIRED_PKG
    exit 1
  fi

  REQUIRED_PKG="jq"
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
  if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG."
    echo sudo apt-get --yes install $REQUIRED_PKG
    exit 1
  fi

  echo "name,iodepth,numjobs,iops_min,iops_max,iops_mean,bw_min,bw_max,bw_mean,clat_ns_9999,clat_ns_99,clat_ns_95,clat_ns_min,clat_ns_max,clat_ns_mean"

  for type in read write randread randwrite;
  do
    for bs in 4k 4M;
    do
      for iodepth in 1 64; # 1 16 64 256
      do
        for numjobs in 1 8; # 1 8 16
        do
          call_fio $dev $type $bs $iodepth $numjobs
        done
      done
    done
  done
}

function call_fio() {
  if [[ $2 == *"read"* ]]; then
    search_base="read"
  else
    search_base="write"
  fi
  ret=`fio --name=fio --output-format=json --direct=1 --group_reporting --size=20G --runtime=120 --rw=$2 --ioengine=libaio --bs=$3 --numjobs=$5 --iodepth=$4 --filename=$1`
  iops_min=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].iops_min'`
  iops_max=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].iops_max'`
  iops_mean=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].iops_mean'`
  bw_min=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].bw_min'`
  bw_max=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].bw_max'`
  bw_mean=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].bw_mean'`
  clat_ns_9999=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].clat_ns.percentile."99.990000"'`
  clat_ns_99=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].clat_ns.percentile."99.000000"'`
  clat_ns_95=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].clat_ns.percentile."95.000000"'`
  clat_ns_min=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].clat_ns.min'`
  clat_ns_max=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].clat_ns.max'`
  clat_ns_mean=`jq -n --arg sb "$search_base" --argjson data "$ret" '$data.jobs[0][$sb].clat_ns.mean'`
  # sed 's/=.*$//g' /tmp/test| sed 's/  /$/g' | tr '\n' ','
  test_name="$1-$2-$3"
  echo $test_name,$4,$5,$iops_min,$iops_max,$iops_mean,$bw_min,$bw_max,$bw_mean,$clat_ns_9999,$clat_ns_99,$clat_ns_95,$clat_ns_min,$clat_ns_max,$clat_ns_mean
}


main "$@"; exit
