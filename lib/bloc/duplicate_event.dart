import 'package:equatable/equatable.dart';
import '../models/duplicate_item.dart';

abstract class DuplicateEvent extends Equatable {
  const DuplicateEvent();

  @override
  List<Object> get props => [];
}

class StartScan extends DuplicateEvent {
  final ScanType scanType;

  const StartScan(this.scanType);

  @override
  List<Object> get props => [scanType];
}

class RemoveDuplicates extends DuplicateEvent {
  final List<DuplicateItem> itemsToRemove;

  const RemoveDuplicates(this.itemsToRemove);

  @override
  List<Object> get props => [itemsToRemove];
}

enum ScanType { images, files, contacts, all }