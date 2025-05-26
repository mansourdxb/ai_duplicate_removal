import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/duplicate_contact.dart';

class ContactService {
  static const double SIMILARITY_THRESHOLD = 0.6;
  static const double HIGH_SIMILARITY_THRESHOLD = 0.8;

  /// Get all contacts from device
  Future<List<DuplicateContact>> getAllContacts() async {
    final permission = await _requestContactsPermission();
    if (!permission) {
      throw Exception('Contacts permission denied');
    }

    try {
      final contacts = await ContactsService.getContacts(
        withThumbnails: false,
        photoHighResolution: false,
      );

      return contacts
          .map((contact) => DuplicateContact.fromContact(contact))
          .where((contact) => contact.displayName?.isNotEmpty == true)
          .toList();
    } catch (e) {
      throw Exception('Failed to load contacts: $e');
    }
  }

  /// Find duplicate contacts using advanced matching algorithm
  Future<List<List<DuplicateContact>>> findDuplicates({
    double similarityThreshold = SIMILARITY_THRESHOLD,
    bool includePartialMatches = true,
  }) async {
    final contacts = await getAllContacts();
    final duplicateGroups = <List<DuplicateContact>>[];
    final processedContacts = <String>{};

    print('Analyzing ${contacts.length} contacts for duplicates...');

    for (int i = 0; i < contacts.length; i++) {
      if (processedContacts.contains(contacts[i].id)) continue;

      final currentContact = contacts[i];
      final duplicateGroup = <DuplicateContact>[currentContact];
      processedContacts.add(currentContact.id);

      // Compare with remaining contacts
      for (int j = i + 1; j < contacts.length; j++) {
        if (processedContacts.contains(contacts[j].id)) continue;

        final otherContact = contacts[j];
        final similarity = currentContact.calculateSimilarity(otherContact);

        if (similarity >= similarityThreshold) {
          // Add similar contact to group
          final similarContact = otherContact.copyWithSimilarity(
            similarity,
            _getMatchingFields(currentContact, otherContact),
          );
          
          duplicateGroup.add(similarContact);
          processedContacts.add(otherContact.id);
        }
      }

      // Only add groups with actual duplicates
      if (duplicateGroup.length > 1) {
        // Sort by quality score (best first)
        duplicateGroup.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
        duplicateGroups.add(duplicateGroup);
      }
    }

    // Sort groups by similarity strength
    duplicateGroups.sort((a, b) {
      final avgSimilarityA = a.skip(1).map((c) => c.similarityScore).fold(0.0, (a, b) => a + b) / (a.length - 1);
      final avgSimilarityB = b.skip(1).map((c) => c.similarityScore).fold(0.0, (a, b) => a + b) / (b.length - 1);
      return avgSimilarityB.compareTo(avgSimilarityA);
    });

    print('Found ${duplicateGroups.length} duplicate groups');
    return duplicateGroups;
  }

  /// Advanced duplicate detection with multiple strategies
  Future<List<List<DuplicateContact>>> findDuplicatesAdvanced() async {
    final contacts = await getAllContacts();
    final allGroups = <List<DuplicateContact>>[];

    // Strategy 1: Exact name matches
    final exactNameGroups = await _findExactNameDuplicates(contacts);
    allGroups.addAll(exactNameGroups);

    // Strategy 2: Phone number matches
    final phoneGroups = await _findPhoneDuplicates(contacts);
    allGroups.addAll(phoneGroups);

    // Strategy 3: Email matches
    final emailGroups = await _findEmailDuplicates(contacts);
    allGroups.addAll(emailGroups);

    // Strategy 4: Fuzzy name matches
    final fuzzyGroups = await _findFuzzyNameDuplicates(contacts);
    allGroups.addAll(fuzzyGroups);

    // Merge overlapping groups
    final mergedGroups = _mergeOverlappingGroups(allGroups);

    return mergedGroups;
  }

