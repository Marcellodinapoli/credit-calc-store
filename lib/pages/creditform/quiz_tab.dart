// -----------------------------------------------------------------------------
// IMPORT / CONFIG
// -----------------------------------------------------------------------------
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/adaptive_button_styles.dart';
import '../../core/dimensions.dart';
import 'course_progress_meta.dart';

// -----------------------------------------------------------------------------
// QUIZ TAB — ROOT
// -----------------------------------------------------------------------------
class QuizTab extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String courseLabel;
  final String? catalogCategory;

  const QuizTab({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseLabel,
    this.catalogCategory,
  });

  @override
  State<QuizTab> createState() => _QuizTabState();
}

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class _QuizTabState extends State<QuizTab> {
  final List<Map<String, dynamic>> _questions = [];
  final Map<int, int> _answers = {};
  final List<Map<String, dynamic>> _answerDetails = [];

  int _currentIndex = 0;
  int _remainingSeconds = 60;
  int _errorCount = 0;

  bool _quizStarted = false;
  bool _quizFinished = false;
  bool _locked = false;

  Timer? _timer;

// -----------------------------------------------------------------------------
// LIFECYCLE
// -----------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

// -----------------------------------------------------------------------------
// LOAD QUESTIONS + RANDOMIZE
// -----------------------------------------------------------------------------
  Future<void> _loadQuestions() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .get();

    if (!snapshot.exists) return;

    final data = snapshot.data();

    if (data == null || data['quiz'] == null) return;

    final quizData = data['quiz'] as Map<String, dynamic>;
    final List<dynamic> questionList = quizData['questions'] ?? [];

    final random = Random();
    _questions.clear();
    _errorCount = 0;

    for (var q in questionList) {
      try {
        final options = List<String>.from(q['options']);
        final int correctIndex = q['correctIndex'];
        final correctText = options[correctIndex];

        options.shuffle(random);
        final newCorrectIndex = options.indexOf(correctText);

        _questions.add({
          'question': q['question'],
          'options': options,
          'correctIndex': newCorrectIndex,
        });
      } catch (_) {
        _errorCount++;
      }
    }

    setState(() {});
  }

// -----------------------------------------------------------------------------
// QUIZ FLOW
// -----------------------------------------------------------------------------
  void _startQuiz() {
    setState(() {
      _quizStarted = true;
      _quizFinished = false;
      _currentIndex = 0;
      _remainingSeconds = 60;
      _answers.clear();
      _answerDetails.clear();
      _locked = false;
      _errorCount = 0;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 1) {
        t.cancel();
        _finishQuiz();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _finishQuiz() async {
    _timer?.cancel();
    setState(() => _quizFinished = true);
    await _saveQuizProgress();
  }

  void _selectAnswer(int index) {
    if (_locked) return;

    setState(() {
      _answers[_currentIndex] = index;
      _locked = true;
    });

    Future.delayed(const Duration(milliseconds: 600), _nextQuestion);
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _locked = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _locked = false;
      });
    }
  }

