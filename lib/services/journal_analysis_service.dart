import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Result of analysing one journal entry.
class JournalAnalysis {
  final String sentiment; // positive | neutral | negative
  final double score; // 0.0 – 1.0
  final List<String> emotions;
  final List<String> stressIndicators;
  final String wellnessTip;
  final String riskLevel; // low | moderate | high

  /// 'AI' when Claude produced it, 'On-device' for the offline fallback.
  final String source;

  const JournalAnalysis({
    required this.sentiment,
    required this.score,
    required this.emotions,
    required this.stressIndicators,
    required this.wellnessTip,
    required this.riskLevel,
    required this.source,
  });

  Map<String, dynamic> toFirestore() => {
        'sentiment': sentiment,
        'score': score,
        'emotions': emotions,
        'stressIndicators': stressIndicators,
        'wellnessTip': wellnessTip,
        'riskLevel': riskLevel,
        'analysisSource': source,
      };

  /// Defensive parsing: never throws on missing / odd fields.
  factory JournalAnalysis.fromJson(Map<String, dynamic> j, String source) {
    List<String> strings(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];

    String oneOf(dynamic v, List<String> allowed, String fallback) {
      final s = v?.toString().toLowerCase().trim() ?? '';
      return allowed.contains(s) ? s : fallback;
    }

    final rawScore = j['score'];
    double score = rawScore is num
        ? rawScore.toDouble()
        : double.tryParse(rawScore?.toString() ?? '') ?? 0.5;
    score = score.clamp(0.0, 1.0);

    return JournalAnalysis(
      sentiment: oneOf(j['sentiment'], ['positive', 'neutral', 'negative'], 'neutral'),
      score: score,
      emotions: strings(j['emotions']),
      stressIndicators: strings(j['stressIndicators']),
      wellnessTip: (j['wellnessTip']?.toString().trim().isNotEmpty ?? false)
          ? j['wellnessTip'].toString()
          : 'Take a few slow breaths and be kind to yourself today.',
      riskLevel: oneOf(j['riskLevel'], ['low', 'moderate', 'high'], 'low'),
      source: source,
    );
  }
}

/// Thrown when the entry is not meaningful text (gibberish, too short...).
class InvalidEntryException implements Exception {
  final String message;
  const InvalidEntryException(this.message);
  @override
  String toString() => message;
}

class JournalAnalysisService {
  static const _model = 'claude-haiku-4-5-20251001';

  static const _stopwords = {
    'i', 'a', 'an', 'the', 'and', 'or', 'but', 'so', 'to', 'of', 'in', 'on',
    'at', 'for', 'with', 'my', 'me', 'we', 'you', 'it', 'is', 'am', 'are',
    'was', 'were', 'be', 'been', 'have', 'has', 'had', 'do', 'did', 'not',
    'no', 'this', 'that', 'today', 'feel', 'felt', 'feeling', 'very', 'just',
    'really', 'about', 'because', 'when', 'how', 'what', 'day', 'can', 'could',
    'would', 'will', 'cant', "can't", "don't", "i'm", "i've", 'im', 'dont',
    'from', 'up', 'out', 'all', 'too', 'much', 'more', 'some', 'like', 'get',
    'got', 'go', 'going', 'work', 'school', 'class', 'home', 'friend', 'friends',
  };

