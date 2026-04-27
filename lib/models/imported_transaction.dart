import 'package:hive/hive.dart';

class ImportedTransaction {
  ImportedTransaction({
    required this.id,
    required this.sourceFileName,
    required this.date,
    required this.description,
    required this.amount,
    required this.category,
    required this.type,
    required this.selectedForImport,
  });

  final String id;
  final String sourceFileName;
  final DateTime date;
  final String description;
  final double amount;
  final String category;
  final String type;
  final bool selectedForImport;

  ImportedTransaction copyWith({
    bool? selectedForImport,
    String? category,
    String? type,
  }) {
    return ImportedTransaction(
      id: id,
      sourceFileName: sourceFileName,
      date: date,
      description: description,
      amount: amount,
      category: category ?? this.category,
      type: type ?? this.type,
      selectedForImport: selectedForImport ?? this.selectedForImport,
    );
  }
}

class ImportedTransactionAdapter extends TypeAdapter<ImportedTransaction> {
  @override
  final int typeId = 3;

  @override
  ImportedTransaction read(BinaryReader reader) {
    return ImportedTransaction(
      id: reader.readString(),
      sourceFileName: reader.readString(),
      date: DateTime.parse(reader.readString()),
      description: reader.readString(),
      amount: reader.readDouble(),
      category: reader.readString(),
      type: reader.readString(),
      selectedForImport: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, ImportedTransaction obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.sourceFileName)
      ..writeString(obj.date.toIso8601String())
      ..writeString(obj.description)
      ..writeDouble(obj.amount)
      ..writeString(obj.category)
      ..writeString(obj.type)
      ..writeBool(obj.selectedForImport);
  }
}
