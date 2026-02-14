import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Service for AES-256 encryption of downloaded content
class EncryptionService {
  static const String _keyStorageKey = 'ransh_encryption_key';
  static const String _ivStorageKey = 'ransh_encryption_iv';
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits for AES
  static const int _chunkSize = 1024 * 1024; // 1MB chunks for streaming

  final FlutterSecureStorage _secureStorage;
  Key? _encryptionKey;
  IV? _iv;

  EncryptionService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Initialize encryption service and load or generate keys
  Future<void> initialize() async {
    await _loadOrGenerateKeys();
  }

  /// Load existing keys or generate new ones
  Future<void> _loadOrGenerateKeys() async {
    try {
      // Try to load existing key
      final storedKey = await _secureStorage.read(key: _keyStorageKey);
      final storedIv = await _secureStorage.read(key: _ivStorageKey);

      if (storedKey != null && storedIv != null) {
        _encryptionKey = Key.fromBase64(storedKey);
        _iv = IV.fromBase64(storedIv);
        debugPrint('Loaded existing encryption keys');
      } else {
        await _generateAndStoreKeys();
      }
    } catch (e) {
      debugPrint('Error loading keys, generating new ones: $e');
      await _generateAndStoreKeys();
    }
  }

  /// Generate new encryption keys and store securely
  Future<void> _generateAndStoreKeys() async {
    final random = Random.secure();

    // Generate random key
    final keyBytes = List<int>.generate(_keyLength, (_) => random.nextInt(256));
    _encryptionKey = Key(Uint8List.fromList(keyBytes));

    // Generate random IV
    final ivBytes = List<int>.generate(_ivLength, (_) => random.nextInt(256));
    _iv = IV(Uint8List.fromList(ivBytes));

    // Store keys securely
    await _secureStorage.write(
      key: _keyStorageKey,
      value: _encryptionKey!.base64,
    );
    await _secureStorage.write(key: _ivStorageKey, value: _iv!.base64);

    debugPrint('Generated and stored new encryption keys');
  }

