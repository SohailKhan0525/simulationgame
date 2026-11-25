import test from 'node:test';
import assert from 'node:assert/strict';
import { versionCode, stampRelease, readVersion } from './release.mjs';
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
    writeFileSync(`${root}/game/version.json`, JSON.stringify({version:'1.0.0', version_code:1000000}));
    stampRelease('2.3.4', root);
    const metadata = JSON.parse(readFileSync(`${root}/game/version.json`, 'utf8'));
    assert.deepEqual(metadata, {version:'2.3.4', version_code:2003004});
    assert.match(readFileSync(`${root}/game/export_presets.cfg`, 'utf8'), /version\/code=2003004\nversion\/name="2.3.4"/);
  } finally { rmSync(root, {recursive:true, force:true}); }
});

test('first release honors the checked-in upgrade and rejects a semantic-release downgrade', () => {
  const root = mkdtempSync(join(tmpdir(), 'qofeno-bootstrap-'));
  try {
    mkdirSync(`${root}/game`);
    const preset = 'version/code=1001000\nversion/name="1.1.0"\npackage/signed=true\n';
    const metadata = JSON.stringify({version:'1.1.0', version_code:1001000});
    writeFileSync(`${root}/game/export_presets.cfg`, preset);
    writeFileSync(`${root}/game/version.json`, metadata);
    assert.deepEqual(readVersion(root), {version:'1.1.0', version_code:1001000});
    assert.throws(() => stampRelease('1.0.0', root), /Refusing Android version downgrade/);
    assert.equal(readFileSync(`${root}/game/export_presets.cfg`, 'utf8'), preset);
    assert.equal(readFileSync(`${root}/game/version.json`, 'utf8'), metadata);
    assert.deepEqual(stampRelease('1.1.0', root), {version:'1.1.0', version_code:1001000});
    assert.match(readFileSync(`${root}/game/export_presets.cfg`, 'utf8'), /package\/signed=true/);
    stampRelease('1.1.1', root);
    assert.deepEqual(readVersion(root), {version:'1.1.1', version_code:1001001});
  } finally { rmSync(root, {recursive:true, force:true}); }
});

test('release refuses inconsistent Android and game version metadata', () => {
  const root = mkdtempSync(join(tmpdir(), 'qofeno-metadata-'));
  try {
    mkdirSync(`${root}/game`);
    const metadata = JSON.stringify({version:'1.1.0', version_code:1001000});
    writeFileSync(`${root}/game/version.json`, metadata);
    writeFileSync(`${root}/game/export_presets.cfg`, 'version/code=1000000\nversion/name="1.0.0"\n');
    assert.throws(() => readVersion(root), /differs from game version/);
    assert.throws(() => stampRelease('1.2.0', root), /differs from game version/);
    assert.equal(readFileSync(`${root}/game/version.json`, 'utf8'), metadata);
    writeFileSync(`${root}/game/version.json`, JSON.stringify({version:'1.1.0', version_code:1000000}));
    assert.throws(() => readVersion(root), /inconsistent Android version code/);
  } finally { rmSync(root, {recursive:true, force:true}); }
});
