import 'dart:async';
import 'dart:convert';

import 'package:my_expense_tracker_app/data/services/on_device_ai_service.dart';

/// Stands in for the on-device model: a status the test sets, an answer per
/// prompt, a record of every prompt.
class FakeOnDeviceAi implements OnDeviceAiService {
  FakeOnDeviceAi({this.current = AiStatus.available, this.reply});

  AiStatus current;

  /// What a prompt gets; null → [plainAnswer] for the SMS in it.
  FutureOr<AiReply> Function(String sms)? reply;

  /// Every prompt's SMS text (between the prompt's `<<<` and `>>>`).
  final asked = <String>[];

  /// Every prompt as sent.
  final prompts = <String>[];

  int downloads = 0;

  /// What [download] answers (its future), so a test can hold it.
  Completer<bool>? downloadAnswer;

  /// Status calls, to check foss and "off" never ask.
  int statusCalls = 0;

  @override
  Future<AiStatus> status() async {
    statusCalls++;
    return current;
  }

  @override
  Future<bool> download() {
    downloads++;
    return downloadAnswer?.future ?? Future.value(true);
  }

  @override
  Future<AiReply> prompt(String text, {required Duration timeout}) async {
    prompts.add(text);
    final sms = smsIn(text);
    asked.add(sms);
    return await (reply ?? plainAnswer)(sms);
  }

  /// The SMS a prompt carries.
  static String smsIn(String prompt) {
    final start = prompt.lastIndexOf('<<<\n') + 4;
    return prompt.substring(start, prompt.lastIndexOf('\n>>>'));
  }

  /// A debit of the first `Rs.<n>` in [sms], titled "AI title", in
  /// "Groceries", by UPI.
  static AiReply plainAnswer(String sms) => AiAnswer(
    answerJson(amount: RegExp(r'Rs\.?\s*([0-9.,]+[0-9])').firstMatch(sms)![1]!),
  );

  static String answerJson({
    bool isDebit = true,
    Object? amount = '150.00',
    String title = 'AI title',
    String payee = 'AI payee',
    String payment = 'upi',
    String category = 'Groceries',
  }) =>
      '```json\n${jsonEncode({'is_debit': isDebit, 'amount': amount, 'payee': payee, 'title': title, 'payment': payment, 'category': category})}\n```';
}