// -----------------------------------------------------------------------------
// SAVE PROGRESS (Firestore)
// -----------------------------------------------------------------------------
  Future<void> _saveQuizProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final total = _questions.length;
    int correct = 0;
    _answerDetails.clear();

    for (int i = 0; i < total; i++) {
      final q = _questions[i];
      final selectedIndex = _answers[i];
      final correctIndex = q['correctIndex'];

      final isCorrect = selectedIndex == correctIndex;
      if (isCorrect) correct++;

      _answerDetails.add({
        'question': q['question'],
        'selected': selectedIndex != null
            ? q['options'][selectedIndex]
            : 'Nessuna risposta',
        'correct': q['options'][correctIndex],
        'isCorrect': isCorrect,
      });
    }

    final percent = (correct / total * 100).round();

    // Calcolo tempo impiegato (60 - secondi rimasti)
    final int elapsedSeconds = 60 - _remainingSeconds;

    await FirebaseFirestore.instance
        .collection('userProgress')
        .doc(user.uid)
        .collection('courses')
        .doc(widget.courseId)
        .set({
      ...CourseProgressMeta.fields(
        courseId: widget.courseId,
        title: widget.courseTitle,
        courseLabel: widget.courseLabel,
        catalogCategory: widget.catalogCategory,
      ),
      'lastScore': percent,
      'quizAttempts': FieldValue.increment(1),
      'lastQuizDate': FieldValue.serverTimestamp(),   // ✅ aggiunto
      'lastQuizTime': elapsedSeconds,                 // ✅ aggiunto
      'answerDetails': _answerDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

// -----------------------------------------------------------------------------
// BUILD
// -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty || _errorCount > 0) {
      return Center(
        child: Text(
          _errorCount > 0
              ? 'Errore nel caricamento del quiz'
              : 'Nessun quiz disponibile',
          style: const TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    // -------------------- START SCREEN --------------------
    if (!_quizStarted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quiz di verifica',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Metti alla prova le tue conoscenze\nsul corso appena seguito',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _startQuiz,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Inizia quiz'),
              style: AdaptiveButtonStyles.formElevated(),
            ),
          ],
        ),
      );
    }

    // -------------------- RESULT SCREEN --------------------
    if (_quizFinished) {
      return _buildResultScreen();
    }

    // -------------------- QUIZ SCREEN --------------------
    final current = _questions[_currentIndex];
    final total = _questions.length;
    final answered = _answers.length;
    final selected = _answers[_currentIndex];
    final progress = answered / total;
    final bottomInset = Dimensions.resolvedBottomInset(context);

    final counterText = Text(
      '$answered / $total risposte date',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );

    final backButton = ElevatedButton.icon(
      onPressed: _currentIndex > 0 ? _previousQuestion : null,
      icon: const Icon(Icons.arrow_back),
      label: const Text('Indietro'),
      style: AdaptiveButtonStyles.formElevatedMuted(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            color: Colors.orange,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Domanda ${_currentIndex + 1} di $total',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _remainingSeconds <= 25
                      ? (_remainingSeconds % 2 == 0
                          ? Colors.red
                          : Colors.transparent)
                      : Colors.black87,
                ),
                child: Text(_formatTime(_remainingSeconds)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            current['question'],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: List.generate(current['options'].length, (i) {
                final isSelected = selected == i;
                return GestureDetector(
                  onTap: () => _selectAnswer(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? Colors.orange : Colors.grey.shade400,
                        width: 2,
                      ),
                      color: isSelected
                          ? Colors.orange.withValues(alpha: 0.15)
                          : const Color(0xFFF5F5F5),
                    ),
                    child: Text(
                      current['options'][i],
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            isSelected ? Colors.black : Colors.grey.shade800,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          if (Dimensions.isPhone(context)) ...[
            counterText,
            const SizedBox(height: 8),
            backButton,
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                backButton,
                counterText,
              ],
            ),
          SizedBox(height: bottomInset + 8),
        ],
      ),
    );
  }

// -----------------------------------------------------------------------------
// RESULT SCREEN
// -----------------------------------------------------------------------------
  Widget _buildResultScreen() {
    final total = _questions.length;
    int correct = 0;

    for (int i = 0; i < total; i++) {
      if (_answers[i] == _questions[i]['correctIndex']) correct++;
    }

    final percent = (correct / total * 100).round();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        Dimensions.resolvedBottomInset(context) + 24,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$percent%',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startQuiz,
              icon: const Icon(Icons.refresh),
              label: const Text('Ricomincia'),
              style: AdaptiveButtonStyles.formElevated(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAnswerDetails,
              icon: const Icon(Icons.list_alt),
              label: const Text('Mostra dettagli risposte'),
              style: AdaptiveButtonStyles.formElevatedMuted(),
            ),
          ),
        ],
      ),
    );
  }

// -----------------------------------------------------------------------------
// ANSWER DETAILS DIALOG
// -----------------------------------------------------------------------------
  void _showAnswerDetails() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dettaglio risposte'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.builder(
            itemCount: _answerDetails.length,
            itemBuilder: (context, index) {
              final d = _answerDetails[index];
              final isCorrect = d['isCorrect'] == true;

              return ListTile(
                title: Text(d['question']),
                subtitle: Text(
                  'Risposta: ${d['selected']}',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                trailing: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
