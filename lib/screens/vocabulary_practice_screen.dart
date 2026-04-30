import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/vocabulary_item.dart';
import '../models/vocabulary_practice_state.dart';
import '../services/language_manager.dart';
import '../services/vocabulary_practice_service.dart';

class VocabularyPracticeScreen extends StatefulWidget {
  final List<VocabularyItem> allWords;
  final List<VocabularyItem>? initialWords;

  const VocabularyPracticeScreen({
    super.key,
    required this.allWords,
    this.initialWords,
  });

  @override
  State<VocabularyPracticeScreen> createState() => _VocabularyPracticeScreenState();
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen> {
  final LanguageManager _languageManager = LanguageManager();
  final VocabularyPracticeService _practiceService = VocabularyPracticeService();

  List<VocabularyItem> _deck = [];
  int _index = 0;
  bool _revealed = false;
  bool _loading = true;

  VocabularyItem get _currentWord => _deck[_index];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _practiceService.initialize();
    final source = (widget.initialWords != null && widget.initialWords!.isNotEmpty)
        ? widget.initialWords!
        : widget.allWords;
    final deck = _practiceService.buildPracticeDeck(source);
    if (!mounted) return;
    setState(() {
      _deck = deck;
      _loading = false;
    });
  }

  Future<void> _answer(VocabularyPracticeOutcome outcome) async {
    await _practiceService.recordOutcome(_currentWord, outcome);
    if (!mounted) return;
    if (_index == _deck.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_languageManager.getText('practiceSessionCompleted'))),
      );
      return;
    }
    setState(() {
      _index += 1;
      _revealed = false;
    });
  }

  void _goNext() {
    if (_index >= _deck.length - 1) return;
    setState(() {
      _index += 1;
      _revealed = false;
    });
  }

  void _goPrevious() {
    if (_index <= 0) return;
    setState(() {
      _index -= 1;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_languageManager.getText('practiceVocabulary')),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _deck.isEmpty
                  ? Center(
                      child: Text(
                        _languageManager.getText('noVocabularyToPractice'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_index + 1}/${_deck.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              const Spacer(),
                              if (_practiceService.isDue(_currentWord))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _languageManager.getText('reviewDue'),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _revealed = !_revealed;
                                });
                              },
                              borderRadius: BorderRadius.circular(26),
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey<bool>(_revealed),
                                tween: Tween<double>(
                                  begin: _revealed ? 0 : 1,
                                  end: _revealed ? 1 : 0,
                                ),
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeInOutCubic,
                                builder: (context, value, child) {
                                  final angle = value * math.pi;
                                  final showBack = angle > math.pi / 2;
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateY(showBack ? math.pi : 0),
                                      child: _buildPracticeCard(
                                        isBack: showBack,
                                        word: _currentWord,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _index > 0 ? _goPrevious : null,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: Text(_languageManager.getText('previous')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _index < _deck.length - 1 ? _goNext : null,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: Text(_languageManager.getText('next')),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _answer(VocabularyPracticeOutcome.stillLearning),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                  child: Text(_languageManager.getText('stillLearning')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _answer(VocabularyPracticeOutcome.gotIt),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: Text(_languageManager.getText('gotIt')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildPracticeCard({
    required bool isBack,
    required VocabularyItem word,
  }) {
    final textPrimary = const Color(0xFF0B2952);
    final textHint = const Color(0xFF0E7CB7);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _languageManager.getText('wordOfTheMoment'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: textHint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      word.vocab,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD54A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_border_rounded,
                  color: Color(0xFF0B2952),
                  size: 22,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            isBack ? word.mean : '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textPrimary.withOpacity(0.9),
              height: 1.25,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 18,
                color: textHint,
              ),
              const SizedBox(width: 8),
              Text(
                _languageManager.getText('tapToFlipDefinition'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
