import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function versionCode(version) {
  const match = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.exec(version);
  if (!match) throw new Error('Release version must be a stable MAJOR.MINOR.PATCH version.');
  const [major, minor, patch] = match.slice(1).map(Number);
  const code = major * 1000000 + minor * 1000 + patch;
  if (major < 1 || minor > 999 || patch > 999 || code > 2100000000) {
    throw new Error('Version is outside the Android version-code allocation.');
  }
  return code;
}

export function readVersion(root = process.cwd()) {
  const metadata = JSON.parse(readFileSync(`${root}/game/version.json`, 'utf8'));
  const code = versionCode(metadata.version);
  if (metadata.version_code !== code) {
    throw new Error('Game version metadata has an inconsistent Android version code.');
  }
  const preset = readFileSync(`${root}/game/export_presets.cfg`, 'utf8');
  const presetCode = /^version\/code=(\d+)$/m.exec(preset);
  const presetName = /^version\/name="([^"]+)"$/m.exec(preset);
  if (!presetCode || !presetName || Number(presetCode[1]) !== code || presetName[1] !== metadata.version) {
    throw new Error('Android export version differs from game version metadata.');
  }
  return {version: metadata.version, version_code: code};
}

export function stampRelease(version, root = process.cwd()) {
  const code = versionCode(version);
  const current = readVersion(root);
  // An untagged semantic-release repository proposes 1.0.0. Never let that
  // silently downgrade the explicitly selected first APK release.
  if (code < current.version_code) {
    throw new Error(`Refusing Android version downgrade from ${current.version} to ${version}.`);
  }
  const preset = `${root}/game/export_presets.cfg`;
  const text = readFileSync(preset, 'utf8');
  if (!/^version\/code=\d+$/m.test(text) || !/^version\/name="[^"]+"$/m.test(text)) {
    throw new Error('Android export preset is missing version fields.');
  }
  writeFileSync(preset, text.replace(/^version\/code=\d+$/m, `version/code=${code}`)
    .replace(/^version\/name="[^"]+"$/m, `version/name="${version}"`));
  writeFileSync(`${root}/game/version.json`, JSON.stringify({version, version_code: code}, null, 2) + '\n');
  return {version, version_code: code};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv[2] === '--version') {
    console.log(readVersion().version);
  } else {
    console.log(JSON.stringify(stampRelease(process.argv[2])));
  }
}
