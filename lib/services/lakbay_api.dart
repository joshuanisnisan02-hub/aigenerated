import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class LakbayApi {
  LakbayApi({
    String chatBaseUrl = '',
    String ttsBaseUrl = '',
    String publishableKey = '',
  })  : chatBaseUrl = chatBaseUrl.trim().isEmpty
            ? 'https://utzfhdvmevbjtahjsncc.supabase.co/functions/v1'
            : chatBaseUrl,
        ttsBaseUrl = ttsBaseUrl.trim().isEmpty
            ? 'https://utzfhdvmevbjtahjsncc.supabase.co/functions/v1'
            : ttsBaseUrl,
        publishableKey = publishableKey.trim().isEmpty
            ? 'sb_publishable_uyxOXkx-5pao9PU4Eg4xjQ_n1E01sGQ'
            : publishableKey;

  /// Base URL for the live AI/history backend.
  final String chatBaseUrl;

  /// Base URL for the natural Filipino speech backend.
  final String ttsBaseUrl;

  /// Supabase publishable key. Publishable keys are intended for client apps.
  final String publishableKey;

  bool get hasNaturalVoice => ttsBaseUrl.trim().isNotEmpty;
  bool get hasLiveChat => chatBaseUrl.trim().isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (publishableKey.trim().isNotEmpty) 'apikey': publishableKey.trim(),
      };

  Future<String> ask(String question) async {
    if (!hasLiveChat) {
      return _demoAnswer(question);
    }

    try {
      final response = await http.post(
        Uri.parse('${chatBaseUrl.replaceAll(RegExp(r'/$'), '')}/lakbay-chat'),
        headers: _headers,
        body: jsonEncode({'question': question}),
      );

      if (response.statusCode >= 400) {
        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        throw Exception(body.isEmpty ? 'Hindi makakonekta sa history service.' : body);
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final answer = (data['answer'] as String?)?.trim();
      if (answer == null || answer.isEmpty) {
        throw Exception('Walang sagot na natanggap.');
      }
      return answer;
    } catch (_) {
      // Keep the classroom app usable even if the live AI provider is temporarily
      // unavailable. Known demo topics still have a local fallback.
      return _demoAnswer(question);
    }
  }

  Future<Uint8List> synthesize(String text) async {
    if (!hasNaturalVoice) {
      throw StateError('Natural Filipino TTS backend is not configured.');
    }

    final response = await http.post(
      Uri.parse('${ttsBaseUrl.replaceAll(RegExp(r'/$'), '')}/lakbay-tts'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode >= 400) {
      final message = utf8.decode(response.bodyBytes, allowMalformed: true);
      throw Exception(
        message.isEmpty
            ? 'Hindi makagawa ng natural Filipino speech.'
            : 'Hindi makagawa ng natural Filipino speech: $message',
      );
    }

    return response.bodyBytes;
  }

  String _demoAnswer(String question) {
    final q = question.toLowerCase();
    if (q.contains('katipunan')) {
      return 'Mahalaga ang Katipunan dahil isa itong lihim na samahang naghangad ng ganap na kalayaan mula sa kolonyal na pamamahala ng Espanya. Itinatag ito noong Hulyo 7, 1892. Isa sa mga pangunahing pinuno nito si Andres Bonifacio. Sa halip na reporma lamang, tahasang itinulak ng Katipunan ang paghihiwalay ng Pilipinas sa Espanya.';
    }
    if (q.contains('mactan') || q.contains('lapulapu')) {
      return 'Ang Labanan sa Mactan ay naganap noong Abril 27, 1521. Hinarap ng mga mandirigma ni Lapulapu ang puwersa ni Ferdinand Magellan. Napatay si Magellan sa labanan. Mahalagang tandaan na ang pangyayaring ito ay hindi pa isang modernong pambansang pakikibaka para sa Pilipinas, ngunit isa itong malinaw na halimbawa ng lokal na pagtutol sa dayuhang panghihimasok.';
    }
    if (q.contains('rizal')) {
      return 'Si Dr. Jose Rizal ay isang manunulat, manggagamot, at repormista. Sa pamamagitan ng Noli Me Tangere at El Filibusterismo, inilantad niya ang mga suliranin at pang-aabuso sa lipunang kolonyal. Binaril siya sa Bagumbayan noong Disyembre 30, 1896.';
    }
    if (q.contains('martial law')) {
      return 'Ang Martial Law sa ilalim ni Ferdinand Marcos Sr. ay idineklara sa pamamagitan ng Proclamation No. 1081, na may petsang Setyembre 21, 1972 at inanunsyo sa publiko noong Setyembre 23. Sa pagtalakay nito, mahalagang gumamit ng primaryang dokumento, opisyal na tala, akademikong pananaliksik, at testimonya ng mga nakaranas ng panahong iyon dahil maraming usaping politikal at historikal ang patuloy na pinagtatalunan.';
    }
    return 'Magandang tanong iyan. Hindi available ang live history AI sa sandaling ito. Kapag nakakonekta ang AI backend, masasagot ni Lakbay ang iba pang paksa sa Kasaysayan ng Pilipinas at hindi lamang ang mga nakahandang halimbawa.';
  }
}
