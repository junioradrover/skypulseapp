import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    
    // Fallback: navigate after 10 seconds even if video doesn't finish
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset('assets/opening.mp4');
    
    // Set volume to 0 (mute)
    await _controller.setVolume(0.0);
    
    await _controller.initialize();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      
      // Play the video
      await _controller.play();
      
      // Listen for video completion
      _controller.addListener(_videoListener);
    }
  }

  void _videoListener() {
    if (_controller.value.position >= _controller.value.duration) {
      // Video finished, navigate to home screen
      _controller.removeListener(_videoListener);
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(
                color: Colors.white,
              ),
      ),
    );
  }
}

