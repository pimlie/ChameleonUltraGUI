import 'dart:io';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:chameleonultragui/bridge/chameleon.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> asyncSleep(int milliseconds) async {
  await Future.delayed(Duration(milliseconds: milliseconds));
}

String bytesToHex(Uint8List bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
}

String bytesToHexSpace(Uint8List bytes) {
  return bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();
}

Uint8List hexToBytes(String hex) {
  List<int> bytes = [];
  for (int i = 0; i < hex.length; i += 2) {
    int byte = int.parse(hex.substring(i, i + 2), radix: 16);
    bytes.add(byte);
  }
  return Uint8List.fromList(bytes);
}

int bytesToU32(Uint8List byteArray) {
  return byteArray.buffer.asByteData().getUint32(0, Endian.big);
}

int bytesToU64(Uint8List byteArray) {
  return byteArray.buffer.asByteData().getUint64(0, Endian.big);
}

Uint8List u64ToBytes(int u64) {
  if (!kIsWeb) {
    // Uint64 accessor not supported by dart2js
    final ByteData byteData = ByteData(8)..setUint64(0, u64, Endian.big);
    return byteData.buffer.asUint8List();
  }

  final bigInt = BigInt.from(u64);
  final data = Uint8List((bigInt.bitLength / 8).ceil());
  var tmp = bigInt;

  for (var i = 1; i <= data.lengthInBytes; i++) {
    final int8 = tmp.toUnsigned(8).toInt();
    data[i - 1] = int8;
    tmp = tmp >> 8;
  }

  return data;
}


bool isValidHexString(String hexString) {
  final hexPattern = RegExp(r'^[A-Fa-f0-9]+$');
  return hexPattern.hasMatch(hexString);
}

int calculateCRC32(List<int> data) {
  Uint8List bytes = Uint8List.fromList(data);
  Uint32List crcTable = generateCRCTable();
  int crc = 0xFFFFFFFF;

  for (int i = 0; i < bytes.length; i++) {
    crc = (crc >> 8) ^ crcTable[(crc ^ bytes[i]) & 0xFF];
  }

  crc = crc ^ 0xFFFFFFFF;
  return crc;
}

Uint32List generateCRCTable() {
  Uint32List crcTable = Uint32List(256);
  for (int i = 0; i < 256; i++) {
    int crc = i;
    for (int j = 0; j < 8; j++) {
      if ((crc & 1) == 1) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc = crc >> 1;
      }
    }
    crcTable[i] = crc;
  }
  return crcTable;
}

String chameleonTagToString(ChameleonTag tag) {
  if (tag == ChameleonTag.mifareMini) {
    return "Mifare Mini";
  } else if (tag == ChameleonTag.mifare1K) {
    return "Mifare Classic 1K";
  } else if (tag == ChameleonTag.mifare2K) {
    return "Mifare Classic 2K";
  } else if (tag == ChameleonTag.mifare4K) {
    return "Mifare Classic 4K";
  } else if (tag == ChameleonTag.em410X) {
    return "EM410X";
  } else if (tag == ChameleonTag.ntag213) {
    return "NTAG213";
  } else if (tag == ChameleonTag.ntag215) {
    return "NTAG215";
  } else if (tag == ChameleonTag.ntag216) {
    return "NTAG216";
  } else {
    return "Unknown";
  }
}

ChameleonTag numberToChameleonTag(int type) {
  if (type == ChameleonTag.mifareMini.value) {
    return ChameleonTag.mifareMini;
  } else if (type == ChameleonTag.mifare1K.value) {
    return ChameleonTag.mifare1K;
  } else if (type == ChameleonTag.mifare2K.value) {
    return ChameleonTag.mifare2K;
  } else if (type == ChameleonTag.mifare4K.value) {
    return ChameleonTag.mifare4K;
  } else if (type == ChameleonTag.em410X.value) {
    return ChameleonTag.em410X;
  } else if (type == ChameleonTag.ntag213.value) {
    return ChameleonTag.ntag213;
  } else if (type == ChameleonTag.ntag215.value) {
    return ChameleonTag.ntag215;
  } else if (type == ChameleonTag.ntag216.value) {
    return ChameleonTag.ntag216;
  } else {
    return ChameleonTag.unknown;
  }
}

ChameleonTag getTagTypeByValue(int value) {
  return ChameleonTag.values.firstWhere((element) => element.value == value,
      orElse: () => ChameleonTag.unknown);
}

String platformToPath() {
  if (Platform.isAndroid) {
    return "android";
  } else if (Platform.isIOS) {
    return "ios";
  } else if (Platform.isLinux) {
    return "linux";
  } else if (Platform.isMacOS) {
    return "macos";
  } else if (Platform.isWindows) {
    return "windows";
  } else {
    return "../";
  }
}

String numToVerCode(int versionCode) {
  int major = (versionCode >> 8) & 0xFF;
  int minor = versionCode & 0xFF;
  return '$major.$minor';
}
