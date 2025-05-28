import 'package:flutter/material.dart';
import '../models/duplicate_contact.dart';

class ContactMergePreviewScreen extends StatelessWidget {
  final List<DuplicateContact> contacts;

  const ContactMergePreviewScreen({Key? key, required this.contacts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bestContact = _selectBestContact();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Merge Preview'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Merged Contact Preview:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _buildFieldRow('Name', bestContact.displayName),
            _buildFieldRow('Phone', bestContact.phoneNumbers?.first.value),
            _buildFieldRow('Email', bestContact.emails?.first.value),
            _buildFieldRow('Company', bestContact.company),
            _buildFieldRow('Job Title', bestContact.jobTitle),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.merge_type),
                label: const Text('Confirm & Merge'),
                onPressed: () {
                  // TODO: Implement actual merging logic
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text('$label:')),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  DuplicateContact _selectBestContact() {
    contacts.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    return contacts.first;
  }
}
