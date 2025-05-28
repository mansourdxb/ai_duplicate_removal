import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import '../models/duplicate_item.dart';
import 'package:ai_duplicate_removal/models/duplicate_contact.dart';


class DuplicateDetector {
  static const double nameThreshold = 0.8;
  static const double phoneThreshold = 0.9;
  static const double emailThreshold = 0.9;

  static Future<List<DuplicateItem>> findFileDuplicates(
    List<DuplicateContact> contacts,
    String strategy,
  ) async {
    final duplicates = <DuplicateItem>[];
    final processedContacts = <String>{};

    for (int i = 0; i < contacts.length; i++) {
      if (processedContacts.contains(contacts[i].id)) continue;

      final duplicateGroup = <DuplicateContact>[contacts[i]];
      processedContacts.add(contacts[i].id);

      for (int j = i + 1; j < contacts.length; j++) {
        if (processedContacts.contains(contacts[j].id)) continue;

        bool isDuplicate = false;

        switch (strategy) {
          case 'name':
            isDuplicate = _isNameSimilar(contacts[i], contacts[j]);
            break;
          case 'phone':
            isDuplicate = _isPhoneSimilar(contacts[i], contacts[j]);
            break;
          case 'email':
            isDuplicate = _isEmailSimilar(contacts[i], contacts[j]);
            break;
          case 'comprehensive':
            isDuplicate = _isComprehensiveSimilar(contacts[i], contacts[j]);
            break;
          case 'ai':
            isDuplicate = await _isAISimilar(contacts[i], contacts[j]);
            break;
        }

        if (isDuplicate) {
          duplicateGroup.add(contacts[j]);
          processedContacts.add(contacts[j].id);
        }
      }

      if (duplicateGroup.length > 1) {
        duplicates.add(DuplicateItem(
          contacts: duplicateGroup,
          similarity: _calculateGroupSimilarity(duplicateGroup),
        ));
      }
    }

    return duplicates;
  }

  static bool _isNameSimilar(DuplicateContact contact1, DuplicateContact contact2) {
  if (contact1.displayName == null || contact1.displayName!.isEmpty ||
    contact2.displayName == null || contact2.displayName!.isEmpty) {
  return false;
}



   final similarity = _calculateStringSimilarity(
  contact1.displayName?.toLowerCase() ?? '',
  contact2.displayName?.toLowerCase() ?? '',
);

    return similarity >= nameThreshold;
  }

  static String _hashString(String input) {
    final bytes = input.codeUnits;
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
static Future<List<DuplicateItem>> findDuplicatesPlaceholder(
  List<String> paths, {
  Function(String)? onProgress,
}) async {
  final Map<String, List<String>> hashToPaths = {};
  final List<DuplicateItem> duplicates = [];

  for (final path in paths) {
    try {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      hashToPaths.putIfAbsent(hash, () => []).add(path);
      onProgress?.call('Processed: $path');
    } catch (e) {
      onProgress?.call('Error reading: $path');
    }
  }

  for (final entry in hashToPaths.entries) {
  if (entry.value.length > 1) {
    final firstPath = entry.value.first;
    final file = File(firstPath);
    final stat = await file.stat();
    final extension = file.path.split('.').last.toLowerCase();

    duplicates.add(DuplicateItem(
      paths: entry.value,
      path: firstPath,
      name: file.uri.pathSegments.last,
      size: stat.size,
      lastModified: stat.modified,
      fileType: DuplicateItem.getFileType(extension).toString().split('.').last,
      similarity: 1.0,
    ));
  }
}

  return duplicates;
}

 static bool _isPhoneSimilar(DuplicateContact contact1, DuplicateContact contact2) {
  if (contact1.phoneNumbers == null || contact2.phoneNumbers == null) return false;

  for (final phone1 in contact1.phoneNumbers!) {
    for (final phone2 in contact2.phoneNumbers!) {
      final cleanPhone1 = _cleanPhoneNumber(phone1.value ?? '');
      final cleanPhone2 = _cleanPhoneNumber(phone2.value ?? '');

      if (cleanPhone1.isNotEmpty && cleanPhone2.isNotEmpty) {
        final similarity = _calculateStringSimilarity(cleanPhone1, cleanPhone2);
        if (similarity >= phoneThreshold) {
          return true;
        }
      }
    }
  }
  return false;
}


static bool _isEmailSimilar(DuplicateContact contact1, DuplicateContact contact2) {
  if (contact1.emails == null || contact2.emails == null) return false;

  for (final email1 in contact1.emails!) {
    for (final email2 in contact2.emails!) {
      if (email1.value?.isNotEmpty == true && email2.value?.isNotEmpty == true) {
        final similarity = _calculateStringSimilarity(
          email1.value!.toLowerCase(),
          email2.value!.toLowerCase(),
        );
        if (similarity >= emailThreshold) {
          return true;
        }
      }
    }
  }
  return false;
}



  static bool _isComprehensiveSimilar(DuplicateContact contact1, DuplicateContact contact2) {
    final nameScore = _isNameSimilar(contact1, contact2) ? 1.0 : 0.0;
    final phoneScore = _isPhoneSimilar(contact1, contact2) ? 1.0 : 0.0;
    final emailScore = _isEmailSimilar(contact1, contact2) ? 1.0 : 0.0;

    final totalScore = (nameScore + phoneScore + emailScore) / 3.0;
    return totalScore >= 0.6;
  }

  static Future<bool> _isAISimilar(DuplicateContact contact1, DuplicateContact contact2) async {
    final features1 = await _extractFeatures(contact1);
    final features2 = await _extractFeatures(contact2);

    final similarity = _calculateFeatureSimilarity(features1, features2);
    return similarity >= 0.75;
  }

  static Future<Map<String, dynamic>> _extractFeatures(DuplicateContact contact) async {
  final features = <String, dynamic>{};

  final displayName = contact.displayName ?? '';
  features['name_length'] = displayName.length;
  features['name_words'] = displayName.split(' ').length;
  features['name_hash'] = _hashString(displayName.toLowerCase());

  final phoneNumbers = contact.phoneNumbers ?? [];
  features['phone_count'] = phoneNumbers.length;
  if (phoneNumbers.isNotEmpty && phoneNumbers.first.value != null) {
    features['first_phone_hash'] = _hashString(_cleanPhoneNumber(phoneNumbers.first.value!));
  }

  final emails = contact.emails ?? [];
  features['email_count'] = emails.length;
  if (emails.isNotEmpty && emails.first.value != null) {
    features['first_email_hash'] = _hashString(emails.first.value!.toLowerCase());
  }

  if (contact.avatar != null) {
    features['avatar_hash'] = await _calculateImageHash(contact.avatar!);
  }

  return features;
}


  static Future<String> _calculateImageHash(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return '';

      final resized = img.copyResize(image, width: 8, height: 8);
      final grayscale = img.grayscale(resized);

      int totalValue = 0;
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = grayscale.getPixel(x, y);
          totalValue += img.getLuminance(pixel).round();
        }
      }
      final average = totalValue / 64;

