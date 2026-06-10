import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen image viewer with PageView for swiping through multiple images.
void openImageViewer(BuildContext context, List<String> imagePaths,
    {int initialIndex = 0}) {
  if (imagePaths.isEmpty) return;

  final validPaths =
      imagePaths.where((p) => p.isNotEmpty && File(p).existsSync()).toList();
  if (validPaths.isEmpty) return;

  final startIndex =
      initialIndex.clamp(0, validPaths.length - 1).toInt();

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _ImageViewerScreen(
        imagePaths: validPaths,
        initialIndex: startIndex,
      ),
    ),
  );
}

class _ImageViewerScreen extends StatefulWidget {
  const _ImageViewerScreen({
    required this.imagePaths,
    required this.initialIndex,
  });

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imagePaths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imagePaths.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.file(
              File(widget.imagePaths[i]),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
