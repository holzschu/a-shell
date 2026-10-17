// Run through the embedded Node CLI in real a-Shell Dash, without mocks.
const assert = require('node:assert/strict');
const cp = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { promisify } = require('node:util');
const exec = promisify(cp.exec);
const execFile = promisify(cp.execFile);

async function main() {
  assert.equal(cp.execSync('echo hi', { encoding: 'utf8' }), 'hi\n');
  console.log('PASS execSync echo');
  await new Promise((resolve, reject) => {
    const child = cp.spawn('grep', ['x']);
    let output = '';
    let errors = '';
    child.stdout.on('data', chunk => { output += chunk; });
    child.stderr.on('data', chunk => { errors += chunk; });
    child.on('error', reject);
    child.on('close', code => {
      try {
        assert.equal(code, 0);
        assert.equal(output, 'x\nextra\n');
        assert.equal(errors, '');
        console.log('PASS spawn grep piped stdin');
        resolve();
      } catch (error) { reject(error); }
    });
    child.stdin.end('no\nx\nextra\n');
  });
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'node47-'));
  try {
    fs.writeFileSync(path.join(directory, 'cwd-marker'), 'fixture');
    const result = await exec('ls', { cwd: directory });
    assert.equal(result.stdout.trim(), 'cwd-marker');
    assert.equal(result.stderr, '');
    console.log('PASS exec ls cwd');
    const environment = await execFile('printenv', ['NODE47_VALUE'], {
      env: { ...process.env, NODE47_VALUE: 'child-value' },
    });
    assert.equal(environment.stdout.trim(), 'child-value');
    assert.equal(process.env.NODE47_VALUE, undefined);
    console.log('PASS execFile env isolation');
    const nodeEnvironment = await execFile(process.execPath, ['-e', 'console.log(process.env.NODE47_VALUE)'], {
      env: { ...process.env, NODE47_VALUE: 'node-child-value' },
    });
    assert.equal(nodeEnvironment.stdout.trim(), 'node-child-value');
    assert.equal(process.env.NODE47_VALUE, undefined);
    console.log('PASS child Node env isolation');
    const sync = cp.spawnSync('grep', ['x'], { input: 'no\nx\n', encoding: 'utf8' });
    assert.equal(sync.status, 0);
    assert.equal(sync.stdout, 'x\n');
    assert.equal(sync.stderr, '');
    console.log('PASS spawnSync stdin');
    assert.throws(() => cp.execSync('exit 7'), error => error.status === 7);
    console.log('PASS nonzero status');
    await assert.rejects(exec('node47-no-such-command'), error => error.code === 127);
    assert.throws(() => cp.execFileSync('node47-no-such-command'), error => error.code === 'ENOENT');
    console.log('PASS unknown shell and execFile errors');
    assert.throws(() => cp.execFileSync(path.join(process.env.APPDIR, 'a-Shell')), error => error.code === 'ENOSYS');
    console.log('PASS native executable ENOSYS');
    assert.throws(() => cp.fork(__filename), error => error.code === 'ENOSYS');
    console.log('PASS fork IPC ENOSYS');
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
