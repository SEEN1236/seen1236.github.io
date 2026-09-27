const path = require('path');
const readline = require('readline');
const { spawn } = require('child_process');

const serverPath = path.join(__dirname, 'server.js');
const url = 'http://localhost:3000';
let serverProcess = null;
let changingState = false;
let quitting = false;

function isRunning() {
  return serverProcess !== null && serverProcess.exitCode === null;
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function startWebsite() {
  if (isRunning()) {
    console.log(`[ON] Website is already running at ${url}`);
    return;
  }

  serverProcess = spawn(process.execPath, [serverPath], {
    env: { ...process.env, PORT: '3000' },
    stdio: ['ignore', 'inherit', 'inherit'],
    windowsHide: true,
  });

  const startedProcess = serverProcess;
  startedProcess.once('exit', () => {
    if (serverProcess === startedProcess) serverProcess = null;
  });

  await wait(250);
  if (!isRunning()) {
    console.log('[ERROR] Website could not start. Port 3000 may already be in use.');
    return;
  }
  console.log(`[ON] Website is running at ${url}`);
}

async function stopWebsite(showMessage = true) {
  if (!isRunning()) {
    serverProcess = null;
    if (showMessage) console.log('[OFF] Website is already stopped.');
    return;
  }

  const processToStop = serverProcess;
  const stopped = new Promise((resolve) => processToStop.once('exit', resolve));
  processToStop.kill('SIGTERM');
  await Promise.race([stopped, wait(1000)]);
  if (processToStop.exitCode === null) processToStop.kill();
  if (serverProcess === processToStop) serverProcess = null;
  if (showMessage) console.log('[OFF] Website has stopped. CMD remains open.');
}

const input = readline.createInterface({ input: process.stdin, output: process.stdout });
input.setPrompt('Command: ');

async function shutdown() {
  if (quitting) return;
  quitting = true;
  await stopWebsite(false);
  input.close();
  process.exit(0);
}

input.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

input.on('line', async (line) => {
  if (changingState || quitting) return;
  changingState = true;
  const command = line.trim().toLowerCase();

  if (command === 'on') {
    await startWebsite();
  } else if (command === 'off') {
    await stopWebsite();
  } else if (command === 're') {
    if (isRunning()) await stopWebsite(false);
    console.log('[RE] Restarting website...');
    await startWebsite();
  } else if (command === 'status') {
    console.log(isRunning() ? `[ON] Website is running at ${url}` : '[OFF] Website is stopped.');
  } else if (command === 'exit' || command === 'quit') {
    changingState = false;
    await shutdown();
    return;
  } else if (command !== '') {
    console.log('Type on, off, status, or exit.');
  }

  changingState = false;
  input.prompt();
});

(async () => {
  console.log('SEEN Website Control');
  console.log('Commands: on = start, off = stop, re = restart, status = show status, exit = close CMD');
  console.log('Ctrl+C or closing CMD stops everything.');
  await startWebsite();
  input.prompt();
})();
