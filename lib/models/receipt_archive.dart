import 'package:hive/hive.dart';

class ReceiptArchive {
  ReceiptArchive({
    required this.receiptId,
    required this.sha256Hash,
    required this.archivedAt,
    required this.archivedImagePath,
    required this.isLocked,
    required this.linkedStatementRefs,
    this.lastVerifiedAt,
  });

  final String receiptId;
  final String sha256Hash;
  final DateTime archivedAt;
  final String? archivedImagePath;
  final bool isLocked;
  final DateTime? lastVerifiedAt;
  final List<String> linkedStatementRefs;

  ReceiptArchive copyWith({
    String? sha256Hash,
    DateTime? archivedAt,
    String? archivedImagePath,
    bool? isLocked,
    DateTime? lastVerifiedAt,
    List<String>? linkedStatementRefs,
  }) {
    return ReceiptArchive(
      receiptId: receiptId,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedImagePath: archivedImagePath ?? this.archivedImagePath,
      isLocked: isLocked ?? this.isLocked,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      linkedStatementRefs: linkedStatementRefs ?? this.linkedStatementRefs,
    );
  }
}

class ReceiptArchiveAdapter extends TypeAdapter<ReceiptArchive> {
  @override
  final int typeId = 5;

  @override
  ReceiptArchive read(BinaryReader reader) {
    return ReceiptArchive(
      receiptId: reader.readString(),
      sha256Hash: reader.readString(),
      archivedAt: DateTime.parse(reader.readString()),
      archivedImagePath: reader.read() as String?,
      isLocked: reader.readBool(),
      lastVerifiedAt: reader.read() as DateTime?,
      linkedStatementRefs: (reader.readList()).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReceiptArchive obj) {
    writer
      ..writeString(obj.receiptId)
      ..writeString(obj.sha256Hash)
      ..writeString(obj.archivedAt.toIso8601String())
      ..write(obj.archivedImagePath)
      ..writeBool(obj.isLocked)
      ..write(obj.lastVerifiedAt)
      ..writeList(obj.linkedStatementRefs);
  }
}
