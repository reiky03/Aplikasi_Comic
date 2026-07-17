import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Logo sumber dari favicon situs dengan placeholder yang selalu stabil.
class SourceSiteIcon extends StatefulWidget {
  const SourceSiteIcon({
    super.key,
    required this.websiteUrl,
    required this.initial,
    required this.hue,
    this.size = 42,
    this.radius = 8,
  });

  final String? websiteUrl;
  final String initial;
  final int hue;
  final double size;
  final double radius;

  @override
  State<SourceSiteIcon> createState() => _SourceSiteIconState();
}

class _SourceSiteIconState extends State<SourceSiteIcon> {
  int _candidateIndex = 0;
  bool _advanceScheduled = false;

  @override
  void didUpdateWidget(SourceSiteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.websiteUrl != widget.websiteUrl) _candidateIndex = 0;
  }

  List<String> get _candidates {
    final raw = widget.websiteUrl?.trim() ?? '';
    if (raw.isEmpty) return const [];
    final normalized = raw.startsWith(RegExp(r'https?://'))
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return const [];
    final origin = uri.replace(path: '/', query: null, fragment: null);
    return <String>{
      origin.resolve('favicon.ico').toString(),
      origin.resolve('apple-touch-icon.png').toString(),
      Uri.https('www.google.com', '/s2/favicons', {
        'domain': uri.host,
        'sz': '128',
      }).toString(),
    }.toList();
  }

  void _tryNextCandidate(int candidateCount) {
    if (_advanceScheduled || _candidateIndex >= candidateCount - 1) return;
    _advanceScheduled = true;
    scheduleMicrotask(() {
      if (!mounted) return;
      setState(() {
        _candidateIndex++;
        _advanceScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: comicCover(widget.hue),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.initial.isEmpty ? '?' : widget.initial,
        style: AppTypography.jakarta(
          size: widget.size * 0.4,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );

    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: candidates.isEmpty
          ? fallback
          : Image.network(
              candidates[_candidateIndex],
              key: ValueKey(candidates[_candidateIndex]),
              fit: BoxFit.cover,
              cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) {
                _tryNextCandidate(candidates.length);
                return fallback;
              },
            ),
    );
  }
}
