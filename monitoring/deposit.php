<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
set_time_limit(900 - 60);

$account = $argv[1] ?? '';
$HOME = '%root_path%';

function msg($message, $exit = true)
{
	$text = sprintf("%s: %s", date('[H:i:s d.m.Y]'), implode("\n", (array)$message));
	echo $text . PHP_EOL;
	if ($exit) {
		exit;
	}
}

$socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
if (false === $socket) {
	throw new Exception("can't create socket: " . socket_last_error($socket));
}
if (false === @socket_bind($socket, '127.0.0.1', '39035')) {
	msg("Autodeposit already running, skipping run.");
}

msg("Script started. Used account - [" . ($account ? $account : 'default') . "] Wait for the logs...", false);

msg("Getting balance...", false);
$exec = exec(trim('/usr/bin/yarn --cwd ~/ironfish/ironfish-cli/ start accounts:balance ' . $account), $output, $code);
if ($code) {
	msg("Can not get balance, code $code", false);
	msg(implode("\n", $output));
}

//msg("matches: " . print_r($output,true), false);
$pattern = '|The balance is: \$IRON ([\d\.,]+)|';
if (!preg_match($pattern, implode('', $output), $matches)) {
	msg("Can not get available amount", false);
	msg(implode("\n", $output));
}
$balanceStr = (float)str_replace(',', '.', $matches[1]);
$pattern = '|Amount available to spend: \$IRON ([\d\.,]+)|';
if (!preg_match($pattern, implode('', $output), $matches)) {
	msg("Can not get available amount", false);
	msg(implode("\n", $output));
}
//msg("matches: " . print_r($matches,true), false);
$balance = (float)str_replace(',', '.', $matches[1]);
$balanceStr = '{ "balance":' . $balanceStr . ', "availableAmount":' . $balance . ' }';
file_put_contents("$HOME/monitoring/ironfish_data.txt", $balanceStr);
if ($balance < 0.10000001) {
	msg("Not enough available amount (" . $matches[1] . ')');
}

msg("Available to spend: \$IRON $balance", false);

//while (true) {

	msg("Trying to make deposit...", false);

	sleep(1);

	$error_log = tempnam(sys_get_temp_dir(), md5(uniqid()));
	if (false === $error_log) {
		throw new Exception('Can not get tempfile.');
	}
	$accountStr = $account ? '-a ' . $account : '';
	exec('/usr/bin/yarn --cwd ~/ironfish/ironfish-cli/ start deposit ' . $accountStr . ' --confirm 2>>' . $error_log, $output, $code);

	if ($code) { // error
		msg("Can not make deposit, code: $code", false);
		msg(implode("\n", $output), false);
		msg(@file_get_contents($error_log), false);
		@unlink($error_log);
		@msg("Script exits");
	}

	@unlink($error_log);

	msg("Deposit made", false);
//}

