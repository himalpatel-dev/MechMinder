import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart'; // Add this import
import 'home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  // If true, we just pop the navigator when done instead of replacing the route
  final bool isFromSettings;

  const OnboardingScreen({super.key, this.isFromSettings = false});

  Future<void> _onIntroEnd(BuildContext context) async {
    // 1. Save that we have seen the onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!context.mounted) return;

    if (isFromSettings) {
      // If we came from settings, just go back
      Navigator.of(context).pop();
    } else {
      // Otherwise, go to Home Screen (replace so user can't go back to intro)
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    final bodyStyle = TextStyle(fontSize: 19.0, color: textColor);
    final pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      bodyTextStyle: bodyStyle,
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: backgroundColor,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      globalBackgroundColor: backgroundColor,
      allowImplicitScrolling: true,

      // autoScrollDuration: 5000, // Removed auto-scroll
      // infiniteAutoScroll: true, // Removed loop
      pages: [
        PageViewModel(
          title: "Master Your Maintenance",
          body:
              "Welcome to MechMinder. The distinct way to track your vehicle's health, history, and handy documents all in one place.",
          image: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: Lottie.asset('assets/animations/securecar.json', width: 200),
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Never Miss a Service",
          body:
              "Keep a detailed digital log of every repair, oil change, and part replacement. Know exactly what was done and when.",
          image: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: Lottie.asset(
              'assets/animations/Maintenance.json', // Case sensitive
              width: 200,
            ),
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Stay Road Legal & Safe",
          body:
              "Get timely alerts for insurance renewals, PUC expiry, and upcoming maintenance. We remember dates so you don't have to.",
          image: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: Lottie.asset(
              'assets/animations/Car_tick.json', // Case sensitive
              width: 200,
            ),
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Track Every Penny",
          body:
              "Monitor fuel and service costs, and securely store your License, RC, and Insurance — all in one place.",
          image: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: Lottie.asset(
              'assets/animations/CarFines.json', // Case sensitive
              width: 200,
            ),
          ),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context), // You can override onSkip
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBackButton: false,
      //rtl: true, // Display as right-to-left
      back: const Icon(Icons.arrow_back),
      skip: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
      curve: Curves.easeInOut,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: const Color(0xFFBDBDBD),
        activeColor: isDarkMode
            ? Colors.white
            : Colors.blue, // Dynamic active dot color
        activeSize: const Size(22.0, 10.0),
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}
