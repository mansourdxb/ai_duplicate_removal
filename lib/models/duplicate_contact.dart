import 'dart:typed_data';

class DuplicateContact {
  final String id;
  final String? displayName;
  final String? givenName;
  final String? familyName;
  final List<ContactPhone>? phoneNumbers;
  final List<ContactEmail>? emails;
  final List<ContactAddress>? addresses;
  final String? company;
  final String? jobTitle;
  final DateTime? birthday;
  final String? note;
  final DateTime? lastModified;
  final double similarityScore;
  final double qualityScore;
  final List<String> matchingFields;
  final Uint8List? avatar; // ✅ Add this line

  DuplicateContact({
    required this.id,
    this.displayName,
    this.givenName,
    this.familyName,
    this.phoneNumbers,
    this.emails,
    this.addresses,
    this.company,
    this.jobTitle,
    this.birthday,
    this.note,
    this.lastModified,
    this.similarityScore = 0.0,
    this.qualityScore = 0.0,
    this.matchingFields = const [],
    this.avatar, // ✅ Add this to the constructor
  });

  // Create from contacts_service Contact
  factory DuplicateContact.fromContact(dynamic contact) {
    return DuplicateContact(
      id: contact.identifier ?? '',
      displayName: contact.displayName,
      givenName: contact.givenName,
      familyName: contact.familyName,
      phoneNumbers: contact.phones?.map<ContactPhone>((phone) => 
        ContactPhone(
          value: phone.value,
          label: phone.label,
        )).toList(),
      emails: contact.emails?.map<ContactEmail>((email) => 
        ContactEmail(
          value: email.value,
          label: email.label,
        )).toList(),
      addresses: contact.postalAddresses?.map<ContactAddress>((address) => 
        ContactAddress(
          street: address.street,
          city: address.city,
          region: address.region,
          postcode: address.postcode,
          country: address.country,
          label: address.label,
        )).toList(),
      company: contact.company,
      jobTitle: contact.jobTitle,
      birthday: contact.birthday,
      note: contact.note,
      lastModified: DateTime.now(),
      qualityScore: _calculateQualityScore(contact),
    );
  }

  // Calculate quality score based on completeness of data
  static double _calculateQualityScore(dynamic contact) {
    double score = 0.0;
    
    // Name completeness (30%)
    if (contact.displayName?.isNotEmpty == true) score += 15;
    if (contact.givenName?.isNotEmpty == true) score += 10;
    if (contact.familyName?.isNotEmpty == true) score += 5;
    
    // Contact info completeness (40%)
    if (contact.phones?.isNotEmpty == true) score += 20;
    if (contact.emails?.isNotEmpty == true) score += 20;
    
    // Additional info completeness (30%)
    if (contact.company?.isNotEmpty == true) score += 10;
    if (contact.jobTitle?.isNotEmpty == true) score += 5;
    if (contact.postalAddresses?.isNotEmpty == true) score += 10;
    if (contact.birthday != null) score += 3;
    if (contact.note?.isNotEmpty == true) score += 2;
    
    return score;
  }

  // Calculate similarity between two contacts
  double calculateSimilarity(DuplicateContact other) {
    double similarity = 0.0;
    int comparisons = 0;
    List<String> matches = [];

    // Name similarity (40% weight)
    if (displayName != null && other.displayName != null) {
      final nameSim = stringSimilarity(displayName!, other.displayName!);
      if (nameSim > 0.8) {
        similarity += nameSim * 0.4;
        matches.add('name');
      }
      comparisons++;
    }

    // Phone similarity (30% weight)
    if (phoneNumbers?.isNotEmpty == true && other.phoneNumbers?.isNotEmpty == true) {
      bool phoneMatch = false;
      for (var phone1 in phoneNumbers!) {
        for (var phone2 in other.phoneNumbers!) {
          if (phonesSimilar(phone1.value, phone2.value)) {
            similarity += 0.3;
            matches.add('phone');
            phoneMatch = true;
            break;
          }
        }
        if (phoneMatch) break;
      }
      comparisons++;
    }

    // Email similarity (25% weight)
    if (emails?.isNotEmpty == true && other.emails?.isNotEmpty == true) {
      bool emailMatch = false;
      for (var email1 in emails!) {
        for (var email2 in other.emails!) {
          if (email1.value?.toLowerCase() == email2.value?.toLowerCase()) {
            similarity += 0.25;
            matches.add('email');
            emailMatch = true;
            break;
          }
        }
        if (emailMatch) break;
      }
      comparisons++;
    }

    // Company similarity (5% weight)
    if (company != null && other.company != null) {
      final companySim = stringSimilarity(company!, other.company!);
      if (companySim > 0.7) {
        similarity += companySim * 0.05;
        matches.add('company');
      }
      comparisons++;
    }

    return comparisons > 0 ? similarity : 0.0;
  }

  // String similarity using Levenshtein distance
  double stringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = [s1.length, s2.length].reduce((a, b) => a > b ? a : b);
    final distance = _levenshteinDistance(s1.toLowerCase(), s2.toLowerCase());
    
    return 1.0 - (distance / maxLen);
  }

  // Levenshtein distance calculation
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  // Check if phone numbers are similar
  bool phonesSimilar(String? phone1, String? phone2) {
    if (phone1 == null || phone2 == null) return false;
    
    // Remove all non-digit characters
    final clean1 = phone1.replaceAll(RegExp(r'[^\d]'), '');
    final clean2 = phone2.replaceAll(RegExp(r'[^\d]'), '');
    
    if (clean1.isEmpty || clean2.isEmpty) return false;
    
    // Check if they're exactly the same
    if (clean1 == clean2) return true;
    
    // Check if one is a subset of the other (for international numbers)
    if (clean1.length >= 7 && clean2.length >= 7) {
      final suffix1 = clean1.substring(clean1.length - 7);
      final suffix2 = clean2.substring(clean2.length - 7);
      return suffix1 == suffix2;
    }
    
    return false;
  }

  // Create a copy with updated similarity score
  DuplicateContact copyWithSimilarity(double similarity, List<String> matches) {
    return DuplicateContact(
      id: id,
      displayName: displayName,
      givenName: givenName,
      familyName: familyName,
      phoneNumbers: phoneNumbers,
      emails: emails,
      addresses: addresses,
      company: company,
      jobTitle: jobTitle,
      birthday: birthday,
      note: note,
      lastModified: lastModified,
      similarityScore: similarity,
      qualityScore: qualityScore,
      matchingFields: matches,
    );
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is DuplicateContact &&
    runtimeType == other.runtimeType &&
    id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DuplicateContact{id: $id, name: $displayName, quality: $qualityScore, similarity: $similarityScore}';
  }
}

// Supporting classes for contact data
class ContactPhone {
  final String? value;
  final String? label;

  ContactPhone({this.value, this.label});

  @override
  String toString() => '$label: $value';
}

class ContactEmail {
  final String? value;
  final String? label;

  ContactEmail({this.value, this.label});

  @override
  String toString() => '$label: $value';
}

class ContactAddress {
  final String? street;
  final String? city;
  final String? region;
  final String? postcode;
  final String? country;
  final String? label;

  ContactAddress({
    this.street,
    this.city,
    this.region,
    this.postcode,
    this.country,
    this.label,
  });

  @override
  String toString() {
    final parts = [street, city, region, postcode, country]
        .where((part) => part?.isNotEmpty == true)
        .join(', ');
    return '$label: $parts';
  }
}