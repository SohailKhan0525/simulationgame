import test from 'node:test';
import assert from 'node:assert/strict';
import { versionCode, stampRelease } from './release.mjs';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

test('version codes remain monotonic across patch, minor and major releases', () => {
  const versions = ['1.0.0', '1.0.1', '1.0.999', '1.1.0', '1.999.999', '2.0.0'];
  const values = versions.map(versionCode);
  assert.equal(values[0], 1000000);
  for (let i = 1; i < values.length; i++) assert.ok(values[i] > values[i - 1]);
});
test('reject ambiguous, overflowing and prerelease version codes', () => {
  for (const value of ['1.1000.0', '1.0.1000', '2101.0.0', '01.2.3', '1.0.0-rc.1', '0.1.0', '../oops']) {
    assert.throws(() => versionCode(value));
  }
});
test('the Android package and game metadata receive exactly the same version', () => {
  const root = mkdtempSync(join(tmpdir(), 'qofeno-release-'));
  try {
    mkdirSync(`${root}/game`);
    writeFileSync(`${root}/game/export_presets.cfg`, 'version/code=1000000\nversion/name="1.0.0"\npackage/name="Qofeno Drive"\n');
    stampRelease('2.3.4', root);
    const metadata = JSON.parse(readFileSync(`${root}/game/version.json`, 'utf8'));
    assert.deepEqual(metadata, {version:'2.3.4', version_code:2003004});
    assert.match(readFileSync(`${root}/game/export_presets.cfg`, 'utf8'), /version\/code=2003004\nversion\/name="2.3.4"/);
  } finally { rmSync(root, {recursive:true, force:true}); }
});
