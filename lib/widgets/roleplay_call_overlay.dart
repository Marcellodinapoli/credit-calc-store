import 'package:flutter/material.dart';

import '../core/dimensions.dart';
import '../services/roleplay_voice_status.dart';
import 'roleplay_practice_details_panel.dart';

class RoleplayCallOverlay extends StatelessWidget {
  const RoleplayCallOverlay({
    super.key,
    required this.title,
    required this.practiceData,
    required this.voiceStatus,
    required this.chatHistory,
    required this.onHangUp,
  });

  final String title;
  final List<dynamic> practiceData;
  final RoleplayVoiceStatus voiceStatus;
  final List<Map<String, String>> chatHistory;
  final VoidCallback onHangUp;

  String get _statusLabel {
    return switch (voiceStatus) {
      RoleplayVoiceStatus.thinking => 'Il debitore sta pensando…',
      RoleplayVoiceStatus.speaking =>
        'Il debitore parla — interrompi parlando',
      RoleplayVoiceStatus.connecting => 'Connessione in corso…',
      RoleplayVoiceStatus.error => 'Errore di connessione',
      _ => 'Chiamata attiva — parla liberamente',
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = !Dimensions.isPhone(context) &&
        MediaQuery.sizeOf(context).width >= 900;
    final lastAssistant = chatHistory.lastWhere(
      (message) => message['role'] == 'assistant',
      orElse: () => const {'role': 'assistant', 'content': ''},
    );
    final lastLine = (lastAssistant['content'] ?? '').trim();

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                      child: SingleChildScrollView(
                        child: RoleplayPracticeDetailsPanel(
                          title: title,
                          practiceData: practiceData,
                          compact: true,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _callPanel(context, lastLine)),
                ],
              )
            : _callPanel(context, lastLine),
      ),
    );
  }

  Widget _callPanel(BuildContext context, String lastLine) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 48,
              maxWidth: 560,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.record_voice_over_outlined,
                    color: Colors.white70,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: lastLine.isEmpty
                        ? const Text(
                            'In attesa del debitore…',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Debitore (AI)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lastLine,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: onHangUp,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.call_end),
                    label: const Text('Termina chiamata'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Simulazione formativa: parla come in una telefonata reale.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  if (Dimensions.isPhone(context) &&
                      practiceData.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    RoleplayPracticeDetailsPanel(
                      title: title,
                      practiceData: practiceData,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
