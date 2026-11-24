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

export function stampRelease(version, root = process.cwd()) {
  const code = versionCode(version);
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
  console.log(JSON.stringify(stampRelease(process.argv[2])));
}
