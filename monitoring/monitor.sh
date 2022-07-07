#!/bin/bash
cd $HOME/ironfish/ironfish-cli/
#validatorBalance=$(yarn ironfish accounts:balance $IRONFISH_WALLET | grep -Po "(^|\s)+(The balance is: .IRON )\K([\s0-9]|\.)*(?=\s|$)" | xargs)

graffiti=$(yarn ironfish config:get blockGraffiti | grep -Po "(^\")\K([A-z0-9])*(?=\"$)")

validatorBalance=$(cat $HOME/monitoring/ironfish_data.txt 2>/dev/null)
validatorBalanceInfo=""
if [ "$validatorBalance" != "" ]; then
	balance=$(jq -r '.balance' <<<$validatorBalance)
	availableAmount=$(jq -r '.availableAmount' <<<$validatorBalance)
	validatorBalanceInfo=",validatorBalance=\"$balance\",validatorAvailableAmount=\"$availableAmount\""
fi

userInfo=$(curl -X "GET" \
  "https://api.ironfish.network/users/find?graffiti=$graffiti" \
  -H "accept: */*" 2>/dev/null)
userId=$(jq -r '.id' <<<$userInfo)
userInfo=$(curl -X "GET" \
  "https://api.ironfish.network/users/$userId/metrics?granularity=lifetime" \
  -H "accept: */*" 2>/dev/null)
localVersion=$(yarn ironfish --version | grep -Po "(^|\s)+(version)\K([\s0-9]|\.)*(?=\s|$)" | xargs)
remoteVersionInfo=$(curl -X 'GET' \
'https://api.ironfish.network/versions' \
-H 'accept: */*' 2>/dev/null)
remoteVersion=$(jq -r '.ironfish.version' <<<$remoteVersionInfo)
rank=$(jq -r '.pools.main.rank' <<<$userInfo)
totalPoints=$(jq -r '.pools.main.points' <<<$userInfo)
nodeUptime=$(jq -r '.node_uptime.total_hours' <<<$userInfo)
sendTransaction=$(jq -r '.metrics.send_transaction.count' <<<$userInfo)
now=$(date +%s%N)
status=1
identityPubkey=$(yarn ironfish accounts:publickey | grep -Po "(^.+key: )\K([A-z0-9])*(?=\s|$)" | xargs)
needsUpdate=0
if [ "$localVersion" != "$remoteVersion" ]; then
	needsUpdate=1
fi

logInfo=$(journalctl --unit=ironfishd-pool -n 1 --no-pager | grep -Po "(^|\s)+(Found share: )\K([\sA-z0-9/]|\.)*(?=\s|$)")
logInfoArr=(${logInfo// / })
hashRate=${logInfoArr[2]}
if [ "$hashRate" == "" ]; then
	hashRate=0
fi
logentry="ironfishmonitor,pubkey=$identityPubkey status=$status,hashRate=$hashRate,sendTransaction=$sendTransaction,nodeUptime=$nodeUptime,rank=$rank,totalPoints=$totalPoints$validatorBalanceInfo,versionRemote=\"$remoteVersion\",version=\"$localVersion\",needsUpdate=$needsUpdate,graffiti=\"$graffiti\",userId=$userId $now"
echo $logentry