  /// Remove selected duplicate contacts
  Future<void> removeContacts(List<DuplicateContact> contacts) async {
    final permission = await _requestContactsPermission();
    if (!permission) {
      throw Exception('Contacts permission denied');
    }

    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (final duplicateContact in contacts) {
      try {
        // Find the actual contact in the device
        final deviceContacts = await ContactsService.getContacts();
        final deviceContact = deviceContacts.firstWhere(
          (c) => c.identifier == duplicateContact.id,
          orElse: () => throw Exception('Contact not found'),
        );

        await ContactsService.deleteContact(deviceContact);
        successCount++;
      } catch (e) {
        failCount++;
        errors.add('Failed to delete ${duplicateContact.displayName}: $e');
        print('Error deleting contact ${duplicateContact.id}: $e');
      }
    }

    if (failCount > 0) {
      final errorMessage = 'Removed $successCount contacts successfully, $failCount failed.\n${errors.take(5).join('\n')}';
      throw Exception(errorMessage);
    }
  }

  /// Merge duplicate contacts into one
  Future<Contact> mergeContacts(List<DuplicateContact> duplicates) async {
    if (duplicates.isEmpty) throw Exception('No contacts to merge');

    // Start with the highest quality contact as base
    final baseContact = duplicates.first;
    final merged = Contact(
      givenName: baseContact.givenName,
      familyName: baseContact.familyName,
      displayName: baseContact.displayName,
    );

    // Merge phone numbers
    final allPhones = <Item>[];
    final seenPhones = <String>{};
    
    for (final contact in duplicates) {
      if (contact.phoneNumbers != null) {
        for (final phone in contact.phoneNumbers!) {
          final cleanPhone = phone.value?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
          if (cleanPhone.isNotEmpty && !seenPhones.contains(cleanPhone)) {
            allPhones.add(Item(label: phone.label ?? 'mobile', value: phone.value));
            seenPhones.add(cleanPhone);
          }
        }
      }
    }
    merged.phones = allPhones;

    // Merge emails
    final allEmails = <Item>[];
    final seenEmails = <String>{};
    
    for (final contact in duplicates) {
      if (contact.emails != null) {
        for (final email in contact.emails!) {
          final cleanEmail = email.value?.toLowerCase() ?? '';
          if (cleanEmail.isNotEmpty && !seenEmails.contains(cleanEmail)) {
            allEmails.add(Item(label: email.label ?? 'home', value: email.value));
            seenEmails.add(cleanEmail);
          }
        }
      }
    }
    merged.emails = allEmails;

    // Merge other fields (take first non-empty value)
    merged.company = duplicates.firstWhere((c) => c.company?.isNotEmpty == true, orElse: () => baseContact).company;
    merged.jobTitle = duplicates.firstWhere((c) => c.jobTitle?.isNotEmpty == true, orElse: () => baseContact).jobTitle;
    
    // Merge notes
    final notes = duplicates
        .where((c) => c.note?.isNotEmpty == true)
        .map((c) => c.note!)
        .toSet()
        .join('\n\n');
    if (notes.isNotEmpty) {
      merged.note = notes;
    }

    return merged;
  }

  // Private helper methods

