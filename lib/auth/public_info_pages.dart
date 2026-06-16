import 'package:flutter/material.dart';

import '../widgets/public_page_shell.dart';
import '../widgets/public_top_menu.dart';

class PublicAboutPage extends StatelessWidget {
  const PublicAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PublicPageShell(
      current: PublicPage.about,
      pageTitle: 'Chi siamo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CreditCore è un ecosistema di servizi per il settore del credito: '
            'formazione, strumenti operativi e opportunità lavorative.',
          ),
          SizedBox(height: 16),
          Text(
            'La piattaforma nasce per rendere più semplice e misurabile la crescita '
            'professionale di operatori, consulenti e aziende.',
          ),
          SizedBox(height: 24),
          _SectionTitle('Cosa trovi'),
          SizedBox(height: 12),
          _BulletLine(
            'CreditForm: corsi, video, quiz, role play e progressi',
          ),
          _BulletLine(
            'CreditCalc: calcoli, simulazioni e strumenti',
          ),
          _BulletLine(
            'CreditJob: incontro tra aziende e professionisti',
          ),
        ],
      ),
    );
  }
}

class PublicContactsPage extends StatelessWidget {
  const PublicContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PublicPageShell(
      current: PublicPage.contacts,
      pageTitle: 'Contatti',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Per informazioni, assistenza o richieste commerciali puoi contattarci qui.',
          ),
          SizedBox(height: 16),
          _InfoCard(
            children: [
              _InfoCardRow(
                label: 'Email',
                value: 'support@creditcore.it',
              ),
              SizedBox(height: 14),
              _InfoCardRow(
                label: 'Orari',
                value: 'Lun–Ven • 9:00–18:00',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PublicFaqPage extends StatelessWidget {
  const PublicFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PublicPageShell(
      current: PublicPage.faq,
      pageTitle: 'FAQ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FaqItem(
            question: 'Come accedo alla piattaforma?',
            answer:
                'Clicca “Accedi” e usa email e password. Se sei un utente Work, '
                'verrai reindirizzato al portale Work.',
          ),
          _FaqItem(
            question: 'Quali piani sono disponibili?',
            answer:
                'Consulta la pagina Piani per FREE, PLUS, ENTERPRISE e la '
                'soluzione AZIENDA per team e organizzazioni.',
          ),
          _FaqItem(
            question: 'Dove vedo i miei corsi e i progressi?',
            answer:
                'Dopo l’accesso, entra in CreditForm → Corsi / I miei progressi.',
          ),
          _FaqItem(
            question: 'Posso usare la piattaforma da telefono?',
            answer: 'Sì, l’interfaccia è responsive e funziona anche su mobile.',
          ),
          _FaqItem(
            question: 'Ho problemi di accesso, cosa faccio?',
            answer:
                'Scrivi a support@creditcore.it indicando email e schermata di errore.',
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: PublicPageTheme.text,
        height: 1.3,
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoCardRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCardRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: PublicPageTheme.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: PublicPageTheme.text,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(answer),
        ],
      ),
    );
  }
}
