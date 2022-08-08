const util = require('util');
const exec = util.promisify(require('child_process').exec);
const https = require('https');
const fs = require('fs');
const os = require('os');

const user = os.userInfo();
const cdHome = 'cd ' + user.homedir + '/ironfish/ironfish-cli/ && ';
var logentry = '';
var logData = {};

function isNum(val) {
	return ('' + val).match(/^[0-9]+\.?[0-9]*$/) != null;
}

async function log() {
	let arg = Array.from(arguments);
	let key = arg.shift();
	let val = '' + arg.shift();
	if(arg.length > 0) {
		val = '' + arg.indexOf(val);
	}
	if(!isNum(val)) {
		val = '"' + val + '"';
	}
	logentry += ',' + key + '=' + val;
}

async function req(url) {
	let response_body = '';
	try {
		let http_promise = new Promise((resolve, reject) => {
			https.get(url, (response) => {
				let chunks_of_data = [];

				response.on('data', (fragments) => {
					chunks_of_data.push(fragments);
				});

				response.on('end', () => {
					let response_body = Buffer.concat(chunks_of_data);
					resolve(response_body.toString());
				});

				response.on('error', (error) => {
					reject(error);
				});
			});
		});
		response_body = JSON.parse(await http_promise);
	} catch(error) {
		// Promise rejected
		console.log(error);
	}
	return response_body;
}

async function runCommand(command, inYarn) {
	inYarn = typeof inYarn == 'undefined' || inYarn? 'yarn ': '';
	const { stdout, stderr, error } = await exec(cdHome + inYarn + command);
	if(stderr){console.error('stderr:', stderr);}
	if(error){console.error('error:', error);}
	return stdout;
}

async function resultToObj (stdout, lineSep, keyValSep, skipLines) {
	let result = stdout.split(lineSep);
	if(typeof skipLines == 'undefined') {
		skipLines = 0;
	}
	if(skipLines > 0)
		result = result.slice(skipLines);
	var data = {};
	if(keyValSep){
		for(let i = 0; i<result.length; i++){
			let kv = result[i].split(keyValSep);
			if(kv.length > 1) {
				data[kv[0]] = kv[1];
			}
		}
	} else {
		data = result;
	}
	return data;
}

async function main () {
	var service_name = '%service_name%';
	if ( service_name == '%'+'service_name'+'%') {
		service_name="ironfishd-pool"
	}
	var identityPubkey = await runCommand('ironfish accounts:publickey');
	identityPubkey = identityPubkey.split('\n').slice(2);
	identityPubkey = await resultToObj(identityPubkey[0], /,\s+/, /:\s+/);
	var statusInfo = await resultToObj(await runCommand('ironfish status'), '\n', /\s\s+/, 2);
	let status = 0;
	if (statusInfo['Node'] == "STARTED"){
		status=1
	}
	logentry = 'ironfishmonitor,pubkey='+identityPubkey['public key']+' status=' + status;
	var userInfo = await req('https://api.ironfish.network/users/find?graffiti=' + statusInfo['Block Graffiti']);
	var journalInfo = (await runCommand('journalctl --unit=' + service_name + ' -n 1 --no-pager', false)).split('\n').join('');
	journalInfo = journalInfo.split(' ');
	var hashRate = journalInfo[journalInfo.length - 2];
	log("hashRate", isNum(hashRate)? hashRate: 0);
	log("statusMining", statusInfo['Mining'].split(' ')[0], "STOPPED", "STARTED");
	log("statusSyncer", statusInfo['Syncer'].split(' ')[0], "STOPPED", "NOT", "SYNCING", "SYNCED", "IDLE");
	log("statusBlockchain", statusInfo['Blockchain'].split(' ')[0], "STOPPED", "NOT", "SYNCING", "SYNCED", "IDLE");
	log("statusTelemetry", statusInfo['Telemetry'].split(' ')[0], "STOPPED", "STARTED");
	log("statusWorkers", statusInfo['Workers'].split(' ')[0], "STOPPED", "STARTED");
	var version = statusInfo['Version'].split(' ')[0];
	log("version", version);
	var userInfoAll = await req('https://api.ironfish.network/users/'+userInfo.id+'/metrics?granularity=lifetime');
	var remoteVersionInfo = await req('https://api.ironfish.network/versions');
	log('userId', userInfo.id);
	log('graffiti', userInfo.graffiti);
	log('versionRemote', remoteVersionInfo.ironfish.version);
	log('rank', userInfoAll.pools.main.rank);
	log('totalPoints', userInfoAll.pools.main.points);
	log('nodeUptime', userInfoAll.node_uptime.total_hours);
	log('sendTransaction', userInfoAll.metrics.send_transaction.count);
	const ironfish_data = JSON.parse(fs.readFileSync(user.homedir+'/monitoring/ironfish_data.txt', {encoding:'utf8', flag:'r'}));
	log('validatorBalance', ironfish_data.balance);
	log('validatorAvailableAmount', ironfish_data.availableAmount);
	log('needsUpdate', remoteVersionInfo.ironfish.version == version ? 0: 1);
	console.log(logentry);
	//console.log(user);
}

main();