      String hash = '';
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = grayscale.getPixel(x, y);
          hash += img.getLuminance(pixel) > average ? '1' : '0';
        }
      }

      return hash;
    } catch (e) {
      return '';
    }
  }

  static double _calculateFeatureSimilarity(Map<String, dynamic> features1, Map<String, dynamic> features2) {
    double totalSimilarity = 0.0;
    int comparisons = 0;

    if (features1['name_hash'] == features2['name_hash']) {
      totalSimilarity += 1.0;
    }
    comparisons++;

    if (features1.containsKey('first_phone_hash') && features2.containsKey('first_phone_hash')) {
      if (features1['first_phone_hash'] == features2['first_phone_hash']) {
        totalSimilarity += 1.0;
      }
      comparisons++;
    }

    if (features1.containsKey('first_email_hash') && features2.containsKey('first_email_hash')) {
      if (features1['first_email_hash'] == features2['first_email_hash']) {
        totalSimilarity += 1.0;
      }
      comparisons++;
    }

    if (features1.containsKey('avatar_hash') && features2.containsKey('avatar_hash')) {
      final hash1 = features1['avatar_hash'] as String;
      final hash2 = features2['avatar_hash'] as String;
      if (hash1.isNotEmpty && hash2.isNotEmpty) {
        totalSimilarity += _calculateHammingDistance(hash1, hash2);
        comparisons++;
      }
    }

    return comparisons > 0 ? totalSimilarity / comparisons : 0.0;
  }

  static double _calculateHammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) return 0.0;

    int differences = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) differences++;
    }

    return 1.0 - (differences / hash1.length);
  }

  static String _cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  static double _calculateStringSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final matrix = List.generate(
      str1.length + 1,
      (i) => List.filled(str2.length + 1, 0),
    );

    for (int i = 0; i <= str1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= str2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= str1.length; i++) {
      for (int j = 1; j <= str2.length; j++) {
        final cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    final maxLength = max(str1.length, str2.length);
    return 1.0 - (matrix[str1.length][str2.length] / maxLength);
  }

  static double _calculateGroupSimilarity(List<DuplicateContact> group) {
    if (group.length < 2) return 0.0;

    double totalSimilarity = 0.0;
    int comparisons = 0;

    for (int i = 0; i < group.length; i++) {
      for (int j = i + 1; j < group.length; j++) {
        totalSimilarity += _calculatePairSimilarity(group[i], group[j]);
        comparisons++;
      }
    }

    return comparisons > 0 ? totalSimilarity / comparisons : 0.0;
  }

static double _calculatePairSimilarity(DuplicateContact contact1, DuplicateContact contact2) {
  // Use empty string if displayName is null
  final name1 = contact1.displayName?.toLowerCase() ?? '';
  final name2 = contact2.displayName?.toLowerCase() ?? '';
  final nameScore = _calculateStringSimilarity(name1, name2);

  double phoneScore = 0.0;
  if (contact1.phoneNumbers?.isNotEmpty == true && contact2.phoneNumbers?.isNotEmpty == true) {
    final phone1 = contact1.phoneNumbers!.first.value ?? '';
    final phone2 = contact2.phoneNumbers!.first.value ?? '';
    phoneScore = _calculateStringSimilarity(
      _cleanPhoneNumber(phone1),
      _cleanPhoneNumber(phone2),
    );
  }

  double emailScore = 0.0;
  if (contact1.emails?.isNotEmpty == true && contact2.emails?.isNotEmpty == true) {
    final email1 = contact1.emails!.first.value ?? '';
    final email2 = contact2.emails!.first.value ?? '';
    emailScore = _calculateStringSimilarity(
      email1.toLowerCase(),
      email2.toLowerCase(),
    );
  }

  return (nameScore + phoneScore + emailScore) / 3.0;
}


  // Preserved original placeholder
  Future<List<List<DuplicateItem>>> findDuplicates(
    List<String> paths, {
    Function(String)? onProgress,
  }) async {
    // Fake implementation for now
    return [];
  }

  // Optional: contact wrapper calling real detection logic
  Future<List<DuplicateItem>> findContactDuplicates(
  List<DuplicateContact> contacts, {
  required String strategy,
  Function(String)? onProgress,
}) async {
  return await findFileDuplicates(contacts, strategy);
}

}