  /// Encrypt data bytes
  Uint8List encrypt(Uint8List data) {
    if (_encryptionKey == null || _iv == null) {
      throw StateError('Encryption service not initialized');
    }

    final encrypter = Encrypter(AES(_encryptionKey!, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: _iv);
    return encrypted.bytes;
  }

  /// Decrypt data bytes
  Uint8List decrypt(Uint8List encryptedData) {
    if (_encryptionKey == null || _iv == null) {
      throw StateError('Encryption service not initialized');
    }

    final encrypter = Encrypter(AES(_encryptionKey!, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(Encrypted(encryptedData), iv: _iv);
    return Uint8List.fromList(decrypted);
  }

  /// Encrypt a file and save to the encrypted downloads directory
  /// Returns the path to the encrypted file
  Future<String> encryptFile(
    String sourceFilePath,
    String destinationFileName,
  ) async {
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file not found', sourceFilePath);
    }

    final encryptedDir = await _getEncryptedDirectory();
    final destinationPath = '${encryptedDir.path}/$destinationFileName.enc';
    final destinationFile = File(destinationPath);

    // Read source file
    final sourceBytes = await sourceFile.readAsBytes();

    // Encrypt
    final encryptedBytes = encrypt(sourceBytes);

    // Write encrypted file
    await destinationFile.writeAsBytes(encryptedBytes);

    debugPrint('Encrypted file saved to: $destinationPath');
    return destinationPath;
  }

  /// Encrypt bytes and stream to file as they are received
  /// Useful for downloading and encrypting simultaneously
  Future<String> encryptStream(
    Stream<List<int>> dataStream,
    String destinationFileName, {
    Function(int bytesWritten)? onProgress,
  }) async {
    final encryptedDir = await _getEncryptedDirectory();
    final destinationPath = '${encryptedDir.path}/$destinationFileName.enc';

    // Collect all bytes first (AES-CBC requires full blocks)
    final allBytes = <int>[];
    await for (final chunk in dataStream) {
      allBytes.addAll(chunk);
      onProgress?.call(allBytes.length);
    }

    // Encrypt the complete data
    final encryptedBytes = encrypt(Uint8List.fromList(allBytes));

    // Write to file
    final destinationFile = File(destinationPath);
    await destinationFile.writeAsBytes(encryptedBytes);

    debugPrint('Encrypted stream saved to: $destinationPath');
    return destinationPath;
  }

  /// Decrypt a portion of an encrypted file (for seeking support)
  ///
  /// IMPORTANT: Due to AES-CBC mode requirements, this method must decrypt
  /// the entire file even for partial reads. The LocalStreamServer implements
  /// caching (max 3 videos) to minimize the performance impact of this.
  ///
  /// For large files with frequent seeking, the cache ensures that subsequent
  /// seeks reuse the already-decrypted content in memory.
  ///
  /// Alternative: Consider switching to AES-CTR mode for true streaming
  /// decryption if performance becomes an issue, but CBC provides better
  /// security for stored content.
  Future<Uint8List> decryptFileRange(
    String encryptedFilePath,
    int start,
    int end,
  ) async {
    final file = File(encryptedFilePath);
    if (!await file.exists()) {
      throw FileSystemException('Encrypted file not found', encryptedFilePath);
    }

    // Read the entire encrypted file (for CBC mode)
    final encryptedBytes = await file.readAsBytes();

    // Decrypt all
    final decryptedBytes = decrypt(encryptedBytes);

    // Return the requested range
    final actualEnd = end.clamp(0, decryptedBytes.length);
    final actualStart = start.clamp(0, actualEnd);

    return decryptedBytes.sublist(actualStart, actualEnd);
  }

  /// Decrypt entire file
  Future<Uint8List> decryptFile(String encryptedFilePath) async {
    final file = File(encryptedFilePath);
    if (!await file.exists()) {
      throw FileSystemException('Encrypted file not found', encryptedFilePath);
    }

    final encryptedBytes = await file.readAsBytes();
    return decrypt(encryptedBytes);
  }

  /// Get the size of the decrypted content
  Future<int> getDecryptedSize(String encryptedFilePath) async {
    final file = File(encryptedFilePath);
    if (!await file.exists()) {
      throw FileSystemException('Encrypted file not found', encryptedFilePath);
    }

    final encryptedBytes = await file.readAsBytes();
    final decryptedBytes = decrypt(encryptedBytes);
    return decryptedBytes.length;
  }

  /// Get the encrypted downloads directory (hidden from gallery)
  Future<Directory> _getEncryptedDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    final encryptedDir = Directory('${appSupport.path}/encrypted_downloads');

    if (!await encryptedDir.exists()) {
      await encryptedDir.create(recursive: true);
    }

    return encryptedDir;
  }

  /// Get path to encrypted file
  Future<String> getEncryptedFilePath(String fileName) async {
    final encryptedDir = await _getEncryptedDirectory();
    return '${encryptedDir.path}/$fileName.enc';
  }

  /// Check if encrypted file exists
  Future<bool> isFileDownloaded(String fileName) async {
    final path = await getEncryptedFilePath(fileName);
    return File(path).exists();
  }

  /// Delete encrypted file
  Future<void> deleteEncryptedFile(String fileName) async {
    final path = await getEncryptedFilePath(fileName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      debugPrint('Deleted encrypted file: $path');
    }
  }

  /// Get list of all downloaded files
  Future<List<String>> getDownloadedFiles() async {
    final encryptedDir = await _getEncryptedDirectory();
    if (!await encryptedDir.exists()) return [];

    final files = await encryptedDir.list().toList();
    return files
        .whereType<File>()
        .map((f) => f.path.split('/').last.replaceAll('.enc', ''))
        .toList();
  }

  /// Clear all downloaded content
  Future<void> clearAllDownloads() async {
    final encryptedDir = await _getEncryptedDirectory();
    if (await encryptedDir.exists()) {
      await encryptedDir.delete(recursive: true);
      debugPrint('Cleared all encrypted downloads');
    }
  }

  /// Clear stored keys (for logout)
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    _encryptionKey = null;
    _iv = null;
    debugPrint('Cleared encryption keys');
  }

  /// Save unencrypted file (e.g. thumbnails)
  Future<String> saveUnencryptedFile(Uint8List data, String fileName) async {
    final dir = await _getEncryptedDirectory();
    final path = '${dir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(data);
    return path;
  }

  /// Get path to unencrypted file
  Future<String> getUnencryptedFilePath(String fileName) async {
    final dir = await _getEncryptedDirectory();
    return '${dir.path}/$fileName';
  }

  /// Check if file exists (generic)
  Future<bool> fileExists(String fileName) async {
    final dir = await _getEncryptedDirectory();
    final path = '${dir.path}/$fileName';
    return File(path).exists();
  }
}
