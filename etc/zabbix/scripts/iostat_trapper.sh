#!/bin/sh

SECONDS=1
COUNT=6
ZABBIX_SENDER='/usr/bin/env zabbix_sender'
CONFIG='/etc/zabbix/zabbix_agentd.conf'


DEVICES=$(lsblk -ldno NAME | xargs echo)
S_TIME_FORMAT=ISO iostat -x $DEVICES $SECONDS $COUNT | awk -v ct=$1 -v devices_list="$DEVICES" '
	BEGIN {
		devices_cnt = split(devices_list, devices, " ")
		metrics_list = "device rrqm/s wrqm/s r/s w/s rkB/s wkB/s avgrq-sz avgqu-sz await r_await w_await svctm util"
		metrics_cnt = split(metrics_list, metrics)
		for (d=1; d<=devices_cnt; d++) {
			data[devices[d],"dn"] = 0
			for (m=1; m<=metrics_cnt; m++) {
				data[devices[d],"sum",metrics[m]] = 0.0
				data[devices[d],"cnt",metrics[m]] = 0
			}
		}
	}
	{
		if ($1 == "avg-cpu:") { f = "cpu" }
		if ($1 != "Device:" && f == "device" && $1 != "") {
			data[$1,"dn"] += 1
			if (data[$1,"dn"] < 2) { next }
			for (m=2; m<=metrics_cnt; m++) {
				gsub(",", ".", $m)
				data[$1,"sum",metrics[m]] += $m
				data[$1,"cnt",metrics[m]] += 1
			}
		}
		if ($1 == "Device:") { f = "device" }
		fflush(stdout)
	}
	END {
		for (d=1; d<=devices_cnt; d++) {
			for (m=2; m<=metrics_cnt; m++) {
				if (data[devices[d],"cnt",metrics[m]] > 0) {
					printf("%s iostat.metric[%s,%s] %.2f\n", ct, devices[d], metrics[m], data[devices[d],"sum",metrics[m]]/data[devices[d],"cnt",metrics[m]]);
				}
			}
		}
	}' | $ZABBIX_SENDER --config $CONFIG --input-file - >>/var/log/zabbix/$(basename $0).log 2>&1

echo $?