  // Common English letter pairs. Keyboard mash ("hudyhd") has almost none.
  static const _commonBigrams = {
    'th', 'he', 'in', 'er', 'an', 're', 'nd', 'on', 'en', 'at', 'ou', 'ed', 'ha', 'to', 'or', 'it', 'is', 'hi', 'es', 'ng', 'st', 'ar', 'te', 'se', 'al', 'nt', 'ti', 'le', 've', 'co', 'me', 'de', 'ra', 'ro', 'ic', 'ne', 'ea', 'ce', 'li', 'll', 'be', 'ri', 'io', 'ur', 'as', 'et', 'ta', 'si', 'ch', 'ma', 'la', 'pe', 'el', 'om', 'di', 'ly', 'ol', 'ge', 'no', 'tr', 'ad', 'ac', 'ss', 'us', 'ec', 'pr', 'un', 'ho', 'wa', 'so', 'ca', 'sh', 'ow', 'wi', 'ut', 'ns', 'ie', 'id', 'ct', 'ey', 'ke', 'ni', 'ik', 'na', 'ul', 'ot', 'os', 'mi', 'ir', 'ev', 'ay', 'ep', 'rs', 'ob', 'ph', 'ab', 'ba', 'im', 'bo', 'mo', 'fi', 'gr', 'fo', 'pl', 'fe', 'oo', 'rt', 'ag', 'lo', 'ai', 'up', 'am', 'ua', 'ff', 'su', 'mp', 'nc', 'ci', 'ee', 'ld', 'ip', 'rm', 'ew', 'ry', 'sp', 'tu', 'av', 'fa', 'em', 'ue', 'do', 'ov', 'ex', 'ig', 'wh', 'ds', 'ts', 'ps', 'ks', 'ye', 'ty', 'ui', 'gi', 'vi', 'bl', 'cl', 'cr', 'dr', 'fr', 'gl', 'pa', 'po', 'pu', 'qu', 'sc', 'sk', 'sl', 'sm', 'sn', 'sw', 'tw', 'vo', 'wo', 'ze', 'ny', 'aw',
  };

  static double _bigramCoverage(String w) {
    final total = w.length - 1;
    if (total <= 0) return 1;
    var hit = 0;
    for (var i = 0; i < total; i++) {
      if (_commonBigrams.contains(w.substring(i, i + 2))) hit++;
    }
    return hit / total;
  }

  static bool _plausibleWord(String w, Set<String> known) {
    if (known.contains(w)) return true;
    if (w.length < 2) return false;
    if (!RegExp(r'[aeiou]').hasMatch(w)) return false; // no vowel
    if (RegExp(r'(.)\1\1').hasMatch(w)) return false; // aaa, zzz
    if (RegExp(r'[^aeiou\W\d_]{5,}').hasMatch(w)) return false; // 5+ consonants
    if (w.length > 20) return false;
    if (w.length >= 4 && _bigramCoverage(w) < 0.6) return false; // not English-like
    return true;
  }

  /// Returns a message if the entry is NOT real, analysable text, else null.
  static String? validate(String text) {
    final words = RegExp(r"[a-z']+")
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();
    const msg = 'I couldn\'t understand that entry, so no wellness result was '
        'given. Please write a few real sentences about how you feel.';
    if (words.length < 3) {
      return 'Please write at least a full sentence (3 or more words) so I can '
          'analyse how you are feeling.';
    }
    final known = {
      ..._stopwords, ..._positive, ..._negative,
      ..._emotionMap.keys, ..._stressMap.keys,
    };
    final plausible = words.where((w) => _plausibleWord(w, known)).length;
    final knownHits = words.where(known.contains).length;
    if (words.toSet().length / words.length < 0.5) return msg; // the the the...
    if (plausible / words.length < 0.8) return msg;
    // Real sentences are full of common words (I, the, and, feel...).
    if (knownHits == 0 || knownHits / words.length < 0.3) return msg;
    return null;
  }

  static String _prompt(String text) =>
      'You are a mental wellness NLP analyzer for CUTMind, a student wellness app at '
      'the Central University of Technology, South Africa.\n\n'
      'If the entry is gibberish, random characters or not meaningful text, respond ONLY with {"valid": false}. '
      'Never guess a risk level for text you cannot understand.\n'
      'Otherwise analyze this student journal entry and respond ONLY with a JSON object '
      '(no markdown, no explanation):\n'
      '{\n'
      '  "sentiment": "positive" | "neutral" | "negative",\n'
      '  "score": 0.0 to 1.0 (1.0 = very positive),\n'
      '  "emotions": ["emotion1", "emotion2"],\n'
      '  "stressIndicators": ["indicator1"],\n'
      '  "wellnessTip": "A short empathetic tip.",\n'
      '  "riskLevel": "low" | "moderate" | "high"\n'
      '}\n\n'
      'Journal entry:\n"""\n$text\n"""';

