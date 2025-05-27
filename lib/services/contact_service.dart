import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/duplicate_contact.dart';
import '../models/duplicate_item.dart';
import 'dart:typed_data';
import 'dart:io';

/*class DuplicateContact {
  final String id;
  final String displayName;
  final List<String> phoneNumbers;
  final List<String> emails;
  final Uint8List? avatar;

  DuplicateContact({
    required this.id,
    required this.displayName,
    required this.phoneNumbers,
    required this.emails,
    this.avatar,
  });
}*/

class ContactService {
  static Future<bool> requestPermissions() async {
    final status = await Permission.contacts.request();
    return status == PermissionStatus.granted;
  }

  static Future<List<DuplicateContact>> getContacts({bool withThumbnails = false}) async {
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contact permission denied');
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: withThumbnails,
      );

      return contacts.map((contact) {
        final phones = contact.phones.map((phone) => phone.number).toList();
        final emails = contact.emails.map((email) => email.address).toList();
        
        return DuplicateContact(
          id: contact.id,
          displayName: contact.displayName,
         phoneNumbers: phones.map((phone) => ContactPhone(value: phone)).toList(),
emails: emails.map((email) => ContactEmail(value: email)).toList(),

          avatar: contact.thumbnail,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get contacts: $e');
    }
  }

Future<List<List<DuplicateContact>>> findDuplicatesAdvanced() async {
  final contacts = await getContacts(); // or getAllContacts() depending on your naming
  final allGroups = <List<DuplicateContact>>[];

  // Group by identical displayName
  final nameGroups = <String, List<DuplicateContact>>{};
  for (final contact in contacts) {
    final name = contact.displayName?.trim().toLowerCase() ?? '';
    if (name.isNotEmpty) {
      nameGroups.putIfAbsent(name, () => []).add(contact);
    }
  }

  for (var group in nameGroups.values) {
    if (group.length > 1) {
      allGroups.add(group);
    }
  }

  return allGroups;
}

Future<List<DuplicateContact>> getAllContacts() async {
  return await ContactService.getContacts(); // or just return getContacts() if it's non-static
}

  static Future<List<DuplicateContact>> getContactsFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final lines = content.split('\n');
      final contacts = <DuplicateContact>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length >= 3) {
          contacts.add(DuplicateContact(
             id: 'file_$i',
  displayName: parts[0].replaceAll('"', ''),
  phoneNumbers: [
    ContactPhone(value: parts[1].replaceAll('"', ''))
  ],
  emails: parts.length > 2
      ? [ContactEmail(value: parts[2].replaceAll('"', ''))]
      : [],
));
        }
      }

      return contacts;
    } catch (e) {
      throw Exception('Failed to read contacts from file: $e');
    }
  }

  static Future<void> removeContacts(List<DuplicateContact> contactsToRemove) async {
    if (!await FlutterContacts.requestPermission(readonly: false)) {
      throw Exception('Contact permission denied');
    }

    try {
      for (final contactToRemove in contactsToRemove) {
        if (!contactToRemove.id.startsWith('file_')) {
          final contact = await FlutterContacts.getContact(contactToRemove.id);
          if (contact != null) {
            await FlutterContacts.deleteContact(contact);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to remove contacts: $e');
    }
  }

  static Future<Contact> mergeContacts(List<DuplicateContact> duplicates) async {
    if (duplicates.isEmpty) {
      throw ArgumentError('Cannot merge empty list of contacts');
    }

    final primaryContact = duplicates.first;
    final allPhones = <Phone>[];
    final allEmails = <Email>[];

    // Collect all unique phone numbers and emails
    final uniquePhones = <String>{};
    final uniqueEmails = <String>{};

    for (final duplicate in duplicates) {
  for (final phone in duplicate.phoneNumbers ?? []) {
    if ((phone.number?.isNotEmpty ?? false) && uniquePhones.add(phone.number!)) {
      allPhones.add(Phone(phone.number!));
    }
  }
  for (final email in duplicate.emails ?? []) {
    if ((email.address?.isNotEmpty ?? false) && uniqueEmails.add(email.address!)) {
      allEmails.add(Email(email.address!));
    }
  }
}


    return Contact(
      id: primaryContact.id,
      displayName: primaryContact.displayName!,
      phones: allPhones,
      emails: allEmails,
    );
  }

  Future<List<DuplicateContact>> findDuplicateContacts({
  required Function(String) onProgress,
}) async {
  onProgress('Getting contacts...');
  final contacts = await getContacts();

  onProgress('Comparing contacts...');
  final groups = await findDuplicates(contacts);

  onProgress('Flattening results...');
  final duplicates = <DuplicateContact>[];
  for (final group in groups) {
    duplicates.addAll(group);
  }

  onProgress('Found ${duplicates.length} duplicate contacts.');
  return duplicates;
}

Future<List<List<DuplicateContact>>> findDuplicates(List<DuplicateContact> contacts) async {
  final seen = <String, List<DuplicateContact>>{};

  for (var contact in contacts) {
    final phoneJoined = (contact.phoneNumbers ?? []).map((p) => p.value ?? '').join();
    final emailJoined = (contact.emails ?? []).map((e) => e.value ?? '').join();

    final key = '${contact.displayName}-$phoneJoined-$emailJoined';
    seen.putIfAbsent(key, () => []).add(contact);
  }

  return seen.values.where((group) => group.length > 1).toList();
}
}