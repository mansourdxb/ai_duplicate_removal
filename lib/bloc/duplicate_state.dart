import 'package:equatable/equatable.dart';
import '../models/duplicate_item.dart';
import '../models/duplicate_contact.dart';

abstract class DuplicateState extends Equatable {
  const DuplicateState();

  @override
  List<Object> get props => [];
}

class DuplicateInitial extends DuplicateState {}

class DuplicateScanning extends DuplicateState {
  final String progress;

  const DuplicateScanning({required this.progress});

  @override
  List<Object> get props => [progress];
}

class DuplicateDetected extends DuplicateState {
  final List<List<DuplicateItem>> duplicates;

  const DuplicateDetected({required this.duplicates});

  @override
  List<Object> get props => [duplicates];
}

class DuplicateNoneFound extends DuplicateState {}

class DuplicateRemoving extends DuplicateState {}

class DuplicateRemoved extends DuplicateState {
  final int removedCount;

  const DuplicateRemoved({required this.removedCount});

  @override
  List<Object> get props => [removedCount];
}

class DuplicateContactsDetected extends DuplicateState {
  final List<List<DuplicateContact>> duplicates;

  const DuplicateContactsDetected({required this.duplicates});

  @override
  List<Object> get props => [duplicates];
}

class DuplicateMixedDetected extends DuplicateState {
  final List<List<DuplicateItem>> fileDuplicates;
  final List<List<DuplicateContact>> contactDuplicates;

  const DuplicateMixedDetected({
    required this.fileDuplicates,
    required this.contactDuplicates,
  });

  @override
  List<Object> get props => [fileDuplicates, contactDuplicates];
}

class DuplicateError extends DuplicateState {
  final String message;

  const DuplicateError(this.message);

  @override
  List<Object> get props => [message];
}