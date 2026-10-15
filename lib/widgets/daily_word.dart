import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DailyWord extends StatefulWidget {
  const DailyWord({super.key, this.clientFactory});
  final http.Client Function()? clientFactory;
  @override
  State<DailyWord> createState() => _DailyWordState();
}

class _DailyWordState extends State<DailyWord> {
  // Shared across instances so scrolling the card off-screen (which disposes
  // it) or moving from login to home does not refetch the same day's word.
  static Map<String, dynamic>? _cachedWord;
  static String _cachedDay = '';

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
    if (_cachedWord != null && _cachedDay == _today) {
      _word = _cachedWord;
      _day = _cachedDay;
    } else {
      _load();
    }
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
      _cachedWord = data;
      _cachedDay = _today;
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

  // Matches the "Өнөөдрийн үг" panel on the 13.214.2.6 web page.
  static const _ink = Color(0xFF18376B);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF4FF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ӨНӨӨДРИЙН ҮГ',
          style: TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        if (_word == null && _error == null)
          const Text(
            'Өнөөдрийн үгийг ачаалж байна…',
            style: TextStyle(color: _ink, fontSize: 17, height: 1.55),
          ),
        if (_word != null) ...[
          Text(
            _word!['english'] as String,
            style: const TextStyle(color: _ink, fontSize: 17, height: 1.55),
          ),
          const SizedBox(height: 8),
          Text(
            _word!['mongolian'] as String,
            style: const TextStyle(color: _ink, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            '${_word!['date']}${_word!['automatic_translation'] == true ? ' · Автомат орчуулга' : ''}',
            style: const TextStyle(color: Color(0xFF577096), fontSize: 11),
          ),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: _ink)),
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('Дахин ачаалах'),
          ),
        ],
      ],
    ),
  );
}