  Future<bool> _requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status == PermissionStatus.granted;
  }

  List<String> _getMatchingFields(DuplicateContact c1, DuplicateContact c2) {
    final matches = <String>[];
    
    // Check name similarity
    if (c1.displayName != null && c2.displayName != null) {
      final similarity = c1._stringSimilarity(c1.displayName!, c2.displayName!);
      if (similarity > 0.8) matches.add('name');
    }
    
    // Check phone matches
    if (c1.phoneNumbers?.isNotEmpty == true && c2.phoneNumbers?.isNotEmpty == true) {
      for (final phone1 in c1.phoneNumbers!) {
        for (final phone2 in c2.phoneNumbers!) {
          if (c1._phonesSimilar(phone1.value, phone2.value)) {
            matches.add('phone');
            break;
          }
        }
        if (matches.contains('phone')) break;
      }
    }
    
    // Check email matches
    if (c1.emails?.isNotEmpty == true && c2.emails?.isNotEmpty == true) {
      for (final email1 in c1.emails!) {
        for (final email2 in c2.emails!) {
          if (email1.value?.toLowerCase() == email2.value?.toLowerCase()) {
            matches.add('email');
            break;
          }
        }
        if (matches.contains('email')) break;
      }
    }
    
    return matches;
  }

  Future<List<List<DuplicateContact>>> _findExactNameDuplicates(List<DuplicateContact> contacts) async {
    final nameGroups = <String, List<DuplicateContact>>{};
    
    for (final contact in contacts) {
      final name = contact.displayName?.toLowerCase().trim();
      if (name?.isNotEmpty == true) {
        nameGroups.putIfAbsent(name!, () => []).add(contact);
      }
    }
    
    return nameGroups.values.where((group) => group.length > 1).toList();
  }

  Future<List<List<DuplicateContact>>> _findPhoneDuplicates(List<DuplicateContact> contacts) async {
    final phoneGroups = <String, List<DuplicateContact>>{};
    
    for (final contact in contacts) {
      if (contact.phoneNumbers?.isNotEmpty == true) {
        for (final phone in contact.phoneNumbers!) {
          final cleanPhone = phone.value?.replaceAll(RegExp(r'[^\d]'), '');
          if (cleanPhone?.isNotEmpty == true && cleanPhone!.length >= 7) {
            phoneGroups.putIfAbsent(cleanPhone, () => []).add(contact);
          }
        }
      }
    }
    
    return phoneGroups.values.where((group) => group.length > 1).toList();
  }

  Future<List<List<DuplicateContact>>> _findEmailDuplicates(List<DuplicateContact> contacts) async {
    final emailGroups = <String, List<DuplicateContact>>{};
    
    for (final contact in contacts) {
      if (contact.emails?.isNotEmpty == true) {
        for (final email in contact.emails!) {
          final cleanEmail = email.value?.toLowerCase().trim();
          if (cleanEmail?.isNotEmpty == true) {
            emailGroups.putIfAbsent(cleanEmail!, () => []).add(contact);
          }
        }
      }
    }
    
    return emailGroups.values.where((group) => group.length > 1).toList();
  }

  Future<List<List<DuplicateContact>>> _findFuzzyNameDuplicates(List<DuplicateContact> contacts) async {
    final groups = <List<DuplicateContact>>[];
    final processed = <String>{};
    
    for (int i = 0; i < contacts.length; i++) {
      if (processed.contains(contacts[i].id)) continue;
      
      final group = <DuplicateContact>[contacts[i]];
      processed.add(contacts[i].id);
      
      for (int j = i + 1; j < contacts.length; j++) {
        if (processed.contains(contacts[j].id)) continue;
        
        final similarity = contacts[i]._stringSimilarity(
          contacts[i].displayName ?? '',
          contacts[j].displayName ?? '',
        );
        
        if (similarity > 0.85) {
          group.add(contacts[j]);
          processed.add(contacts[j].id);
        }
      }
      
      if (group.length > 1) {
        groups.add(group);
      }
    }
    
    return groups;
  }

  List<List<DuplicateContact>> _mergeOverlappingGroups(List<List<DuplicateContact>> groups) {
    final merged = <List<DuplicateContact>>[];
    final processed = <String>{};
    
    for (final group in groups) {
      final contactIds = group.map((c) => c.id).toSet();
      
      // Check if any contact in this group is already processed
      if (contactIds.any((id) => processed.contains(id))) {
        // Find existing group to merge with
        final existingGroupIndex = merged.indexWhere((existingGroup) =>
            existingGroup.any((c) => contactIds.contains(c.id)));
        
        if (existingGroupIndex != -1) {
          // Merge with existing group
          for (final contact in group) {
            if (!merged[existingGroupIndex].any((c) => c.id == contact.id)) {
              merged[existingGroupIndex].add(contact);
            }
          }
        }
      } else {
        // Add as new group
        merged.add(group);
        processed.addAll(contactIds);
      }
    }
    
    return merged;
  }
}