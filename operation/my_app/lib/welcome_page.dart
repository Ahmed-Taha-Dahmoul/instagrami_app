import 'package:flutter/material.dart';
import 'dart:math';
import 'login_page.dart'; // Import the LoginPage
import 'signup.dart';

// Constants
const _backgroundColor = Color(0xFFF5C7B8);
const _primaryColor = Color(0xFFCF8360);
const _buttonSize = Size(150, 50);
const _textStyle = TextStyle(
  color: Color(0xFFCF8360),
  fontSize: 36,
  fontWeight: FontWeight.bold,
);

// Data Models
class PageContent {
  final String text;
  final String? buttonText;
  final int? navigateTo;
  final List<AnimatedElementData> elements;

  PageContent({
    required this.text,
    this.buttonText,
    this.navigateTo,
    required this.elements,
  });
}

class AnimatedElementData {
  final String type;
  final String imageUrl;
  final double top;
  final double? left;
  final double? right;

  AnimatedElementData({
    required this.type,
    required this.imageUrl,
    required this.top,
    this.left,
    this.right,
  });
}

class WelcomePage extends StatefulWidget {
  final ValueNotifier<bool> isLoggedIn; // Make it required

  WelcomePage({required this.isLoggedIn}); // Make it required in constructor
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  final List<PageContent> _pages = [
    PageContent(
      text: '160 COUNTRIES. 40\nCURRENCIES. ONE\nACCOUNT',
      buttonText: 'Get Started',
      navigateTo: 2,
      elements: [
        AnimatedElementData(
          type: 'jar',
          imageUrl: 'assets/jar1.png',
          top: 50.0,
          left: 20.0,
        ),
        AnimatedElementData(
          type: 'coin',
          imageUrl: 'assets/coin.png',
          top: 20.0,
          right: 80.0,
        ),
      ],
    ),
    PageContent(
      text: 'SEND MONEY AND\nGET PAID FROM\nABROAD',
      buttonText: 'Check Rates',
      navigateTo: 2,
      elements: [
        AnimatedElementData(
          type: 'plane',
          imageUrl: 'assets/plane.png',
          top: 100.0,
          right: 50.0,
        ),
      ],
    ),
    PageContent(
      text: 'ONE ACCOUNT, FOR\nALL THE MONEY IN\nTHE WORLD',
      elements: [
        AnimatedElementData(
          type: 'globe',
          imageUrl: 'assets/globe.png',
          top: 100.0,
          right: 50.0,
        ),
        AnimatedElementData(
          type: 'coin',
          imageUrl: 'assets/coin.png',
          top: 50.0,
          left: 20.0,
        ),
      ],
    ),
  ];

  late final PageController _pageController;
  late final List<AnimationController> _controllers;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controllers = [
      AnimationController(vsync: this, duration: const Duration(seconds: 5)),
      AnimationController(vsync: this, duration: const Duration(seconds: 8)),
      AnimationController(vsync: this, duration: const Duration(seconds: 6)),
    ];
    _controllers.forEach((controller) => controller.repeat());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: _handlePageChange,
            itemBuilder: (context, index) => _buildPage(_pages[index]),
          ),
          _buildPageIndicator(),
          if (_currentPage < _pages.length - 1) _buildCurrentPageButton(),
          if (_currentPage == _pages.length - 1) _buildAuthButtons(),
        ],
      ),
    );
  }

  void _handlePageChange(int index) {
    setState(() => _currentPage = index);
  }

  Widget _buildPage(PageContent page) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              page.text,
              textAlign: TextAlign.center,
              style: _textStyle,
            ),
          ),
        ),
        ...page.elements.map((element) => _AnimatedElement(
              data: element,
              controller: _getControllerForType(element.type),
            )),
      ],
    );
  }

  AnimationController _getControllerForType(String type) {
    switch (type) {
      case 'jar':
        return _controllers[0];
      case 'coin':
        return _controllers[1];
      case 'plane':
      case 'globe':
      default:
        return _controllers[2];
    }
  }

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: _currentPage == index ? 15 : 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: _currentPage == index ? _primaryColor : Colors.grey[400],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentPageButton() {
    final currentPage = _pages[_currentPage];

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: _buttonSize.width,
          child: ElevatedButton(
            onPressed: () => _navigateToPage(currentPage.navigateTo),
            child: Text(currentPage.buttonText!),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPage(int? targetPage) {
    if (targetPage == null) return;
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeIn,
    );
  }

  Widget _buildAuthButtons() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AuthButton(
            text: 'Login',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      LoginPage(isLoggedIn: widget.isLoggedIn)),
            ),
          ),
          _AuthButton(
            text: 'Register',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SignupPage(
                      isLoggedIn: widget
                          .isLoggedIn)), // Now correctly passing isLoggedIn
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedElement extends StatelessWidget {
  final AnimatedElementData data;
  final AnimationController controller;

  const _AnimatedElement({
    required this.data,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Positioned(
          top: data.top + 10 * sin(controller.value * 2 * pi),
          left: data.left,
          right: data.right,
          child: Transform.rotate(
            angle: 0.2 * sin(controller.value * 4 * pi),
            child: Image.asset(data.imageUrl, width: 80),
          ),
        );
      },
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _AuthButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _buttonSize.width,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          foregroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
