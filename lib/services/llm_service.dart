import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/receipt.dart';

class ParsedReceipt {
  ParsedReceipt({
    required this.merchantName,
    required this.date,
    required this.totalAmount,
    required this.category,
    required this.paymentMethod,
    required this.items,
  });

  final String merchantName;
  final DateTime date;
  final double totalAmount;
  final String category;
  final String paymentMethod;
  final List<ReceiptItem> items;
}

class LlmService {
  LlmService({String? apiKey, String? model})
    : apiKey =
          apiKey ??
          dotenv.env['OPENROUTER_API_KEY'] ??
          const String.fromEnvironment('OPENROUTER_API_KEY'),
      model =
          model ??
          dotenv.env['OPENROUTER_MODEL'] ??
          '~google/gemini-flash-latest';

  final String apiKey;
  final String model;

  Future<ParsedReceipt> parseReceipt(String ocrText) async {
    if (apiKey.isEmpty) {
      debugPrint('[LLM] No API key configured. Using local heuristic parse.');
      return _localHeuristicParse(ocrText);
    }
    try {
      debugPrint(
        '[LLM] Sending OCR text to OpenRouter. model=$model textLength=${ocrText.length}',
      );
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://coursework.local/smart-receipt-ai',
          'X-Title': 'Smart Receipt AI',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Extract receipt fields. Return JSON only with keys merchantName, date, totalAmount, category, paymentMethod, items. items is an array of {name, quantity, unitPrice, totalPrice}. Use MYR context for Malaysian receipts.',
            },
            {'role': 'user', 'content': ocrText},
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        }),
      );
      debugPrint('[LLM] OpenRouter response status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[LLM] Non-success status. Falling back to local heuristic parse. body=${response.body}',
        );
        return _localHeuristicParse(ocrText);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          body['choices']?[0]?['message']?['content']?.toString() ?? '{}';
      debugPrint(
        '[LLM] OpenRouter parse success. contentLength=${content.length}',
      );
      return _fromJson(
        jsonDecode(_jsonOnly(content)) as Map<String, dynamic>,
        ocrText,
      );
    } catch (error) {
      debugPrint(
        '[LLM] Parse error. Falling back to local heuristic. error=$error',
      );
      return _localHeuristicParse(ocrText);
    }
  }

  String _jsonOnly(String input) {
    final start = input.indexOf('{');
    final end = input.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) return '{}';
    return input.substring(start, end + 1);
  }

  ParsedReceipt _fromJson(Map<String, dynamic> json, String ocrText) {
    final itemsRaw = (json['items'] as List?) ?? [];
    return ParsedReceipt(
      merchantName: (json['merchantName'] ?? 'Unknown Merchant').toString(),
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      totalAmount:
          double.tryParse((json['totalAmount'] ?? '0').toString()) ??
          _amountFromText(ocrText),
      category: (json['category'] ?? 'Food').toString(),
      paymentMethod: (json['paymentMethod'] ?? 'TNG eWallet').toString(),
      items: itemsRaw.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return ReceiptItem(
          name: (map['name'] ?? 'Item').toString(),
          quantity: double.tryParse((map['quantity'] ?? '1').toString()) ?? 1,
          unitPrice: double.tryParse((map['unitPrice'] ?? '0').toString()) ?? 0,
          totalPrice:
              double.tryParse((map['totalPrice'] ?? '0').toString()) ?? 0,
        );
      }).toList(),
    );
  }

  ParsedReceipt _localHeuristicParse(String text) {
    debugPrint('[LLM] Using local heuristic parse.');
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final merchant = lines.isEmpty
        ? 'TNG eWallet Merchant'
        : lines.first.replaceAll(RegExp(r'Merchant:\s*'), '');
    final total = _amountFromText(text);
    final lower = text.toLowerCase();
    final category = lower.contains('grab') || lower.contains('toll')
        ? 'Transport'
        : lower.contains('airasia') || lower.contains('hotel')
        ? 'Travel'
        : lower.contains('maxis') || lower.contains('celcom')
        ? 'Utilities'
        : 'Food';
    final payment = lower.contains('visa')
        ? 'Visa'
        : lower.contains('master')
        ? 'Mastercard'
        : lower.contains('bank')
        ? 'Bank Transfer'
        : 'TNG eWallet';
    return ParsedReceipt(
      merchantName: merchant,
      date: DateTime.now(),
      totalAmount: total == 0 ? 24.90 : total,
      category: category,
      paymentMethod: payment,
      items: const [],
    );
  }

  double _amountFromText(String text) {
    final match = RegExp(
      r'(?:RM|MYR)?\s*([0-9]+(?:\.[0-9]{2})?)',
      caseSensitive: false,
    ).allMatches(text).lastOrNull;
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