  /// Analyse an entry. Always returns a result: tries the AI first and falls
  /// back to the on-device analyser if the network / key / proxy fails.
  static Future<JournalAnalysis> analyze(String text) async {
    final problem = validate(text);
    if (problem != null) throw InvalidEntryException(problem);
    try {
      final ai = await _analyzeWithAI(text).timeout(const Duration(seconds: 25));
      if (ai != null) return ai;
    } on InvalidEntryException {
      rethrow;
    } catch (e) {
      debugPrint('AI analysis failed, using on-device fallback: $e');
    }
    return _analyzeLocally(text);
  }

  // ── AI (via proxy, or direct on mobile/desktop) ────────────────────────
  static Future<JournalAnalysis?> _analyzeWithAI(String text) async {
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 600,
      'messages': [
        {'role': 'user', 'content': _prompt(text)}
      ],
    });

    http.Response res;
    if (ApiConfig.proxyUrl.isNotEmpty) {
      res = await http.post(
        Uri.parse(ApiConfig.proxyUrl),
        headers: {'content-type': 'application/json'},
        body: body,
      );
    } else if (!kIsWeb &&
        ApiConfig.anthropicApiKey.isNotEmpty &&
        ApiConfig.anthropicApiKey != 'YOUR_API_KEY_HERE') {
      res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': ApiConfig.anthropicApiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: body,
      );
    } else {
      return null; // nothing configured -> fallback
    }

    if (res.statusCode != 200) {
      throw Exception('AI returned ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (data['content'] as List).first['text'] as String;

    // Pull the JSON object out even if the model added fences or extra text.
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end <= start) throw const FormatException('No JSON in reply');
    final parsed = jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;
    if (parsed['valid'] == false) {
      throw const InvalidEntryException(
          'I couldn\'t understand that entry, so no wellness result was given. '
          'Please write a few real sentences about how you feel.');
    }
    return JournalAnalysis.fromJson(parsed, 'AI');
  }

  // ── On-device fallback (keyword based) ─────────────────────────────────
  static const _positive = {
    'happy', 'glad', 'grateful', 'thankful', 'excited', 'proud', 'calm',
    'relaxed', 'good', 'great', 'amazing', 'love', 'hopeful', 'confident',
    'motivated', 'peaceful', 'joy', 'better', 'fun', 'enjoyed', 'blessed',
  };
  static const _negative = {
    'sad', 'anxious', 'anxiety', 'worried', 'stress', 'stressed', 'tired',
    'exhausted', 'angry', 'upset', 'lonely', 'overwhelmed', 'depressed',
    'afraid', 'scared', 'nervous', 'hopeless', 'worthless', 'panic', 'cry',
    'crying', 'failing', 'fail', 'pressure', 'burnout', 'bad', 'terrible',
    'awful', 'hate', 'stuck', 'alone', 'frustrated', 'down',
  };
  static const _emotionMap = {
    'anxious': 'anxiety', 'anxiety': 'anxiety', 'worried': 'worry',
    'nervous': 'nervousness', 'panic': 'panic', 'scared': 'fear',
    'afraid': 'fear', 'sad': 'sadness', 'depressed': 'sadness',
    'lonely': 'loneliness', 'alone': 'loneliness', 'angry': 'anger',
    'frustrated': 'frustration', 'upset': 'distress', 'overwhelmed': 'overwhelm',
    'tired': 'fatigue', 'exhausted': 'fatigue', 'happy': 'happiness',
    'glad': 'happiness', 'joy': 'happiness', 'grateful': 'gratitude',
    'thankful': 'gratitude', 'excited': 'excitement', 'proud': 'pride',
    'calm': 'calm', 'relaxed': 'calm', 'peaceful': 'calm', 'hopeful': 'hope',
    'motivated': 'motivation', 'confident': 'confidence',
  };
  static const _stressMap = {
    'exam': 'exam pressure', 'exams': 'exam pressure', 'test': 'test pressure',
    'deadline': 'deadlines', 'deadlines': 'deadlines', 'assignment': 'workload',
    'assignments': 'workload', 'failing': 'fear of failing', 'fail': 'fear of failing',
    'money': 'financial stress', 'funding': 'financial stress', 'nsfas': 'financial stress',
    'sleep': 'sleep problems', 'insomnia': 'sleep problems', 'pressure': 'pressure',
    'burnout': 'burnout', 'overwhelmed': 'feeling overwhelmed',
  };
  static const _highRisk = [
    'kill myself', 'suicide', 'suicidal', 'end my life', 'end it all',
    'want to die', 'better off dead', 'hurt myself', 'self harm', 'self-harm',
    "don't want to live", 'no reason to live',
  ];
  static const _moderateRisk = [
    'hopeless', 'worthless', "can't cope", 'cannot cope', "can't go on",
    'give up', 'no point', 'nobody cares', 'breaking down',
  ];

  static JournalAnalysis _analyzeLocally(String text) {
    final lower = text.toLowerCase();
    final words = RegExp(r"[a-z']+").allMatches(lower).map((m) => m.group(0)!).toList();

    int pos = 0, neg = 0;
    for (final w in words) {
      if (_positive.contains(w)) pos++;
      if (_negative.contains(w)) neg++;
    }

    final emotions = <String>{};
    final stress = <String>{};
    for (final w in words) {
      if (_emotionMap[w] != null) emotions.add(_emotionMap[w]!);
      if (_stressMap[w] != null) stress.add(_stressMap[w]!);
    }

    final highHit = _highRisk.any(lower.contains);
    final modHit = _moderateRisk.any(lower.contains);

    String sentiment;
    double score;
    if (pos == 0 && neg == 0) {
      sentiment = 'neutral';
      score = 0.5;
    } else {
      score = ((pos + 1) / (pos + neg + 2)).clamp(0.05, 0.95);
      sentiment = score > 0.58 ? 'positive' : (score < 0.42 ? 'negative' : 'neutral');
    }
    if (highHit || modHit) {
      sentiment = 'negative';
      score = score.clamp(0.0, 0.25);
    }

    String risk = 'low';
    if (highHit) {
      risk = 'high';
    } else if (modHit || (neg >= 4 && sentiment == 'negative')) {
      risk = 'moderate';
    }

    String tip;
    if (risk == 'high') {
      tip = 'You are not alone, and what you feel matters. Please talk to someone '
          'now: the SADAG Suicide Crisis Line is 0800 567 567 (South Africa, 24h), '
          'or visit CUT Student Counselling.';
    } else if (sentiment == 'negative') {
      tip = 'It sounds like a heavy day. Try a few slow breaths, a short walk, or '
          'talking to a friend, and consider booking a CUT counselling session.';
    } else if (sentiment == 'positive') {
      tip = 'Lovely to hear this. Notice what helped today and try to repeat it.';
    } else {
      tip = 'Thanks for checking in with yourself. A little reflection each day builds resilience.';
    }

    if (emotions.isEmpty) emotions.add(sentiment == 'positive' ? 'contentment' : 'reflection');

    return JournalAnalysis(
      sentiment: sentiment,
      score: score,
      emotions: emotions.take(4).toList(),
      stressIndicators: stress.take(4).toList(),
      wellnessTip: tip,
      riskLevel: risk,
      source: 'On-device',
    );
  }
}
