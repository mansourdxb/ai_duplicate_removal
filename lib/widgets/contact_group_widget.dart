import 'package:flutter/material.dart';
import '../models/duplicate_contact.dart';

class ContactGroupWidget extends StatelessWidget {
  final List<DuplicateContact> group;
  final Set<DuplicateContact> selectedContacts;
  final Function(DuplicateContact) onContactToggled;
  final int groupIndex;

  const ContactGroupWidget({
    Key? key,
    required this.group,
    required this.selectedContacts,
    required this.onContactToggled,
    required this.groupIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Group $groupIndex',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${group.length} contacts',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.people,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Contact List
            ...group.asMap().entries.map((entry) {
              final index = entry.key;
              final contact = entry.value;
              final isSelected = selectedContacts.contains(contact);
              final isOriginal = index == 0; // First contact is considered original
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected 
                        ? Colors.red.shade300 
                        : isOriginal 
                            ? Colors.green.shade300 
                            : Colors.grey.shade300,
                    width: isSelected || isOriginal ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected 
                      ? Colors.red.shade50 
                      : isOriginal 
                          ? Colors.green.shade50 
                          : Colors.grey.shade50,
                ),
                child: ListTile(
                  onTap: () => onContactToggled(contact),
                  leading: CircleAvatar(
                    backgroundColor: isSelected 
                        ? Colors.red.shade200 
                        : isOriginal 
                            ? Colors.green.shade200 
                            : Colors.grey.shade300,
                    child: Text(
                      contact.displayName?.isNotEmpty == true
                          ? contact.displayName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: isSelected 
                            ? Colors.red.shade800 
                            : isOriginal 
                                ? Colors.green.shade800 
                                : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.displayName ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            decoration: isSelected ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isOriginal)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'KEEP',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isSelected)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'DELETE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (contact.phoneNumbers?.isNotEmpty == true)
                        Text(
                          contact.phoneNumbers!.first.value ?? '',
                          style: TextStyle(fontSize: 12),
                        ),
                      if (contact.emails?.isNotEmpty == true)
                        Text(
                          contact.emails!.first.value ?? '',
                          style: TextStyle(fontSize: 12),
                        ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          _buildInfoChip('Quality: ${contact.qualityScore.toStringAsFixed(1)}', Colors.blue),
                          SizedBox(width: 8),
                          _buildInfoChip('Match: ${(contact.similarityScore * 100).toStringAsFixed(0)}%', Colors.orange),
                        ],
                      ),
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.red)
                      : isOriginal
                          ? Icon(Icons.star, color: Colors.green)
                          : Icon(Icons.radio_button_unchecked, color: Colors.grey),
                ),
              );
            }).toList(),
            
            // Match Details
            if (group.length > 1)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match Details:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _getMatchReasons(group).map((reason) =>
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color.withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<String> _getMatchReasons(List<DuplicateContact> contacts) {
    List<String> reasons = [];
    
    if (contacts.length < 2) return reasons;
    
    // Check for name similarities
    final firstContact = contacts.first;
    bool hasNameMatch = false;
    bool hasPhoneMatch = false;
    bool hasEmailMatch = false;
    
    for (int i = 1; i < contacts.length; i++) {
      final contact = contacts[i];
      
      // Name matching
      if (firstContact.displayName?.toLowerCase() == contact.displayName?.toLowerCase()) {
        hasNameMatch = true;
      }
      
      // Phone matching
      if (firstContact.phoneNumbers?.isNotEmpty == true && 
          contact.phoneNumbers?.isNotEmpty == true) {
        final firstPhone = firstContact.phoneNumbers!.first.value?.replaceAll(RegExp(r'[^\d]'), '');
        final contactPhone = contact.phoneNumbers!.first.value?.replaceAll(RegExp(r'[^\d]'), '');
        if (firstPhone == contactPhone && firstPhone?.isNotEmpty == true) {
          hasPhoneMatch = true;
        }
      }
      
      // Email matching
      if (firstContact.emails?.isNotEmpty == true && 
          contact.emails?.isNotEmpty == true) {
        if (firstContact.emails!.first.value?.toLowerCase() == 
            contact.emails!.first.value?.toLowerCase()) {
          hasEmailMatch = true;
        }
      }
    }
    
    if (hasNameMatch) reasons.add('Same Name');
    if (hasPhoneMatch) reasons.add('Same Phone');
    if (hasEmailMatch) reasons.add('Same Email');
    
    if (reasons.isEmpty) {
      reasons.add('Similar Data');
    }
    
    return reasons;
  }
}