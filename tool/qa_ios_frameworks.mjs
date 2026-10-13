import fs from 'node:fs';
import path from 'node:path';

const vendorDir = path.resolve('ios/Runner/Vendor');
const frameworkNames = [
  'ABParTool',
  'BluetoothLibrary',
  'DFUnits',
  'GRDFUSDK',
  'JLDialUnit',
  'JL_BLEKit',
  'QCBandSDK',
  'VeepooBleSDK',
  'ZipZap',
];

const rows = frameworkNames.map((name) => {
  const binaryPath = path.join(vendorDir, `${name}.framework`, name);
  if (!fs.existsSync(binaryPath)) {
    return {framework: name, exists: false, format: '', architectures: ''};
  }
  const bytes = fs.readFileSync(binaryPath);
  const parsed = parseMachO(bytes);
  return {
    framework: name,
    exists: true,
    format: parsed.format,
    architectures: parsed.architectures.join(', '),
  };
});

console.table(rows);

const invalid = rows.filter(
  (row) => !row.exists || !row.architectures.split(', ').includes('arm64'),
);
if (invalid.length > 0) {
  console.error(
    `Missing iPhone arm64 support: ${invalid.map((row) => row.framework).join(', ')}`,
  );
  process.exitCode = 1;
}

function parseMachO(bytes) {
  if (bytes.subarray(0, 8).toString('ascii') === '!<arch>\n') {
    return {format: 'static archive', architectures: architecturesInArchive(bytes)};
  }

  const magic = bytes.readUInt32BE(0);
  if (magic === 0xcafebabe || magic === 0xcafebabf) {
    const is64 = magic === 0xcafebabf;
    const count = bytes.readUInt32BE(4);
    const stride = is64 ? 32 : 20;
    const architectures = [];
    for (let index = 0; index < count; index++) {
      const offset = 8 + index * stride;
      architectures.push(cpuName(bytes.readUInt32BE(offset)));
    }
    return {format: is64 ? 'fat64 Mach-O' : 'fat Mach-O', architectures};
  }

  const littleEndian = magic === 0xcefaedfe || magic === 0xcffaedfe;
  const thinMagic = littleEndian ? bytes.readUInt32LE(0) : magic;
  if (thinMagic === 0xfeedface || thinMagic === 0xfeedfacf) {
    const cpu = littleEndian ? bytes.readUInt32LE(4) : bytes.readUInt32BE(4);
    return {format: 'thin Mach-O', architectures: [cpuName(cpu)]};
  }

  return {format: `unknown 0x${magic.toString(16)}`, architectures: []};
}

function architecturesInArchive(bytes) {
  const names = new Set();
  for (let offset = 8; offset + 60 <= bytes.length; ) {
    const memberName = bytes
      .subarray(offset, offset + 16)
      .toString('ascii')
      .trim();
    const size = Number.parseInt(bytes.subarray(offset + 48, offset + 58).toString('ascii').trim(), 10);
    const bodyOffset = offset + 60;
    if (!Number.isFinite(size) || bodyOffset + size > bytes.length) break;
    const extendedNameLength = memberName.startsWith('#1/')
      ? Number.parseInt(memberName.slice(3), 10)
      : 0;
    const payloadOffset = bodyOffset + (extendedNameLength || 0);
    const member = bytes.subarray(payloadOffset, bodyOffset + size);
    if (member.length >= 8) {
      const magic = member.readUInt32BE(0);
      const littleEndian = magic === 0xcefaedfe || magic === 0xcffaedfe;
      const thinMagic = littleEndian ? member.readUInt32LE(0) : magic;
      if (thinMagic === 0xfeedface || thinMagic === 0xfeedfacf) {
        const cpu = littleEndian ? member.readUInt32LE(4) : member.readUInt32BE(4);
        names.add(cpuName(cpu));
      }
    }
    offset = bodyOffset + size + (size % 2);
  }
  return [...names];
}

function cpuName(cpu) {
  switch (cpu >>> 0) {
    case 0x0100000c:
      return 'arm64';
    case 0x01000007:
      return 'x86_64';
    case 12:
      return 'arm';
    case 7:
      return 'x86';
    default:
      return `cpu-0x${(cpu >>> 0).toString(16)}`;
  }
}
