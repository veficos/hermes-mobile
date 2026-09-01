/// OnboardingScreen: first-launch feature tour.
///
/// Desktop parity note: desktop's tour (`src/lib/tour/*`) is a spotlight
/// overlay that highlights live widgets in place — it depends on
/// `driver.js`-style DOM measurement that has no cheap Flutter analog, and
/// pinning it to real widget positions across the home/session/terminal/git
/// screens would be a much larger, riskier change than the tour itself is
/// worth. A full-screen swipeable carousel shown once at first launch is the
/// mobile-native equivalent (this is how most iOS/Android apps introduce
/// their feature set) rather than a literal port of the desktop mechanism.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';

const _kOnboardingSeenKey = 'hm_onboarding_seen_v1';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingSeenKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingSeenKey, true);
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final pages = [
      _OnboardingPage(
        icon: Icons.chat_bubble_outline,
        title: l10n.onboardingChatTitle,
        description: l10n.onboardingChatDescription,
      ),
      _OnboardingPage(
        icon: Icons.folder_outlined,
        title: l10n.onboardingProjectsTitle,
        description: l10n.onboardingProjectsDescription,
      ),
      _OnboardingPage(
        icon: Icons.terminal,
        title: l10n.onboardingTerminalTitle,
        description: l10n.onboardingTerminalDescription,
      ),
      _OnboardingPage(
        icon: Icons.search,
        title: l10n.onboardingPaletteTitle,
        description: l10n.onboardingPaletteDescription,
      ),
      _OnboardingPage(
        icon: Icons.pets,
        title: l10n.onboardingPetTitle,
        description: l10n.onboardingPetDescription,
      ),
    ];
    final isLast = _page == pages.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.onboardingSkip),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final page = pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              page.icon,
                              size: 44,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: HermesType.onSurface(
                              HermesType.title,
                              theme,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: HermesType.onSurfaceVariant(
                              HermesType.callout,
                              theme,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLast
                        ? _finish
                        : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    child: Text(
                      isLast ? l10n.onboardingStart : l10n.onboardingNext,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
