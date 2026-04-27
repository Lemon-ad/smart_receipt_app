import 'package:hive/hive.dart';

class ReceiptItem {
  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
}

class Receipt {
  Receipt({
    required this.id,
    required this.merchantName,
    required this.date,
    required this.totalAmount,
    required this.currency,
    required this.category,
    required this.type,
    required this.paymentMethod,
    required this.tags,
    required this.imagePath,
    required this.rawOcrText,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;
  final String merchantName;
  final DateTime date;
  final double totalAmount;
  final String currency;
  final String category;
  final String type;
  final String paymentMethod;
  final List<String> tags;
  final String? imagePath;
  final String rawOcrText;
  final String sourceType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ReceiptItem> items;

  Receipt copyWith({
    String? id,
    String? merchantName,
    DateTime? date,
    double? totalAmount,
    String? currency,
    String? category,
    String? type,
    String? paymentMethod,
    List<String>? tags,
    String? imagePath,
    String? rawOcrText,
    String? sourceType,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ReceiptItem>? items,
  }) {
    return Receipt(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tags: tags ?? this.tags,
      imagePath: imagePath ?? this.imagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

class ReceiptItemAdapter extends TypeAdapter<ReceiptItem> {
  @override
  final int typeId = 1;

  @override
  ReceiptItem read(BinaryReader reader) {
    return ReceiptItem(
      name: reader.readString(),
      quantity: reader.readDouble(),
      unitPrice: reader.readDouble(),
      totalPrice: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ReceiptItem obj) {
    writer
      ..writeString(obj.name)
      ..writeDouble(obj.quantity)
      ..writeDouble(obj.unitPrice)
      ..writeDouble(obj.totalPrice);
  }
}

class ReceiptAdapter extends TypeAdapter<Receipt> {
  @override
  final int typeId = 2;

  @override
  Receipt read(BinaryReader reader) {
    return Receipt(
      id: reader.readString(),
      merchantName: reader.readString(),
      date: DateTime.parse(reader.readString()),
      totalAmount: reader.readDouble(),
      currency: reader.readString(),
      category: reader.readString(),
      type: reader.readString(),
      paymentMethod: reader.readString(),
      tags: (reader.readList()).cast<String>(),
      imagePath: reader.read() as String?,
      rawOcrText: reader.readString(),
      sourceType: reader.readString(),
      createdAt: DateTime.parse(reader.readString()),
      updatedAt: DateTime.parse(reader.readString()),
      items: (reader.readList()).cast<ReceiptItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, Receipt obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.merchantName)
      ..writeString(obj.date.toIso8601String())
      ..writeDouble(obj.totalAmount)
      ..writeString(obj.currency)
      ..writeString(obj.category)
      ..writeString(obj.type)
      ..writeString(obj.paymentMethod)
      ..writeList(obj.tags)
      ..write(obj.imagePath)
      ..writeString(obj.rawOcrText)
      ..writeString(obj.sourceType)
      ..writeString(obj.createdAt.toIso8601String())
      ..writeString(obj.updatedAt.toIso8601String())
      ..writeList(obj.items);
  }
}
