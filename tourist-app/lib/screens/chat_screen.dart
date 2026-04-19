import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String,String>> _messages = [];
  bool _loading = false;
  String _language = 'english';

  final List<Map<String,String>> _languages = [
    {'code':'english','label':'🇬🇧 EN'},{'code':'hindi','label':'🇮🇳 HI'},
    {'code':'chinese','label':'🇨🇳 ZH'},{'code':'spanish','label':'🇪🇸 ES'},
    {'code':'french','label':'🇫🇷 FR'},{'code':'arabic','label':'🇸🇦 AR'},
    {'code':'japanese','label':'🇯🇵 JA'},{'code':'korean','label':'🇰🇷 KO'},
    {'code':'assamese','label':'🇮🇳 AS'},{'code':'bengali','label':'🇧🇩 BN'},
  ];

  Future<void> _send() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty || _loading) return;
    _msgCtrl.clear();
    setState(() { _messages.add({'role':'user','text':msg}); _loading = true; });
    _scrollToBottom();
    try {
      final res = await ApiService.chat(msg, _language);
      setState(() => _messages.add({'role':'ai','text':res['response'] ?? 'No response'}));
    } catch (e) {
      setState(() => _messages.add({'role':'ai','text':'Connection error. Please try again.'}));
    }
    setState(() => _loading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFa855f7)])),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20,16,20,16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🤖 AI Assistant', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const Text('Llama3.2 — 20+ languages — local AI', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, children: _languages.map((lang) {
                    final active = _language == lang['code'];
                    return GestureDetector(
                      onTap: () => setState(() => _language = lang['code']!),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? Colors.white : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(lang['label']!, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: active ? const Color(0xFF6C63FF) : Colors.white,
                        )),
                      ),
                    );
                  }).toList()),
                ),
              ]),
            ),
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🌏', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text('Ask me anything about NE India!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                const Text('Safety tips, tourist spots, local culture', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  'Best places in Meghalaya?', '最好的旅游景点？', 'Consejos de seguridad', 'Safety tips for trekking',
                ].map((s) => GestureDetector(
                  onTap: () { _msgCtrl.text = s; _send(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFf0e8ff), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFe8d5ff))),
                    child: Text(s, style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
                  ),
                )).toList()),
              ]))
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFf0e8ff))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🤖 ', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
                          const SizedBox(width: 8),
                          Text('Thinking in $_language...', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ]),
                      ),
                    );
                  }
                  final msg = _messages[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF6C63FF) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isUser ? null : Border.all(color: const Color(0xFFf0e8ff)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!isUser) const Text('🤖 TourSafe360 AI', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.w600)),
                        if (!isUser) const SizedBox(height: 4),
                        Text(msg['text']!, style: TextStyle(color: isUser ? Colors.white : const Color(0xFF333333), fontSize: 14, height: 1.5)),
                      ]),
                    ),
                  );
                },
              ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(16,8,16,16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFf0e8ff)))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Message in any language...',
                  filled: true, fillColor: const Color(0xFFf8f0ff),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFe8d5ff))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFe8d5ff))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loading ? null : _send,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFa855f7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
