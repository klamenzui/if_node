#!/bin/bash
cd $HOME/ironfish/ironfish-cli/
#validatorBalance=$(yarn ironfish accounts:balance $IRONFISH_WALLET | grep -Po "(^|\s)+(The balance is: .IRON )\K([\s0-9]|\.)*(?=\s|$)" | xargs)

logentry=""
function log(){
	local key="$1"
	local val="${!key}"
	local count=-1
	for arg in "$@"
	do
		if [ "$count" != "-1" ]; then
			if [ "$val" == "$arg" ]; then
				val="$count"
				break
			fi
		fi
		count=$((count+1))
	done
	if ! [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]]
		then
			val="\"$val\""
	fi
	#if [ "${!arg}" != "" ]; then
	logentry="$logentry,$key=$val"
	#fi
}
identityPubkey=$(yarn ironfish accounts:publickey | grep -Po "(^.+key: )\K([A-z0-9])*(?=\s|$)" | xargs)
statusInfo=$(yarn ironfish status)
statusNode=$(echo $statusInfo | grep -Po "(^|\s)+(Node\s+)\K([A-z0-9/]|\.)*(?=\s|$)" | xargs)
statusMining=$(echo $statusInfo | grep -Po "(^|\s)+(Mining\s+)\K([A-z0-9/]|\.)*(?=\s|$)")
statusSyncer=$(echo $statusInfo | grep -Po "(^|\s)+(Syncer\s+)\K([A-z0-9/]|\.)*(?=\s|$)")
statusBlockchain=$(echo $statusInfo | grep -Po "(^|\s)+(Blockchain\s+)\K([A-z0-9/]|\.)*(?=\s|$)")
statusTelemetry=$(echo $statusInfo | grep -Po "(^|\s)+(Telemetry\s+)\K([A-z0-9/]|\.)*(?=\s|$)")
version=$(echo $statusInfo | grep -Po "(^|\s)+(Version\s+)\K([A-z0-9/]|\.)*(?=\s|$)" | xargs)
status=0
if [ "$statusNode" == "STARTED" ]; then
	status=1
fi
logentry="ironfishmonitor,pubkey=$identityPubkey status=$status"
log "statusMining" "STOPED" "STARTED"
log "statusSyncer" "NOT" "SYNCING" "SYNCED" "IDLE"
log "statusBlockchain" "NOT" "SYNCING" "SYNCED"
log "statusTelemetry" "STOPED" "STARTED"
log "version"
graffiti=$(yarn ironfish config:get blockGraffiti | grep -Po "(^\")\K([A-z0-9])*(?=\"$)")

validatorBalanceInfo=$(cat $HOME/monitoring/ironfish_data.txt 2>/dev/null)
if [ "$validatorBalanceInfo" != "" ]; then
	validatorBalance=$(jq -r '.balance' <<<$validatorBalanceInfo)
	validatorAvailableAmount=$(jq -r '.availableAmount' <<<$validatorBalanceInfo)
	log "validatorBalance"
	log "validatorAvailableAmount"
fi

userInfo=$(curl -X "GET" \
  "https://api.ironfish.network/users/find?graffiti=$graffiti" \
  -H "accept: */*" 2>/dev/null)
userId=$(jq -r '.id' <<<$userInfo)
userInfo=$(curl -X "GET" \
  "https://api.ironfish.network/users/$userId/metrics?granularity=lifetime" \
  -H "accept: */*" 2>/dev/null)
# localVersion=$(yarn ironfish --version | grep -Po "(^|\s)+(version)\K([\s0-9]|\.)*(?=\s|$)" | xargs)
remoteVersionInfo=$(curl -X 'GET' \
'https://api.ironfish.network/versions' \
-H 'accept: */*' 2>/dev/null)
versionRemote=$(jq -r '.ironfish.version' <<<$remoteVersionInfo)
rank=$(jq -r '.pools.main.rank' <<<$userInfo)
totalPoints=$(jq -r '.pools.main.points' <<<$userInfo)
nodeUptime=$(jq -r '.node_uptime.total_hours' <<<$userInfo)
sendTransaction=$(jq -r '.metrics.send_transaction.count' <<<$userInfo)
now=$(date +%s%N)

needsUpdate=0
if [ "$version" != "$versionRemote" ]; then
	needsUpdate=1
fi
#logInfo=$(journalctl --unit=ironfishd-pool -n 1 --no-pager | grep -Po "(^|\s)+(Found share: )\K([\sA-z0-9/]|\.)*(?=\s|$)")
service_name="%service_name%"
tmp="service_name"
if [ "$service_name"=="%$tmp%" ]; then
	service_name="ironfishd-pool"
fi
logInfo=$(journalctl --unit=$service_name -n 1 --no-pager | grep -Po "(^|\s)+(Found share: )\K([\sA-z0-9/]|\.)*(?=\s|$)")
logInfoArr=(${logInfo// / })
hashRate=${logInfoArr[2]}
if [ "$hashRate" == "" ]; then
	hashRate=0
fi
log "graffiti"
log "userId"
log "versionRemote"
log "needsUpdate"
log "hashRate"
log "sendTransaction"
log "nodeUptime"
log "totalPoints"
log "rank"
logentry="$logentry $now"
echo $logentry


