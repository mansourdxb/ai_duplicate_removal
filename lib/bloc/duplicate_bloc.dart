import 'package:flutter_bloc/flutter_bloc.dart';
import 'duplicate_event.dart';
import 'duplicate_state.dart';
import '../services/file_service.dart';
import '../services/duplicate_detector.dart';
import '../services/contact_service.dart';
import '../models/duplicate_item.dart';
import '../models/duplicate_contact.dart';

class DuplicateBloc extends Bloc<DuplicateEvent, DuplicateState> {
  final FileService fileService;
  final DuplicateDetector duplicateDetector;
  final ContactService contactService;

  DuplicateBloc({
    required this.fileService,
    required this.duplicateDetector,
    required this.contactService,
  }) : super(DuplicateInitial()) {
    on<StartScan>(_onStartScan);
    on<RemoveDuplicates>(_onRemoveDuplicates);
  }

  Future<void> _onStartScan(StartScan event, Emitter<DuplicateState> emit) async {
    try {
      emit(DuplicateScanning(progress: 'Initializing scan...'));
      
      // Get files based on scan type
      List<String> filePaths = [];
      
      switch (event.scanType) {
        case ScanType.images:
          emit(DuplicateScanning(progress: 'Scanning images...'));
          filePaths = await fileService.getImageFiles();
          break;
        case ScanType.files:
          emit(DuplicateScanning(progress: 'Scanning files...'));
          filePaths = await fileService.getDocumentFiles();
          break;
        case ScanType.contacts:
          emit(DuplicateScanning(progress: 'Scanning contacts...'));
          final contactDuplicates = await contactService.findDuplicateContacts(
            onProgress: (progress) {
              emit(DuplicateScanning(progress: progress));
            },
          );
          
          if (contactDuplicates.isEmpty) {
            emit(DuplicateNoneFound());
          } else {
            emit(DuplicateContactsDetected(duplicates: contactDuplicates));
          }
          return;
        case ScanType.all:
          emit(DuplicateScanning(progress: 'Scanning all files and contacts...'));
          filePaths = await fileService.getAllFiles();
          
          // Also scan contacts
          final contactDuplicates = await contactService.findDuplicateContacts(
            onProgress: (progress) {
              emit(DuplicateScanning(progress: 'Contacts: $progress'));
            },
          );
          
          // Process file duplicates
          if (filePaths.isNotEmpty) {
            emit(DuplicateScanning(progress: 'Analyzing ${filePaths.length} files...'));
            final duplicates = await duplicateDetector.findDuplicates(
              filePaths,
              onProgress: (progress) {
                emit(DuplicateScanning(progress: 'Files: $progress'));
              },
            );
            
            if (duplicates.isNotEmpty || contactDuplicates.isNotEmpty) {
              emit(DuplicateMixedDetected(
                fileDuplicates: duplicates,
                contactDuplicates: contactDuplicates,
              ));
            } else {
              emit(DuplicateNoneFound());
            }
          } else if (contactDuplicates.isNotEmpty) {
            emit(DuplicateContactsDetected(duplicates: contactDuplicates));
          } else {
            emit(DuplicateNoneFound());
          }
          return;
      }

      if (filePaths.isEmpty) {
        emit(DuplicateError('No files found to scan'));
        return;
      }

      emit(DuplicateScanning(progress: 'Analyzing ${filePaths.length} files...'));

      // Detect duplicates
      final duplicates = await duplicateDetector.findDuplicates(
        filePaths,
        onProgress: (progress) {
          emit(DuplicateScanning(progress: 'Processing: $progress'));
        },
      );

      if (duplicates.isEmpty) {
        emit(DuplicateNoneFound());
      } else {
        emit(DuplicateDetected(duplicates: duplicates));
      }
    } catch (e) {
      emit(DuplicateError('Error during scan: $e'));
    }
  }

  Future<void> _onRemoveDuplicates(
      RemoveDuplicates event, Emitter<DuplicateState> emit) async {
    try {
      emit(DuplicateRemoving());
      
      int removedCount = 0;
      for (final item in event.itemsToRemove) {
        final success = await fileService.deleteFile(item.path);
        if (success) {
          removedCount++;
        }
      }

      emit(DuplicateRemoved(removedCount: removedCount));
      
      // Return to initial state after a delay
      await Future.delayed(Duration(seconds: 2));
      emit(DuplicateInitial());
    } catch (e) {
      emit(DuplicateError('Error removing duplicates: $e'));
    }
  }
}