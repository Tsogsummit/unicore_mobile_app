import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:unicore_mobile_app/widgets/cards.dart';

class DailyWord extends StatefulWidget {
  const DailyWord({super.key, this.clientFactory});
  final http.Client Function()? clientFactory;
  @override
  State<DailyWord> createState() => _DailyWordState();
}

class _DailyWordState extends State<DailyWord> {
  Map<String, dynamic>? _word;
  String? _error;
  bool _loading = false;
  Timer? _timer;
  String _day = '';
  String get _today => DateTime.now()
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_day != _today && !_loading) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = widget.clientFactory?.call() ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('https://13.214.2.6/api/inspiration'))
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 ||
          data is! Map<String, dynamic> ||
          data['english'] is! String ||
          data['mongolian'] is! String) {
        throw const FormatException();
      }
      if (mounted) {
        setState(() {
          _word = data;
          _day = _today;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Өнөөдрийн үгийг ачаалж чадсангүй.');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Өнөөдрийн үг',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        if (_word != null) ...[
          Text(
            _word!['english'] as String,
            style: const TextStyle(fontSize: 18, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            _word!['mongolian'] as String,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            '${_word!['date']}${_word!['automatic_translation'] == true ? ' · Автомат орчуулга' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('Дахин ачаалах'),
          ),
        ],
      ],
    ),
  );
}
