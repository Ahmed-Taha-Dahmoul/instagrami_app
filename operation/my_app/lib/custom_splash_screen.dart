import 'package:flutter/material.dart';

class CustomSplashScreen extends StatefulWidget {
  @override
  _CustomSplashScreenState createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Animation Controller: Controls the animation's duration and state.
    _controller = AnimationController(
      vsync: this, // Required for animations, provides timing.
      duration: Duration(seconds: 2), // Adjust the duration as needed.
    );

    // Tween Animation: Defines the animation's start and end values.
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut, // Choose a different curve for different effects.
      ),
    );

    // Start the animation.
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set your background color.
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Opacity(
              opacity: _animation.value,
              child: Transform.scale(
                scale: _animation.value,
                child: Image.asset(
                  'assets/splash.png', // Replace with your logo's path
                  width: 200, // Adjust size as needed
                  height: 200,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Very important: Clean up the controller.
    super.dispose();
  }
}