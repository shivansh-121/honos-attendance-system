import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A widget that efficiently displays a base64 encoded image with in-memory caching.
/// This prevents expensive base64 decoding on every frame/rebuild.
class Base64ImageWidget extends StatefulWidget {
  final String base64String;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final double borderRadius;

  const Base64ImageWidget({
    super.key,
    required this.base64String,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius = 0,
  });

  @override
  State<Base64ImageWidget> createState() => _Base64ImageWidgetState();
}

class _Base64ImageWidgetState extends State<Base64ImageWidget> {
  Uint8List? _bytes;
  static final Map<String, Uint8List> _cache = {};

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(Base64ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64String != widget.base64String) {
      _decode();
    }
  }

  void _decode() {
    if (widget.base64String.length < 10) {
      _bytes = null;
      return;
    }

    if (_cache.containsKey(widget.base64String)) {
      _bytes = _cache[widget.base64String];
      return;
    }

    // Decode in background if it's a large string to keep UI thread smooth
    if (widget.base64String.length > 50000) {
      compute(base64Decode, widget.base64String).then((bytes) {
        if (mounted) {
          setState(() {
            _cache[widget.base64String] = bytes;
            _bytes = bytes;
          });
        }
      });
    } else {
      _bytes = base64Decode(widget.base64String);
      _cache[widget.base64String] = _bytes!;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return widget.placeholder ?? _defaultPlaceholder();
    }

    Widget image = Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );

    if (widget.borderRadius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: image,
      );
    }

    return image;
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[800],
      child: const Icon(Icons.person, color: Colors.white54),
    );
  }
}
