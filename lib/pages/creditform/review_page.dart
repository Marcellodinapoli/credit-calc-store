import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/dimensions.dart';
import '../../services/progress_checker.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool? _canReview;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _canReview = false);
      return;
    }

    final ok = await hasCompletedPreContenzioso(user.uid);
    setState(() => _canReview = ok);
  }

  @override
  Widget build(BuildContext context) {
    return PersonalFormShell(
      pageTitle: 'Recensione',
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Dimensions.pagePaddingFor(context)),
          child: _canReview == null
              ? const CircularProgressIndicator()
              : _canReview!
                  ? _reviewForm(context)
                  : _blockedMessage(),
        ),
      ),
    );
  }

  Widget _blockedMessage() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Per lasciare una recensione devi completare almeno i corsi '
            'della sezione Pre-decadenza (video + quiz).',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.black54),
      ),
    );
  }

  Widget _reviewForm(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: Dimensions.dialogWidth(context, max: 500),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Lascia la tua recensione',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Scrivi la tua esperienza…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // QUI in futuro salvi su Firestore
            },
            child: const Text('Invia recensione'),
          ),
        ],
      ),
    );
  }
}
