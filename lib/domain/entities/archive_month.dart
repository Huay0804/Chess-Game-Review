import 'package:equatable/equatable.dart';

class ArchiveMonth extends Equatable {
  const ArchiveMonth(this.year, this.month);
  final int year;
  final int month;
  String get path => '$year/${month.toString().padLeft(2, '0')}';
  String get label => '${month.toString().padLeft(2, '0')}/$year';
  DateTime get startUtc => DateTime.utc(year, month);
  bool get isValid => year >= 2000 && year <= 9999 && month >= 1 && month <= 12;
  @override
  List<Object?> get props => [year, month];
}
