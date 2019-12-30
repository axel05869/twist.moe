import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

final BLOCK_SIZE = 16;

// https://stackoverflow.com/a/36780727/8608146

final KEY = "LXgIVP&PorO68Rq7dTx8N^lP!Fa5sGJ^*XK";
// Get this by setting a breakpoint
Uint8List bytesToKey(Uint8List data, Uint8List salt, {int output: 48}) {
  if (salt.length != 8) {
    throw DecryptionError("");
  }
  // create a copy of the data
  List<int> dataB = data.toList();
  // data += salt
  dataB.addAll(salt);
  // md5 hash
  Uint8List key = md5.convert(dataB).bytes;
  List<int> final_key = key.toList();
  while (final_key.length < output) {
    key = md5.convert(key + dataB).bytes;
    // final_key += key
    final_key.addAll(key);
  }
  // free the list (not needed)
  dataB.clear();
  return Uint8List.fromList(
    final_key.sublist(0, output),
  );
}

String decrypt(String encrypted, String passphrase) {
  final bytes = base64.decode(encrypted);
  if (utf8.decode(bytes.sublist(0, 8)) != "Salted__") {
    throw DecryptionError("");
  }
  final salt = bytes.sublist(8, 16);
  final key_iv = bytesToKey(utf8.encode(passphrase), salt);
  final key = key_iv.sublist(0, 32);
  final iv = key_iv.sublist(32);

  // Taken from https://gist.github.com/phanirithvij/97bb0648c9888b9285fdcfd3f7b4a291
  // These files are in helpers/ i.e. aes_encryption_helper.dart
  // Look at `Aeshelper.decrypt`
  final aes = AESFastEngine();
  final cipher = CBCBlockCipher(aes);
  KeyParameter keyParam = KeyParameter(key);
  final params = ParametersWithIV(keyParam, iv);
  cipher.init(false, params);

  int cipherLen = bytes.length - aes.blockSize;
  Uint8List cipherBytes = Uint8List(cipherLen)
    ..setRange(0, cipherLen, bytes, aes.blockSize);
  Uint8List paddedText = processBlocks(cipher, cipherBytes);
  Uint8List textBytes = unpad(paddedText);

  return String.fromCharCodes(textBytes);
}

List<String> decryptUrls(Iterable<String> urls) {
  return urls.map((url) => decrypt(url, KEY)).toList();
}

// Taken from https://gist.github.com/phanirithvij/97bb0648c9888b9285fdcfd3f7b4a291
// Look at `Aeshelper.processBlocks`
// Not sure what this does
Uint8List processBlocks(BlockCipher cipher, Uint8List inp) {
  var out = Uint8List(inp.lengthInBytes);

  for (var offset = 0; offset < inp.lengthInBytes;) {
    var len = cipher.processBlock(inp, offset, out, offset);
    offset += len;
  }

  return out;
}

// Taken from https://gist.github.com/phanirithvij/97bb0648c9888b9285fdcfd3f7b4a291
// Look at `Aeshelper.unpad`
// Some bytes to the right are removed from the decrypted string
Uint8List unpad(Uint8List src) {
  var pad = PKCS7Padding();
  pad.init(null);

  int padLength = pad.padCount(src);
  int len = src.length - padLength;

  return Uint8List(len)..setRange(0, len, src);
}

class DecryptionError implements Exception {
  final String message;
  const DecryptionError(this.message);
  @override
  String toString() => """Decryption Error has occured.
      Please report at https://github.com/phanirithvij/twist.moe/issues
      """
      .trim();
}