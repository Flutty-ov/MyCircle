import 'dart:io';

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'tapflow/tapflow_models.dart';
import 'tapflow/tapflow_share_intent.dart';
import 'tapflow/tapflow_service.dart';

enum TapFlowMode { files, receiveSupabase, sendSupabase }

class TapFlowPage extends StatefulWidget {
  const TapFlowPage({
    super.key,
    this.initialFile,
    this.mode = TapFlowMode.files,
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.onSupabaseAccepted,
  });

  final File? initialFile;
  final TapFlowMode mode;
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final Future<void> Function(String url, String anonKey)? onSupabaseAccepted;

  @override
  State<TapFlowPage> createState() => _TapFlowPageState();
}

class _TapFlowPageState extends State<TapFlowPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wavesController;
  late final Animation<double> _t;
  late final TapFlowService _service;
  late final TapFlowShareIntent _shareIntent;

  @override
  void initState() {
    super.initState();
    _service = TapFlowService();
    _shareIntent = TapFlowShareIntent();
    _wavesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _t = CurvedAnimation(parent: _wavesController, curve: Curves.linear);

    if (widget.mode == TapFlowMode.files) {
      _shareIntent.listen(onFile: _service.startSendingFile);
      final f = widget.initialFile;
      if (f != null) {
        _service.startSendingFile(f);
      } else {
        _service.enterRadar();
      }
    } else if (widget.mode == TapFlowMode.sendSupabase) {
      final url = (widget.supabaseUrl ?? '').trim();
      final key = (widget.supabaseAnonKey ?? '').trim();
      if (url.isNotEmpty && key.isNotEmpty) {
        _service.startSendingSupabaseConfig(url: url, anonKey: key);
      } else {
        _service.enterRadar();
      }
    } else {
      _service.enterRadar();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    _shareIntent.dispose();
    _wavesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.80),
      height: 1.25,
    );

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).get('tapflow'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _service.stage,
              _service.debugText,
              _service.receivedSupabaseConfig,
            ]),
            builder: (context, _) {
              final stage = _service.stage.value;
              final incoming = _service.incomingRequest.value;
              final prog = _service.progress.value;
              final err = _service.errorText.value;
              final dbg = _service.debugText.value;
              final supa = _service.receivedSupabaseConfig.value;

              final headline = _headlineFor(context, stage);
              final subtitle = _subtitleFor(
                context,
                stage,
                incoming,
                prog,
                err,
              );

              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: RepaintBoundary(
                        child: SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _t,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: _TapFlowWavesPainter(
                                      t: _t.value,
                                      color: cs.primary,
                                    ),
                                    size: const Size(260, 260),
                                  );
                                },
                              ),
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(
                                    alpha: 0.65,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.asset(
                                      'assets/icons/TapFlow.png',
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 10),
                  Text(subtitle, textAlign: TextAlign.center, style: bodyStyle),
                  if (dbg != null && dbg.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      dbg,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (stage == TapFlowStage.incomingRequest)
                    _TapFlowIncomingCard(
                      request: incoming!,
                      onAccept: _service.acceptIncoming,
                      onDecline: _service.declineIncoming,
                    )
                  else if (stage == TapFlowStage.transferring)
                    _TapFlowProgressCard(value: prog?.ratio ?? 0.0)
                  else if (stage == TapFlowStage.completed)
                    (supa != null
                        ? _TapFlowSupabaseReceivedCard(
                            config: supa,
                            onApply: () async {
                              final cb = widget.onSupabaseAccepted;
                              if (cb != null) {
                                await cb(supa.url, supa.anonKey);
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                          )
                        : _TapFlowHintCard(
                            title: AppLocalizations.of(context).get('done'),
                            text:
                                _service.receivedFile.value?.path ??
                                AppLocalizations.of(context).get('file_saved'),
                          ))
                  else if (stage == TapFlowStage.error)
                    _TapFlowHintCard(
                      title: AppLocalizations.of(context).get('error'),
                      text:
                          err ??
                          AppLocalizations.of(context).get('transfer_failed'),
                    )
                  else
                    _TapFlowHintCard(
                      title: AppLocalizations.of(context).get('hint'),
                      text: AppLocalizations.of(
                        context,
                      ).get('tapflow_share_hint'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _headlineFor(BuildContext context, TapFlowStage stage) {
  final l10n = AppLocalizations.of(context);
  switch (stage) {
    case TapFlowStage.standby:
      return l10n.get('tapflow');
    case TapFlowStage.waitingForTap:
      return l10n.get('ready_to_receive');
    case TapFlowStage.handshake:
      return l10n.get('tap_detected');
    case TapFlowStage.incomingRequest:
      return l10n.get('transfer_request');
    case TapFlowStage.connecting:
      return l10n.get('connecting');
    case TapFlowStage.transferring:
      return l10n.get('transferring');
    case TapFlowStage.completed:
      return l10n.get('done');
    case TapFlowStage.error:
      return l10n.get('error');
  }
}

String _subtitleFor(
  BuildContext context,
  TapFlowStage stage,
  TapFlowIncomingRequest? incoming,
  TapFlowTransferProgress? prog,
  String? err,
) {
  final l10n = AppLocalizations.of(context);
  switch (stage) {
    case TapFlowStage.standby:
      return l10n.get('tapflow_standby');
    case TapFlowStage.waitingForTap:
      return l10n.get('tapflow_waiting');
    case TapFlowStage.handshake:
      return l10n.get('establishing_connection');
    case TapFlowStage.incomingRequest:
      final file = incoming?.offer.fileName ?? l10n.get('file_fallback');
      final who = incoming?.peerName ?? l10n.get('device');
      return '$who ${l10n.get('wants_to_transfer')}\n$file';
    case TapFlowStage.connecting:
      return l10n.get('connecting_to_sender');
    case TapFlowStage.transferring:
      final p = prog == null
          ? ''
          : ' ${(prog.ratio * 100).toStringAsFixed(0)}%';
      return '${l10n.get('receiving_file')}$p';
    case TapFlowStage.completed:
      return l10n.get('file_received');
    case TapFlowStage.error:
      return err ?? l10n.get('transfer_failed');
  }
}

class _TapFlowIncomingCard extends StatelessWidget {
  const _TapFlowIncomingCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final TapFlowIncomingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final offer = request.offer;
    final supa = request.supabaseConfig;
    final sizeText = offer.size <= 0 ? '' : ' • ${_bytes(context, offer.size)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supa != null
                ? AppLocalizations.of(context).get('supabase_data')
                : offer.fileName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${request.peerName ?? AppLocalizations.of(context).get('device')}$sizeText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (supa != null) ...[
            const SizedBox(height: 10),
            Text(
              supa.url,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.85),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              supa.anonKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.75),
                height: 1.2,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: Text(
                    supa != null
                        ? AppLocalizations.of(context).get('cancel')
                        : AppLocalizations.of(context).get('decline'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: Text(
                    supa != null
                        ? AppLocalizations.of(context).get('get')
                        : AppLocalizations.of(context).get('accept'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TapFlowSupabaseReceivedCard extends StatelessWidget {
  const _TapFlowSupabaseReceivedCard({
    required this.config,
    required this.onApply,
  });

  final TapFlowSupabaseConfig config;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).get('supabase_data'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            config.url,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.85),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            config.anonKey,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.75),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: onApply,
              child: Text(AppLocalizations.of(context).get('get')),
            ),
          ),
        ],
      ),
    );
  }
}

String _bytes(BuildContext context, int b) {
  final l10n = AppLocalizations.of(context);
  final units = [
    l10n.get('byte_unit_b'),
    l10n.get('byte_unit_kb'),
    l10n.get('byte_unit_mb'),
    l10n.get('byte_unit_gb'),
  ];
  double v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final s = i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$s ${units[i]}';
}

class _TapFlowHintCard extends StatelessWidget {
  const _TapFlowHintCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.78),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TapFlowProgressCard extends StatelessWidget {
  const _TapFlowProgressCard({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).get('progress'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: value.clamp(0.0, 1.0),
              backgroundColor: cs.onSurface.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapFlowWavesPainter extends CustomPainter {
  _TapFlowWavesPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.5;

    void drawRing(double base, double opacity) {
      final r = (base * maxR).clamp(0.0, maxR);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(c, r, paint);
    }

    final p1 = t;
    final p2 = (t + 0.33) % 1.0;
    final p3 = (t + 0.66) % 1.0;

    drawRing(0.38 + 0.62 * p1, (1.0 - p1) * 0.22);
    drawRing(0.38 + 0.62 * p2, (1.0 - p2) * 0.16);
    drawRing(0.38 + 0.62 * p3, (1.0 - p3) * 0.12);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
      ..color = color.withValues(alpha: 0.10);
    canvas.drawCircle(c, maxR * 0.55, glow);
  }

  @override
  bool shouldRepaint(covariant _TapFlowWavesPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color;
  }
}
