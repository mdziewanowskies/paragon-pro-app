import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/receipt_image_cache.dart';

class ReceiptImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ReceiptImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<ReceiptImage> createState() => _ReceiptImageState();
}

class _ReceiptImageState extends State<ReceiptImage> {
  String? _localPath;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ReceiptImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty ||
        (!widget.imageUrl.startsWith('http://') &&
            !widget.imageUrl.startsWith('https://'))) {
      if (mounted) setState(() { _loading = false; _error = true; });
      return;
    }

    setState(() { _loading = true; _error = false; });

    final path = await ReceiptImageCache.getOrFetch(widget.imageUrl);

    if (mounted) {
      setState(() {
        _localPath = path;
        _loading = false;
        _error = path == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ??
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error || _localPath == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ??
            Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(Icons.receipt_long_rounded, size: 32, color: Colors.grey),
              ),
            ),
      );
    }

    return Image.file(
      File(_localPath!),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (_, __, ___) =>
          widget.errorWidget ??
          Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.broken_image_rounded, size: 32, color: Colors.grey),
            ),
          ),
    );
  }
}
