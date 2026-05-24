import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ras/cache_service.dart';
import 'package:ras/dev_notice.dart';
import 'package:ras/profile.dart';
import 'package:ras/registration_page.dart';
import 'package:ras/start_chat_page.dart';
import 'package:ras/app_scope.dart';
import 'package:ras/emoji_picker_button.dart';
import 'package:ras/settings_page.dart';
import 'package:ras/settings_search_page.dart';
import 'package:ras/mycircle_features_channel_page.dart';
import 'package:cupertino_liquid_glass/cupertino_liquid_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as img;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';
import 'notifications_service.dart';
import 'tapflow/tapflow_share_intent.dart';
import 'tapflow_page.dart';
import 'log_service.dart';
import 'chat_settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.instance.info('Приложение запускается');
  await Firebase.initializeApp();
  LogService.instance.info('Firebase инициализирован');
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final prefs = await SharedPreferences.getInstance();
  final supabaseUrl = (prefs.getString('server.supabase.url') ?? '').trim();
  final supabaseAnonKey = (prefs.getString('server.supabase.anonKey') ?? '')
      .trim();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    LogService.instance.info('Supabase инициализирован с данными пользователя');
  } else {
    LogService.instance.info(
      'Supabase не инициализирован — нет данных (пользователь не зарегистрирован)',
    );
  }

  runApp(const MyApp());
  LogService.instance.info('MyApp запущен');
}

class _CropImagePage extends StatefulWidget {
  const _CropImagePage({required this.bytes});

  final Uint8List bytes;

  @override
  State<_CropImagePage> createState() => _CropImagePageState();
}

class _CropImagePageState extends State<_CropImagePage> {
  CropController _controller = CropController();
  int _resetKey = 0;
  bool _busy = false;

  Future<void> _crop() async {
    if (_busy) return;
    setState(() => _busy = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Crop(
                key: ValueKey(_resetKey),
                controller: _controller,
                image: widget.bytes,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.55),
                cornerDotBuilder: (size, edgeAlignment) =>
                    const DotControl(color: Colors.white),
                onCropped: (bytes) {
                  if (!mounted) return;
                  Navigator.of(context).pop<Uint8List?>(bytes);
                },
                initialSize: 0.9,
                interactive: true,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop<Uint8List?>(null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : _crop,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPadding),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() => _busy = false);
                              _controller = CropController();
                              _resetKey++;
                            },
                      child: const Text(
                        'Сбросить',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const Spacer(),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageAdjustPage extends StatefulWidget {
  const _ImageAdjustPage({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImageAdjustPage> createState() => _ImageAdjustPageState();
}

class _ImageAdjustPageState extends State<_ImageAdjustPage> {
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  int _rotation = 0;
  bool _flipH = false;
  bool _flipV = false;
  bool _busy = false;

  Uint8List _applyAdjustments() {
    try {
      var decoded = img.decodeImage(widget.bytes);
      if (decoded == null) return widget.bytes;

      if (_rotation == 1) decoded = img.copyRotate(decoded, angle: 90);
      if (_rotation == 2) decoded = img.copyRotate(decoded, angle: 180);
      if (_rotation == 3) decoded = img.copyRotate(decoded, angle: 270);

      if (_flipH) decoded = img.flipHorizontal(decoded);
      if (_flipV) decoded = img.flipVertical(decoded);

      if (_brightness != 0) {
        decoded = img.adjustColor(decoded, brightness: 1.0 + _brightness);
      }
      if (_contrast != 0) {
        decoded = img.adjustColor(decoded, contrast: 1.0 + _contrast);
      }
      if (_saturation != 0) {
        decoded = img.adjustColor(decoded, saturation: 1.0 + _saturation);
      }

      return Uint8List.fromList(img.encodePng(decoded));
    } catch (_) {
      return widget.bytes;
    }
  }

  Future<void> _done() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final out = _applyAdjustments();
    if (!mounted) return;
    Navigator.of(context).pop<Uint8List?>(out);
  }

  void _reset() {
    setState(() {
      _brightness = 0;
      _contrast = 0;
      _saturation = 0;
      _rotation = 0;
      _flipH = false;
      _flipV = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.memory(_applyAdjustments(), fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop<Uint8List?>(null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      child: const Text(
                        'Сбросить',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _BottomAction(
                          icon: Icons.rotate_left,
                          onTap: () =>
                              setState(() => _rotation = (_rotation - 1) % 4),
                        ),
                        const SizedBox(width: 10),
                        _BottomAction(
                          icon: Icons.rotate_right,
                          onTap: () =>
                              setState(() => _rotation = (_rotation + 1) % 4),
                        ),
                        const SizedBox(width: 10),
                        _BottomAction(
                          icon: Icons.flip,
                          onTap: () => setState(() => _flipH = !_flipH),
                        ),
                        const SizedBox(width: 10),
                        _BottomAction(
                          icon: Icons.swap_vert,
                          onTap: () => setState(() => _flipV = !_flipV),
                        ),
                        const Spacer(),
                        if (_busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (!_busy) ...[
                          const SizedBox(width: 10),
                          Material(
                            color: cs.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _done,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(Icons.check, color: cs.onPrimary),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SliderRow(
                      label: 'Яркость',
                      value: _brightness,
                      onChanged: (v) => setState(() => _brightness = v),
                    ),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: 'Контраст',
                      value: _contrast,
                      onChanged: (v) => setState(() => _contrast = v),
                    ),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: 'Насыщенность',
                      value: _saturation,
                      onChanged: (v) => setState(() => _saturation = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: -1,
              max: 1,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

img.Image _coolFilter(img.Image image) {
  final result = img.copyResize(
    image,
    width: image.width,
    height: image.height,
  );
  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = (pixel.r.toInt() * 0.9).clamp(0, 255);
      final g = pixel.g.toInt();
      final b = (pixel.b.toInt() * 1.2).clamp(0, 255);
      result.setPixelRgba(x, y, r / 255, g / 255, b / 255, pixel.a / 255);
    }
  }
  return result;
}

img.Image _warmFilter(img.Image image) {
  final result = img.copyResize(
    image,
    width: image.width,
    height: image.height,
  );
  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = (pixel.r.toInt() * 1.15).clamp(0, 255);
      final g = pixel.g.toInt();
      final b = (pixel.b.toInt() * 0.85).clamp(0, 255);
      result.setPixelRgba(x, y, r / 255, g / 255, b / 255, pixel.a / 255);
    }
  }
  return result;
}

class _ImageFiltersPage extends StatefulWidget {
  const _ImageFiltersPage({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImageFiltersPage> createState() => _ImageFiltersPageState();
}

class _ImageFiltersPageState extends State<_ImageFiltersPage> {
  String? _selectedFilter;
  bool _busy = false;

  final List<_FilterPreset> _filters = const [
    _FilterPreset(name: 'Оригинал', filter: null),
    _FilterPreset(name: 'Ч/Б', filter: 'grayscale'),
    _FilterPreset(name: 'Сепия', filter: 'sepia'),
    _FilterPreset(name: 'Винтаж', filter: 'vintage'),
    _FilterPreset(name: 'Холодный', filter: 'cool'),
    _FilterPreset(name: 'Тёплый', filter: 'warm'),
    _FilterPreset(name: 'Инверсия', filter: 'invert'),
    _FilterPreset(name: 'Размытие', filter: 'blur'),
  ];

  Uint8List _applyFilter(String? filter) {
    try {
      final decoded = img.decodeImage(widget.bytes);
      if (decoded == null) return widget.bytes;

      img.Image result;
      switch (filter) {
        case 'grayscale':
          result = img.grayscale(decoded);
        case 'sepia':
          result = img.sepia(decoded);
        case 'vintage':
          result = img.sepia(decoded);
          result = img.adjustColor(result, contrast: 1.1);
          result = img.adjustColor(result, brightness: 0.95);
        case 'cool':
          result = _coolFilter(decoded);
        case 'warm':
          result = _warmFilter(decoded);
        case 'invert':
          result = img.invert(decoded);
        case 'blur':
          result = img.gaussianBlur(decoded, radius: 3);
        default:
          return widget.bytes;
      }
      return Uint8List.fromList(img.encodePng(result));
    } catch (_) {
      return widget.bytes;
    }
  }

  Future<void> _done() async {
    if (_busy || _selectedFilter == null) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final out = _applyFilter(_selectedFilter);
    if (!mounted) return;
    Navigator.of(context).pop<Uint8List?>(out);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.memory(
                    _applyFilter(_selectedFilter),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop<Uint8List?>(null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    if (_busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (!_busy && _selectedFilter != null) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: cs.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _done,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.check, color: cs.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomPadding),
                child: SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final f = _filters[index];
                      final selected = _selectedFilter == f.filter;
                      return _FilterChip(
                        name: f.name,
                        selected: selected,
                        onTap: () => setState(() => _selectedFilter = f.filter),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPreset {
  const _FilterPreset({required this.name, required this.filter});
  final String name;
  final String? filter;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageTextPage extends StatefulWidget {
  const _ImageTextPage({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImageTextPage> createState() => _ImageTextPageState();
}

class _ImageTextPageState extends State<_ImageTextPage> {
  final TextEditingController _textController = TextEditingController(
    text: 'Ваш текст',
  );
  double _x = 0.5;
  double _y = 0.5;
  double _fontSize = 32;
  Color _textColor = Colors.white;
  bool _showShadow = true;
  ui.Image? _baseImage;
  _ContainFit? _textFit;

  @override
  void initState() {
    super.initState();
    _decodeBase();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _decodeBase() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _baseImage = frame.image);
    } catch (_) {}
  }

  Future<void> _done() async {
    try {
      final base = _baseImage;
      if (base == null) return;
      final text = _textController.text.trim();
      if (text.isEmpty) return;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(base, Offset.zero, Paint());

      final textStyle = TextStyle(
        color: _textColor,
        fontSize: _fontSize,
        fontWeight: FontWeight.bold,
        shadows: _showShadow
            ? [
                const Shadow(
                  color: Colors.black54,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ]
            : null,
      );

      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final xPos = _x * base.width - textPainter.width / 2;
      final yPos = _y * base.height - textPainter.height / 2;

      textPainter.paint(canvas, Offset(xPos, yPos));

      final picture = recorder.endRecording();
      final imgOut = await picture.toImage(base.width, base.height);
      final byteData = await imgOut.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final out = byteData.buffer.asUint8List();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List?>(out);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить текст')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screen = constraints.biggest;
                    double? displayFontSize;
                    double textX = 0, textY = 0;
                    String txt = '';
                    if (_baseImage != null) {
                      final scaleX = screen.width / _baseImage!.width;
                      final scaleY = screen.height / _baseImage!.height;
                      final scale = scaleX < scaleY ? scaleX : scaleY;
                      final scaledW = _baseImage!.width * scale;
                      final scaledH = _baseImage!.height * scale;
                      final dx = (screen.width - scaledW) / 2;
                      final dy = (screen.height - scaledH) / 2;
                      _textFit = _ContainFit(
                        scale: scale,
                        offset: Offset(dx, dy),
                      );
                      displayFontSize = _fontSize * scale;
                      txt = _textController.text.isEmpty
                          ? 'Текст'
                          : _textController.text;
                      final tp = TextPainter(
                        text: TextSpan(
                          text: txt,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: displayFontSize,
                            fontWeight: FontWeight.bold,
                            shadows: _showShadow
                                ? [
                                    const Shadow(
                                      color: Colors.black54,
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        textDirection: TextDirection.ltr,
                      );
                      tp.layout();
                      textX = dx + _x * scale * _baseImage!.width - tp.width / 2;
                      textY = dy + _y * scale * _baseImage!.height - tp.height / 2;
                    }
                    return GestureDetector(
                      onPanStart: (_) {},
                      onPanUpdate: (details) {
                        if (_textFit == null || _baseImage == null) return;
                        final local = details.localPosition;
                        final imgPoint =
                            (local - _textFit!.offset) / _textFit!.scale;
                        setState(() {
                          _x = (imgPoint.dx / _baseImage!.width).clamp(0.0, 1.0);
                          _y = (imgPoint.dy / _baseImage!.height).clamp(0.0, 1.0);
                        });
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Center(
                              child: Image.memory(
                                widget.bytes,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (_textFit != null && displayFontSize != null)
                            Positioned(
                              left: textX,
                              top: textY,
                              child: IgnorePointer(
                                child: Text(
                                  txt,
                                  textScaler: const TextScaler.linear(1.0),
                                  style: TextStyle(
                                    color: _textColor,
                                    fontSize: displayFontSize,
                                    fontWeight: FontWeight.bold,
                                    shadows: _showShadow
                                        ? [
                                            const Shadow(
                                              color: Colors.black54,
                                              offset: Offset(2, 2),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop<Uint8List?>(null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    Material(
                      color: cs.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _done,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.check, color: cs.onPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Введите текст…',
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Размер',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: Slider(
                              value: _fontSize,
                              min: 12,
                              max: 80,
                              divisions: 34,
                              onChanged: (v) => setState(() => _fontSize = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Цвет',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        _ColorDot(
                          color: Colors.white,
                          selected: _textColor == Colors.white,
                          onTap: () =>
                              setState(() => _textColor = Colors.white),
                        ),
                        const SizedBox(width: 8),
                        _ColorDot(
                          color: Colors.redAccent,
                          selected: _textColor == Colors.redAccent,
                          onTap: () =>
                              setState(() => _textColor = Colors.redAccent),
                        ),
                        const SizedBox(width: 8),
                        _ColorDot(
                          color: Colors.yellowAccent,
                          selected: _textColor == Colors.yellowAccent,
                          onTap: () =>
                              setState(() => _textColor = Colors.yellowAccent),
                        ),
                        const SizedBox(width: 8),
                        _ColorDot(
                          color: Colors.black,
                          selected: _textColor == Colors.black,
                          onTap: () =>
                              setState(() => _textColor = Colors.black),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Text(
                              'Тень',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Switch(
                              value: _showShadow,
                              onChanged: (v) => setState(() => _showShadow = v),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContainFit {
  const _ContainFit({required this.scale, required this.offset});

  final double scale;
  final Offset offset;
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _StrokePreset extends StatelessWidget {
  const _StrokePreset({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 36,
          child: Center(
            child: Container(
              width: width,
              height: width,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityAction extends StatelessWidget {
  const _QualityAction({required this.hd, required this.onTap});

  final bool hd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: Text(
              hd ? 'HD' : 'SD',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageDrawPage extends StatefulWidget {
  const _ImageDrawPage({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImageDrawPage> createState() => _ImageDrawPageState();
}

class _ImageDrawPageState extends State<_ImageDrawPage> {
  final List<_Stroke> _strokes = <_Stroke>[];
  _Stroke? _current;
  Color _color = Colors.redAccent;
  double _width = 6;
  bool _isEraser = false;
  ui.Image? _baseImage;

  Size? get _imageSize => _baseImage == null
      ? null
      : Size(_baseImage!.width.toDouble(), _baseImage!.height.toDouble());

  void _eraseAt(Offset imagePoint) {
    final eraserRadius = _width * 3 / 2;
    _strokes.removeWhere((stroke) {
      return stroke.points.any((p) => (p - imagePoint).distance < eraserRadius);
    });
  }

  @override
  void initState() {
    super.initState();
    _decodeBase();
  }

  Future<void> _decodeBase() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _baseImage = frame.image);
    } catch (_) {
      // ignore; drawing will still show preview but can't export.
    }
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() => setState(() => _strokes.clear());

  Future<void> _done() async {
    try {
      final base = _baseImage;
      if (base == null) return;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(base, Offset.zero, Paint());

      for (final stroke in _strokes) {
        if (stroke.points.length < 2) continue;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = stroke.color
          ..strokeWidth = stroke.width;

        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (final p in stroke.points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }

      final picture = recorder.endRecording();
      final imgOut = await picture.toImage(base.width, base.height);
      final byteData = await imgOut.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final out = byteData.buffer.asUint8List();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List?>(out);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось применить рисунок')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final imgSize = _imageSize;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _DrawSurface(
                bytes: widget.bytes,
                imageSize: imgSize,
                strokes: _strokes,
                isEraser: _isEraser,
                onErase: _isEraser ? (p) => setState(() => _eraseAt(p)) : null,
                onStart: (p) {
                  setState(() {
                    _current = _Stroke(
                      points: <Offset>[p],
                      color: _color,
                      width: _width,
                    );
                    _strokes.add(_current!);
                  });
                },
                onMove: (p) {
                  final c = _current;
                  if (c == null) return;
                  setState(() => c.points.add(p));
                },
                onEnd: () => _current = null,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop<Uint8List?>(null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clear,
                      child: const Text(
                        'Очистить всё',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomPadding),
                child: Row(
                  children: [
                    _BottomAction(icon: Icons.undo, onTap: _undo),
                    const SizedBox(width: 10),
                    _BottomAction(
                      icon: _isEraser ? Icons.brush : Icons.auto_fix_high,
                      onTap: () => setState(() => _isEraser = !_isEraser),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (!_isEraser) ...[
                              _StrokePreset(
                                width: 4,
                                selected: _width == 4,
                                onTap: () => setState(() => _width = 4),
                              ),
                              const SizedBox(width: 8),
                              _StrokePreset(
                                width: 7,
                                selected: _width == 7,
                                onTap: () => setState(() => _width = 7),
                              ),
                              const SizedBox(width: 8),
                              _StrokePreset(
                                width: 11,
                                selected: _width == 11,
                                onTap: () => setState(() => _width = 11),
                              ),
                              const SizedBox(width: 12),
                              _ColorDot(
                                color: Colors.white,
                                selected: _color == Colors.white,
                                onTap: () =>
                                    setState(() => _color = Colors.white),
                              ),
                              const SizedBox(width: 8),
                              _ColorDot(
                                color: Colors.redAccent,
                                selected: _color == Colors.redAccent,
                                onTap: () =>
                                    setState(() => _color = Colors.redAccent),
                              ),
                              const SizedBox(width: 8),
                              _ColorDot(
                                color: Colors.greenAccent,
                                selected: _color == Colors.greenAccent,
                                onTap: () =>
                                    setState(() => _color = Colors.greenAccent),
                              ),
                              const SizedBox(width: 8),
                              _ColorDot(
                                color: Colors.blueAccent,
                                selected: _color == Colors.blueAccent,
                                onTap: () =>
                                    setState(() => _color = Colors.blueAccent),
                              ),
                              const SizedBox(width: 8),
                              _ColorDot(
                                color: Colors.yellowAccent,
                                selected: _color == Colors.yellowAccent,
                                onTap: () => setState(
                                  () => _color = Colors.yellowAccent,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Ластик',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _done,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawSurface extends StatelessWidget {
  const _DrawSurface({
    required this.bytes,
    required this.imageSize,
    required this.strokes,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
    this.isEraser = false,
    this.onErase,
  });

  final Uint8List bytes;
  final Size? imageSize;
  final List<_Stroke> strokes;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;
  final bool isEraser;
  final ValueChanged<Offset>? onErase;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        final fit = _containFit(box, imageSize);
        return GestureDetector(
          onPanStart: (d) {
            final imgPoint = _mapToImage(fit, d.localPosition);
            if (isEraser) {
              onErase?.call(imgPoint);
            } else {
              onStart(imgPoint);
            }
          },
          onPanUpdate: (d) {
            final imgPoint = _mapToImage(fit, d.localPosition);
            if (isEraser) {
              onErase?.call(imgPoint);
            } else {
              onMove(imgPoint);
            }
          },
          onPanEnd: (_) => onEnd(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              CustomPaint(
                painter: _StrokesPainter(fit: fit, strokes: strokes),
              ),
            ],
          ),
        );
      },
    );
  }

  _ContainFit _containFit(Size box, Size? imageSize) {
    if (imageSize == null || imageSize.width <= 0 || imageSize.height <= 0) {
      return const _ContainFit(scale: 1, offset: Offset.zero);
    }
    final scale = (box.width / imageSize.width < box.height / imageSize.height)
        ? box.width / imageSize.width
        : box.height / imageSize.height;
    final render = Size(imageSize.width * scale, imageSize.height * scale);
    final offset = Offset(
      (box.width - render.width) / 2,
      (box.height - render.height) / 2,
    );
    return _ContainFit(scale: scale, offset: offset);
  }

  Offset _mapToImage(_ContainFit fit, Offset p) {
    if (fit.scale <= 0) return p;
    return (p - fit.offset) / fit.scale;
  }
}

class _StrokesPainter extends CustomPainter {
  const _StrokesPainter({required this.fit, required this.strokes});

  final _ContainFit fit;
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale, fit.scale);

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = stroke.color
        ..strokeWidth = stroke.width;

      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.fit != fit;
  }
}

class _Stroke {
  _Stroke({required this.points, required this.color, required this.width});

  final List<Offset> points;
  final Color color;
  final double width;
}

class _GalleryPickerSheet extends StatefulWidget {
  const _GalleryPickerSheet({required this.onPick});

  final Future<void> Function(AssetEntity entity) onPick;

  @override
  State<_GalleryPickerSheet> createState() => _GalleryPickerSheetState();
}

class _GalleryPickerSheetState extends State<_GalleryPickerSheet> {
  final _controller = ScrollController();
  final _assets = <AssetEntity>[];
  AssetPathEntity? _mainPath;
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  static const _pageSize = 120;

  Future<Uint8List?> _thumb(AssetEntity e) {
    return e.thumbnailDataWithSize(
      const ThumbnailSize.square(256),
      quality: 80,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 600) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _page = 0;
      _assets.clear();
      _mainPath = null;
    });

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(needTitle: true),
        videoOption: const FilterOption(needTitle: true),
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (!mounted) return;
    _mainPath = () {
      for (final p in paths) {
        if (p.isAll) return p;
      }
      return paths.isNotEmpty ? paths.first : null;
    }();
    await _loadMore();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final mainPath = _mainPath;
    if (mainPath == null) return;

    setState(() {
      _loadingMore = true;
    });

    final next = <AssetEntity>[];
    try {
      final items = await mainPath.getAssetListPaged(
        page: _page,
        size: _pageSize,
      );
      if (items.isNotEmpty) next.addAll(items);
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _page += 1;
      _assets.addAll(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_assets.isEmpty) {
      return Center(
        child: Text(
          'Нет медиа',
          style: TextStyle(color: cs.onSurface.withValues(alpha:0.7)),
        ),
      );
    }

    return GridView.builder(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(2, 40, 2, 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _assets.length + (_loadingMore ? 6 : 0),
      itemBuilder: (context, index) {
        if (index >= _assets.length) {
          return DecoratedBox(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest),
          );
        }

        final entity = _assets[index];
        return InkWell(
          onTap: () => widget.onPick(entity),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: _thumb(entity),
                builder: (context, snap) {
                  final bytes = snap.data;
                  if (bytes != null) {
                    return Image.memory(bytes, fit: BoxFit.cover);
                  }
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                    ),
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                },
              ),
              if (entity.type == AssetType.video)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha:0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(
                        Icons.videocam,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CachedMediaSquare extends StatefulWidget {
  const _CachedMediaSquare({required this.url, required this.isSticker});

  final String url;
  final bool isSticker;

  @override
  State<_CachedMediaSquare> createState() => _CachedMediaSquareState();
}

class _CachedMediaSquareState extends State<_CachedMediaSquare> {
  Future<File?>? _future;
  bool _forceDownload = false;

  @override
  void initState() {
    super.initState();
    _kick();
  }

  @override
  void didUpdateWidget(covariant _CachedMediaSquare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _forceDownload = false;
      _kick();
    }
  }

  void _kick() {
    _future = () async {
      final u = widget.url.trim();
      if (u.startsWith('file://')) {
        final path = Uri.tryParse(u)?.toFilePath();
        if (path != null) {
          final f = File(path);
          if (await f.exists()) return f;
        }
      }
      if (!u.contains('://')) {
        final f = File(u);
        if (await f.exists()) return f;
      }
      final cached = await CacheService.instance.getFileFromCache(
        widget.url,
        category: widget.isSticker
            ? CacheCategory.sticker
            : CacheCategory.photo,
      );
      if (cached != null) return cached;
      final allowAuto = await CacheService.instance.shouldAutoDownload();
      return CacheService.instance.getOrDownloadFile(
        widget.url,
        allowDownload: allowAuto || _forceDownload,
        forceDownload: _forceDownload,
        category: widget.isSticker
            ? CacheCategory.sticker
            : CacheCategory.photo,
      );
    }();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Image.file(file, fit: BoxFit.cover);
        }
        return ColoredBox(
          color: cs.surfaceContainerHighest,
          child: Center(
            child: snap.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isSticker ? 'Стикер' : 'Медиа',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _forceDownload = true;
                            _kick();
                          });
                        },
                        child: const Text('Загрузить'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _CachedStickerThumb extends StatefulWidget {
  const _CachedStickerThumb({required this.url});

  final String url;

  @override
  State<_CachedStickerThumb> createState() => _CachedStickerThumbState();
}

class _CachedStickerThumbState extends State<_CachedStickerThumb> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = () async {
      final allow = await CacheService.instance.shouldAutoDownload();
      return CacheService.instance.getOrDownloadFile(
        widget.url,
        allowDownload: allow,
        forceDownload: false,
        category: CacheCategory.sticker,
      );
    }();
  }

  @override
  void didUpdateWidget(covariant _CachedStickerThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = () async {
        final allow = await CacheService.instance.shouldAutoDownload();
        return CacheService.instance.getOrDownloadFile(
          widget.url,
          allowDownload: allow,
          forceDownload: false,
          category: CacheCategory.sticker,
        );
      }();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Image.file(file, fit: BoxFit.cover);
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: Color(0x11000000),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return const ColoredBox(color: Color(0x11000000));
      },
    );
  }
}

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final TapFlowShareIntent _shareIntent = TapFlowShareIntent();
  bool _shareListening = false;
  AppController? _controller;
  Timer? _inactivityTimer;
  bool _lockScreenShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startShareListening();
  }

  void _startShareListening() {
    if (_shareListening) return;
    _shareListening = true;
    _shareIntent.listen(
      onFile: (file) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = _appNavigatorKey.currentState;
          if (nav == null) return;
          nav.push(
            MaterialPageRoute(builder: (_) => TapFlowPage(initialFile: file)),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _shareIntent.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (ctrl.hasPasscode && ctrl.passcodeAutoLockSeconds > 0) {
        ctrl.setPasscodeLocked(true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (ctrl.hasPasscode && ctrl.passcodeLocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLockScreen();
        });
      }
    }
  }

  void _onUserActivity() {
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    final ctrl = _controller;
    if (ctrl == null || !ctrl.hasPasscode || ctrl.passcodeLocked) return;

    final seconds = ctrl.passcodeAutoLockSeconds;
    if (seconds <= 0) return;

    _inactivityTimer = Timer(Duration(seconds: seconds), () {
      final ctrl = _controller;
      if (ctrl == null || !ctrl.hasPasscode || ctrl.passcodeLocked) return;

      if (ctrl.inChatPage) return;

      ctrl.setPasscodeLocked(true);
      _showLockScreen();
    });
  }

  void _showLockScreen() {
    if (_lockScreenShowing) return;
    final nav = _appNavigatorKey.currentState;
    if (nav == null) return;
    _lockScreenShowing = true;

    nav.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PasscodeUnlockPage(),
        fullscreenDialog: true,
      ),
    ).then((unlocked) {
      _lockScreenShowing = false;
      final ctrl = _controller;
      if (unlocked == true) {
        _onUserActivity();
      } else if (ctrl != null && ctrl.hasPasscode && ctrl.passcodeLocked) {
        _showLockScreen();
      }
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        if (prefs == null) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.white,
              body: SizedBox.expand(),
            ),
          );
        }

        final controller = AppController(prefs);
        _controller = controller;

        NotificationsService.instance.init(
          enabled: controller.notificationsEnabled,
        );
        NotificationsService.instance.setCharacterToken(
          controller.characterToken,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onUserActivity();
        });

        return Listener(
          onPointerDown: (_) => _onUserActivity(),
          onPointerMove: (_) => _onUserActivity(),
          onPointerUp: (_) => _onUserActivity(),
          child: AppScope(
            controller: controller,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
              ColorScheme buildScheme(Brightness brightness) {
                final base = ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: brightness,
                );
                final primary = controller.seedColor;
                final onPrimary =
                    ThemeData.estimateBrightnessForColor(primary) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black;
                return base.copyWith(primary: primary, onPrimary: onPrimary);
              }

              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'RAS',
                navigatorKey: _appNavigatorKey,
                navigatorObservers: [_LogNavigatorObserver()],
                themeMode: controller.themeMode,
                theme: ThemeData(
                  colorScheme: buildScheme(Brightness.light),
                  useMaterial3: true,
                ),
                darkTheme: ThemeData(
                  colorScheme: buildScheme(Brightness.dark),
                  useMaterial3: true,
                ),
                home: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: controller.onboardingCompleted
                      ? const MainHomePage(key: ValueKey('home'))
                      : const RegistrationPage(key: ValueKey('onboarding')),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}


class _LogNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final routeName = route.settings.name ?? route.runtimeType.toString();
    LogService.instance.nav('Push: $routeName');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final routeName = route.settings.name ?? route.runtimeType.toString();
    LogService.instance.nav('Pop: $routeName');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final newName = newRoute?.settings.name ?? newRoute?.runtimeType.toString();
    final oldName = oldRoute?.settings.name ?? oldRoute?.runtimeType.toString();
    LogService.instance.nav('Replace: $oldName -> $newName');
  }
}

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  final Set<String> _selectedChatUuids = <String>{};
  int _messengerNavIndex = 0;
  bool _devNoticeCheckScheduled = false;

  bool get _selectionMode => _selectedChatUuids.isNotEmpty;

  void _openStartChat(BuildContext context) {
    LogService.instance.tap('Открытие списка чатов');
    final app = AppScope.of(context);
    final channels = app.addedChats
        .where((e) {
          final name = (e['chatName'] ?? '').toString().trim().toLowerCase();
          if (name.isEmpty) return true;
          return !name.contains('избран');
        })
        .toList(growable: false);

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => StartChatPage(
          channels: channels,
          onOpenChat: (context, row) {
            final chatUuid = (row['chatUuid'] ?? '').toString();
            final chatId = (row['chatId'] ?? '').toString();
            final name = (row['chatName'] ?? '').toString();
            final fallback = name.isEmpty
                ? (chatId.isEmpty ? 'Чат' : chatId)
                : name;
            final app = AppScope.of(context);
            final title = app.getChatDisplayName(
              chatUuid: chatUuid,
              fallback: fallback,
            );
            LogService.instance.chat('Открытие чата: $title (uuid: $chatUuid)');

            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ChatPage(
                  chatUuid: chatUuid,
                  chatId: chatId,
                  chatName: title,
                ),
              ),
            );
          },
        ),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  void _openNotes(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotesChatPage()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void _openProfile(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));
  }

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowDevNotice();
    });
  }

  Future<void> _maybeShowDevNotice() async {
    if (_devNoticeCheckScheduled) return;
    _devNoticeCheckScheduled = true;

    final controller = AppScope.of(context);
    if (!controller.onboardingCompleted) return;
    if (controller.devNoticeShown) return;

    await showDevNoticeDialog(context);
    if (!mounted) return;
    await controller.setDevNoticeShown(true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    controller.ensureCharacterSynced();
    final messengerNavEnabled = controller.messengerNavEnabled;

    final query = _query.trim().toLowerCase();
    final cs = Theme.of(context).colorScheme;

    Widget searchField(BuildContext context) {
      return TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textAlign: TextAlign.center,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Поиск чатов',
          suffixIcon: _searchFocus.hasFocus
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                    _searchFocus.unfocus();
                  },
                )
              : Icon(Icons.search, color: cs.onSurface.withValues(alpha:0.55)),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: messengerNavEnabled,
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: messengerNavEnabled
          ? null
          : Drawer(
              child: SafeArea(
                child: MainMenu(
                  onProfileTap: () {
                    Navigator.of(context).pop();
                    _openProfile(context);
                  },
                  onNotesTap: () {
                    Navigator.of(context).pop();
                    _openNotes(context);
                  },
                  onSettingsTap: () {
                    Navigator.of(context).pop();
                    _openSettings(context);
                  },
                  themeMode: controller.themeMode,
                  onThemeChanged: (isDark) {
                    controller.setThemeMode(
                      isDark ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
              ),
            ),
      body: SafeArea(
        bottom: !messengerNavEnabled,
        child: messengerNavEnabled && _messengerNavIndex == 2
            ? const SettingsPage(embedded: true)
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) {
                          final fade = CurvedAnimation(
                            parent: anim,
                            curve: Curves.ease,
                          );
                          return FadeTransition(
                            opacity: fade,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -0.05),
                                end: Offset.zero,
                              ).animate(fade),
                              child: child,
                            ),
                          );
                        },
                        child: !_selectionMode
                            ? Row(
                                key: const ValueKey('topbar-normal'),
                                children: [
                                  if (!messengerNavEnabled)
                                    Builder(
                                      builder: (context) {
                                        return IconButton(
                                          icon: const Icon(Icons.menu),
                                          onPressed: () =>
                                              Scaffold.of(context).openDrawer(),
                                        );
                                      },
                                    )
                                  else
                                    const SizedBox(width: 48),
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: Center(
                                        child: Text(
                                          'Чаты',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                ],
                              )
                            : Row(
                                key: const ValueKey('topbar-selection'),
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(
                                        () => _selectedChatUuids.clear(),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedChatUuids.length.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.download_outlined),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      if (_selectedChatUuids.isEmpty) return;
                                      final count = _selectedChatUuids.length;
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text(
                                              'Удалить чат${count == 1 ? '' : 'ы'}',
                                            ),
                                            content: Text(
                                              count == 1
                                                  ? 'Убрать чат из списка на устройстве?'
                                                  : 'Убрать $count чатов из списка на устройстве?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: const Text('Отмена'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: const Text('Удалить'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (ok != true) return;

                                      await controller.removeChats(
                                        _selectedChatUuids,
                                      );
                                      if (!mounted) return;
                                      setState(
                                        () => _selectedChatUuids.clear(),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 10),
                      searchField(context),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Builder(
                            builder: (context) {
                              final tc = DefaultTabController.of(context);
                              return AnimatedBuilder(
                                animation: tc.animation ?? tc,
                                builder: (context, _) {
                                  final index = tc.index;
                                  final t =
                                      tc.animation?.value ?? index.toDouble();
                                  final bg = cs.surfaceContainerHighest;
                                  final thumb =
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? cs.onSurface.withValues(alpha:0.20)
                                      : cs.surface;

                                  return ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 190,
                                      maxWidth: 260,
                                    ),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragUpdate: (d) {
                                        final box = context.findRenderObject();
                                        if (box is! RenderBox) return;
                                        final local = box.globalToLocal(
                                          d.globalPosition,
                                        );
                                        final newIndex =
                                            local.dx < (box.size.width / 2)
                                            ? 0
                                            : 1;
                                        if (newIndex == tc.index) return;
                                        tc.animateTo(
                                          newIndex,
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          curve: Curves.easeOut,
                                        );
                                      },
                                      child: Container(
                                        height: 40,
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: bg,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, seg) {
                                            final w = seg.maxWidth / 2;
                                            return Stack(
                                              children: [
                                                Positioned(
                                                  left: t * w,
                                                  top: 0,
                                                  width: w,
                                                  height: seg.maxHeight,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: thumb,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                        onTap: () =>
                                                            tc.animateTo(0),
                                                        child: Center(
                                                          child: Text(
                                                            'Все',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelLarge
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: t < 0.5
                                                                      ? cs.onSurface
                                                                      : cs.onSurface
                                                                            .withValues(alpha:
                                                                              0.65,
                                                                            ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                        onTap: () =>
                                                            tc.animateTo(1),
                                                        child: Center(
                                                          child: Text(
                                                            'Каналы',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelLarge
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      t >= 0.5
                                                                      ? cs.onSurface
                                                                      : cs.onSurface
                                                                            .withValues(alpha:
                                                                              0.65,
                                                                            ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: TabBarView(
                          physics: const PageScrollPhysics(),
                          children: [
                            ListView(
                              children: [
                                if (query.isEmpty || 'заметки'.contains(query))
                                  ListTile(
                                    leading: Transform.translate(
                                      offset: const Offset(-12, 0),
                                      child: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/icons/zametki_logo.png',
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Transform.translate(
                                      offset: const Offset(-15, 0),
                                      child: const Text(
                                        'Заметки',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    onTap: () => _openNotes(context),
                                  ),
                                _SupabaseChatsSection(
                                  query: query,
                                  selectedChatUuids: _selectedChatUuids,
                                  selectionMode: _selectionMode,
                                  onToggleSelected: (chatUuid) {
                                    setState(() {
                                      if (_selectedChatUuids.contains(
                                        chatUuid,
                                      )) {
                                        _selectedChatUuids.remove(chatUuid);
                                      } else {
                                        _selectedChatUuids.add(chatUuid);
                                      }
                                    });
                                  },
                                  onEnterSelection: (chatUuid) {
                                    setState(() {
                                      _selectedChatUuids.add(chatUuid);
                                    });
                                  },
                                ),
                              ],
                            ),
                            ListView(
                              children: [
                                if (controller.myCircleChannelSubscribed)
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    leading: ClipOval(
                                      child: Image.asset(
                                        'assets/icons/MyCircle.png',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    title: const Text('MyCircle'),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const MyCircleFeaturesChannelPage(),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: messengerNavEnabled
          ? _MessengerTelegramBottomBar(
              currentIndex: _messengerNavIndex,
              onTap: (i) {
                if (i == 0) {
                  setState(() => _messengerNavIndex = 0);
                  return;
                }

                setState(() => _messengerNavIndex = i);
                if (i == 2) return;
                Future<void>? nav;
                switch (i) {
                  case 1:
                    nav = Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotesChatPage(),
                      ),
                    );
                    break;
                  case 2:
                    nav = Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                    break;
                }

                nav?.whenComplete(() {
                  if (!mounted) return;
                  setState(() => _messengerNavIndex = 0);
                });
              },
              items: const [
                _MessengerTelegramBottomBarItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Чаты',
                ),
                _MessengerTelegramBottomBarItem(
                  icon: Icons.note_alt_outlined,
                  label: 'Заметки',
                ),
                _MessengerTelegramBottomBarItem(
                  icon: Icons.menu,
                  label: 'Настройки',
                ),
              ],
              onSearchTap: () {
                if (_messengerNavIndex == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsSearchPage(),
                    ),
                  );
                  return;
                }
                _openStartChat(context);
              },
            )
          : null,
    );
  }
}

class _MessengerTelegramBottomBarItem {
  const _MessengerTelegramBottomBarItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _MessengerTelegramBottomBar extends StatefulWidget {
  const _MessengerTelegramBottomBar({
    required this.currentIndex,
    required this.onTap,
    this.onSearchTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onSearchTap;
  final List<_MessengerTelegramBottomBarItem> items;

  @override
  State<_MessengerTelegramBottomBar> createState() =>
      _MessengerTelegramBottomBarState();
}

class _LensShaderPainter extends CustomPainter {
  const _LensShaderPainter({
    required this.image,
    required this.program,
    required this.refraction,
    required this.blurMix,
    required this.edgeFeather,
    required this.time,
    required this.radius,
    required this.originInBar,
    required this.barSize,
    required this.flipY,
    required this.isDark,
  });

  final ui.Image image;
  final ui.FragmentProgram program;
  final double refraction;
  final double blurMix;
  final double edgeFeather;
  final double time;
  final double radius;
  final ui.Offset originInBar;
  final ui.Size barSize;
  final bool flipY;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, refraction);
    shader.setFloat(4, blurMix);
    shader.setFloat(5, edgeFeather);
    shader.setFloat(6, originInBar.dx);
    shader.setFloat(7, originInBar.dy);
    shader.setFloat(8, barSize.width);
    shader.setFloat(9, barSize.height);
    shader.setFloat(10, radius);
    shader.setFloat(11, flipY ? 1.0 : 0.0);
    shader.setFloat(12, isDark ? 1.0 : 0.0);
    shader.setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LensShaderPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.program != program ||
      oldDelegate.refraction != refraction ||
      oldDelegate.blurMix != blurMix ||
      oldDelegate.edgeFeather != edgeFeather ||
      oldDelegate.time != time ||
      oldDelegate.radius != radius ||
      oldDelegate.originInBar != originInBar ||
      oldDelegate.barSize != barSize;
}

class _MessengerTelegramBottomBarState
    extends State<_MessengerTelegramBottomBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapAnimController;
  int? _dragIndex;
  double? _dragPillLeft;
  double? _dragGrabDx;
  double? _dragStartX;
  bool _dragMoved = false;
  bool _tapAnimating = false;
  int? _tapTargetIndex;
  double? _tapAnimStartLeft;
  bool _searchPressed = false;
  Offset _searchDragOffset = Offset.zero;
  bool _menuDragActive = false;
  final GlobalKey _barRepaintKey = GlobalKey();
  ui.Image? _barSnapshot;
  ui.FragmentProgram? _lensProgram;
  Timer? _snapshotDebounce;
  bool _snapshotInFlight = false;
  bool _wasCovered = false;

  @override
  void initState() {
    super.initState();
    _tapAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadLensShader();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSnapshot());
  }

  @override
  void didUpdateWidget(covariant _MessengerTelegramBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _tapAnimController.stop();
      _tapAnimController.removeStatusListener(_tapStatusListener);
      setState(() {
        _menuDragActive = false;
        _dragIndex = null;
        _dragPillLeft = null;
        _dragGrabDx = null;
        _dragStartX = null;
        _dragMoved = false;
        _tapAnimating = false;
        _tapTargetIndex = null;
        _tapAnimStartLeft = null;
        _searchPressed = false;
        _searchDragOffset = Offset.zero;
      });
      _scheduleSnapshot();
    }
  }

  @override
  void dispose() {
    _snapshotDebounce?.cancel();
    _barSnapshot?.dispose();
    _tapAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadLensShader() async {
    try {
      final p = await ui.FragmentProgram.fromAsset('assets/shaders/lens.frag');
      if (!mounted) return;
      setState(() => _lensProgram = p);
    } catch (_) {
      // If shader compilation fails, we keep the existing glass rendering.
    }
  }

  void _scheduleSnapshot() {
    if (_snapshotInFlight) return;
    _snapshotDebounce?.cancel();
    _snapshotDebounce = Timer(const Duration(milliseconds: 24), () async {
      if (!mounted) return;
      final boundary =
          _barRepaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      _snapshotInFlight = true;
      try {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final image = await boundary.toImage(pixelRatio: dpr);
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _barSnapshot?.dispose();
          _barSnapshot = image;
        });
      } finally {
        _snapshotInFlight = false;
      }
    });
  }

  void _tapStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      final targetIndex = _tapTargetIndex;
      if (!mounted || targetIndex == null) return;
      setState(() {
        _tapAnimating = false;
        _tapTargetIndex = null;
        _tapAnimStartLeft = null;
        _dragIndex = null;
        _dragPillLeft = null;
      });
      _tapAnimController.removeStatusListener(_tapStatusListener);
      widget.onTap(targetIndex);
      _scheduleSnapshot();
    }
  }

  int _indexFromPillCenter({
    required double centerX,
    required double itemWidth,
    required int itemCount,
  }) {
    final i = ((centerX / itemWidth).floor()).clamp(0, itemCount - 1);
    return i;
  }

  Widget _buildGlassPill({
    required bool isDark,
    required double radius,
    required double blurSigma,
    required double tintOpacity,
    required Color edgeLightColor,
    required bool bubbleMode,
    required bool flipY,
    bool showHalo = true,
    ui.Offset? originInBar,
    ui.Size? barSize,
  }) {
    final program = _lensProgram;
    final snapshot = _barSnapshot;
    final useLens =
        program != null &&
        snapshot != null &&
        originInBar != null &&
        barSize != null;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (bubbleMode && showHalo)
          Transform.scale(
            scale: 1.12,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: isDark
                      ? const Color(0x10FFFFFF)
                      : const Color(0x14FFFFFF),
                ),
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (useLens)
                CustomPaint(
                  painter: _LensShaderPainter(
                    image: snapshot,
                    program: program,
                    time: DateTime.now().microsecondsSinceEpoch / 1e6,
                    refraction: bubbleMode ? 0.045 : 0.0,
                    blurMix: bubbleMode ? 0.9 : 0.75,
                    edgeFeather: 1.0,
                    radius: radius,
                    originInBar: originInBar,
                    barSize: barSize,
                    flipY: flipY,
                    isDark: isDark,
                  ),
                )
              else
                CupertinoLiquidGlass(
                  theme: isDark
                      ? LiquidGlassThemeData.dark()
                      : LiquidGlassThemeData.light(),
                  blurSigma: blurSigma,
                  tintOpacity: tintOpacity,
                  borderRadius: BorderRadius.circular(radius),
                  edgeLightColor: edgeLightColor,
                  child: const SizedBox.expand(),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x22FFFFFF)
                        : const Color(0x16000000),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? const [Color(0x1AFFFFFF), Color(0x06FFFFFF)]
                        : const [Color(0x14FFFFFF), Color(0x05FFFFFF)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isCurrent = (ModalRoute.of(context)?.isCurrent ?? true);
      if (_wasCovered && isCurrent) {
        setState(() {
          _menuDragActive = false;
          _dragIndex = null;
          _dragPillLeft = null;
          _dragGrabDx = null;
          _dragStartX = null;
          _dragMoved = false;
          _searchPressed = false;
          _searchDragOffset = Offset.zero;
        });
        _scheduleSnapshot();
      }
      _wasCovered = !isCurrent;
    });

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lensFlipY = app.messengerNavLensFlipY;

    // Keep the bar visually transparent, but NOT fully transparent.
    // A fully transparent BackdropFilter + clip can produce dark "seams"/lines
    // near high-contrast content (text/icons) due to how the blur is composed.
    // A tiny tint keeps the glass effect while removing the artifact.
    final border = isDark
        ? cs.outlineVariant.withValues(alpha:0.22)
        : cs.outlineVariant.withValues(alpha:0.30);

    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontSize: 11, height: 1.1);

    final selectedIndex = _tapTargetIndex ?? _dragIndex ?? widget.currentIndex;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 8, 6, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const barHeight = 68.0;
            const searchSize = barHeight;
            const gap = 10.0;
            final totalAvailable = constraints.maxWidth - searchSize - gap;
            final menuWidth = (totalAvailable * 0.85).clamp(
              0.0,
              double.infinity,
            );
            final menuOffset = (totalAvailable - menuWidth) / 2;
            final itemCount = widget.items.length;
            final itemWidth = menuWidth / itemCount;

            final selectedLabel = widget.items[selectedIndex].label;
            final basePillWidth = 58.0;
            final targetPillWidth = selectedLabel.length >= 9
                ? 74.0
                : basePillWidth;
            final pillWidth = targetPillWidth.clamp(
              0.0,
              (itemWidth - 4).clamp(0.0, double.infinity),
            );
            final pillHeight = 56.0;
            const itemBoxHeight = 38.0;
            final snappedPillLeft =
                (itemWidth * widget.currentIndex) + (itemWidth - pillWidth) / 2;

            double computedBaseLeft = snappedPillLeft;
            if (_dragPillLeft != null) {
              computedBaseLeft = _dragPillLeft!;
            } else if (_tapAnimating &&
                _tapAnimStartLeft != null &&
                _tapTargetIndex != null) {
              final targetLeft =
                  (itemWidth * _tapTargetIndex!) + (itemWidth - pillWidth) / 2;
              final curveT = Curves.easeOutCubic.transform(
                _tapAnimController.value,
              );
              computedBaseLeft =
                  _tapAnimStartLeft! +
                  (targetLeft - _tapAnimStartLeft!) * curveT;
            }

            final baseLeft = computedBaseLeft;
            const pillTop = 6.0;
            final maxPillLeft = (menuWidth - pillWidth).clamp(
              0.0,
              double.infinity,
            );

            final baseCenterX = baseLeft + (pillWidth / 2);
            final frac =
                (baseCenterX / itemWidth) -
                (baseCenterX / itemWidth).floorToDouble();
            final distToCenter = ((frac - 0.5).abs() * 2).clamp(0.0, 1.0);
            final bubbleT = (_dragPillLeft != null || _tapAnimating)
                ? Curves.easeOutCubic.transform(distToCenter)
                : 0.0;

            final visualWidth = pillWidth + (itemWidth * 0.70 * bubbleT);
            final visualHeight = pillHeight + (10.0 * bubbleT);
            final visualRadius = 22.0 + (18.0 * bubbleT);
            final visualBlurSigma = 44.0 + (10.0 * bubbleT);
            final visualTintOpacity = (isDark ? 0.20 : 0.14) + (0.05 * bubbleT);
            final visualEdgeLight = isDark
                ? Color.lerp(
                    const Color(0x70FFFFFF),
                    const Color(0xB0FFFFFF),
                    bubbleT,
                  )!
                : Color.lerp(
                    const Color(0x55FFFFFF),
                    const Color(0x90FFFFFF),
                    bubbleT,
                  )!;

            final maxVisualLeft = (menuWidth - visualWidth).clamp(
              0.0,
              double.infinity,
            );
            final visualLeft = (baseCenterX - (visualWidth / 2)).clamp(
              0.0,
              maxVisualLeft,
            );

            return SizedBox(
              height: barHeight,
              child: Stack(
                children: [
                  // Snapshot layer: whole bar (menu + search) WITHOUT lens overlays.
                  RepaintBoundary(
                    key: _barRepaintKey,
                    child: Row(
                      children: [
                        SizedBox(width: menuOffset),
                        SizedBox(
                          width: menuWidth,
                          height: barHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CupertinoLiquidGlass(
                                  theme: isDark
                                      ? LiquidGlassThemeData.dark()
                                      : LiquidGlassThemeData.light(),
                                  blurSigma: 44,
                                  tintOpacity: isDark ? 0.20 : 0.14,
                                  borderRadius: BorderRadius.circular(26),
                                  edgeLightColor: isDark
                                      ? const Color(0x70FFFFFF)
                                      : const Color(0x55FFFFFF),
                                  child: const SizedBox.expand(),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(color: border),
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Row(
                                      children: [
                                        for (var i = 0; i < itemCount; i++)
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => widget.onTap(i),
                                              splashFactory:
                                                  NoSplash.splashFactory,
                                              overlayColor:
                                                  const WidgetStatePropertyAll<
                                                    Color
                                                  >(Colors.transparent),
                                              highlightColor:
                                                  Colors.transparent,
                                              splashColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                    ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    SizedBox(
                                                      width: pillWidth,
                                                      height: itemBoxHeight,
                                                      child: Icon(
                                                        widget.items[i].icon,
                                                        size: 24,
                                                        color:
                                                            i == selectedIndex
                                                            ? cs.primary
                                                            : cs.onSurface
                                                                  .withValues(alpha:
                                                                    0.90,
                                                                  ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      widget.items[i].label,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: labelStyle?.copyWith(
                                                        color:
                                                            i == selectedIndex
                                                            ? cs.primary
                                                            : cs.onSurface
                                                                  .withValues(alpha:
                                                                    0.85,
                                                                  ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Gesture area for dragging menu only.
                  Positioned(
                    left: menuOffset,
                    top: 0,
                    width: menuWidth,
                    height: barHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        if (_tapAnimating) return;

                        final box =
                            _barRepaintKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        final local = box?.globalToLocal(
                          details.globalPosition,
                        );
                        if (local == null) return;

                        final tappedIndex = _indexFromPillCenter(
                          centerX: local.dx,
                          itemWidth: itemWidth,
                          itemCount: itemCount,
                        );

                        // If tapping a different item, trigger bubble animation
                        if (tappedIndex != widget.currentIndex) {
                          setState(() {
                            _tapAnimating = true;
                            _tapTargetIndex = tappedIndex;
                            _tapAnimStartLeft = snappedPillLeft;
                            _dragIndex = widget.currentIndex;
                            _dragPillLeft = snappedPillLeft;
                            _dragMoved = true;
                          });
                          _scheduleSnapshot();

                          _tapAnimController.forward(from: 0.0);
                          _tapAnimController.addListener(() {
                            if (mounted) setState(() {});
                          });
                          _tapAnimController.addStatusListener(
                            _tapStatusListener,
                          );
                          return;
                        }

                        final startIndex = _indexFromPillCenter(
                          centerX: local.dx,
                          itemWidth: itemWidth,
                          itemCount: itemCount,
                        );
                        final isOnCurrent =
                            startIndex == widget.currentIndex &&
                            local.dx >= snappedPillLeft &&
                            local.dx <= (snappedPillLeft + pillWidth);
                        if (!isOnCurrent) {
                          setState(() {
                            _menuDragActive = false;
                          });
                          return;
                        }

                        final grabDx = (local.dx - snappedPillLeft).clamp(
                          0.0,
                          pillWidth,
                        );

                        setState(() {
                          _menuDragActive = true;
                          _dragIndex = widget.currentIndex;
                          _dragPillLeft = snappedPillLeft;
                          _dragGrabDx = grabDx;
                          _dragStartX = local.dx;
                          _dragMoved = false;
                        });
                        _scheduleSnapshot();
                      },
                      onPanUpdate: (details) {
                        if (!_menuDragActive) return;
                        final box =
                            _barRepaintKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        final local = box?.globalToLocal(
                          details.globalPosition,
                        );
                        if (local == null) return;

                        final startX = _dragStartX;
                        if (!_dragMoved && startX != null) {
                          if ((local.dx - startX).abs() > 2.0) {
                            setState(() => _dragMoved = true);
                          }
                        }

                        final grabDx = (_dragGrabDx ?? (pillWidth / 2)).clamp(
                          0.0,
                          pillWidth,
                        );
                        final desiredLeft = (local.dx - grabDx).clamp(
                          0.0,
                          maxPillLeft,
                        );
                        final centerX = desiredLeft + (pillWidth / 2);
                        final i = _indexFromPillCenter(
                          centerX: centerX,
                          itemWidth: itemWidth,
                          itemCount: itemCount,
                        );

                        setState(() {
                          _dragPillLeft = desiredLeft;
                          _dragIndex = i;
                        });
                        _scheduleSnapshot();
                      },
                      onPanEnd: (_) {
                        final i = _dragIndex;
                        final moved = _dragMoved;
                        setState(() {
                          _menuDragActive = false;
                          _dragIndex = null;
                          _dragPillLeft = null;
                          _dragGrabDx = null;
                          _dragStartX = null;
                          _dragMoved = false;
                        });
                        _scheduleSnapshot();
                        if (moved && i != null && i != widget.currentIndex) {
                          widget.onTap(i);
                        }
                      },
                      onPanCancel: () => setState(() {
                        _menuDragActive = false;
                        _dragIndex = null;
                        _dragPillLeft = null;
                        _dragGrabDx = null;
                        _dragStartX = null;
                        _dragMoved = false;
                      }),
                    ),
                  ),

                  // Lens pill overlay.
                  if (_dragPillLeft != null || _tapAnimating)
                    Positioned(
                      left: menuOffset + visualLeft,
                      top: pillTop,
                      width: visualWidth,
                      height: visualHeight,
                      child: IgnorePointer(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildGlassPill(
                              isDark: isDark,
                              radius: visualRadius,
                              blurSigma: visualBlurSigma,
                              tintOpacity: visualTintOpacity,
                              edgeLightColor: visualEdgeLight,
                              bubbleMode: _dragMoved || _tapAnimating,
                              flipY: lensFlipY,
                              originInBar: ui.Offset(
                                menuOffset + visualLeft,
                                pillTop,
                              ),
                              barSize: ui.Size(constraints.maxWidth, barHeight),
                            ),
                            if (!_dragMoved && !_tapAnimating)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.items[selectedIndex].icon,
                                      size: 24,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.items[selectedIndex].label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: labelStyle?.copyWith(
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      left: menuOffset + baseLeft,
                      top: pillTop,
                      width: pillWidth,
                      height: pillHeight,
                      child: IgnorePointer(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildGlassPill(
                              isDark: isDark,
                              radius: 22,
                              blurSigma: 44,
                              tintOpacity: isDark ? 0.20 : 0.08,
                              edgeLightColor: isDark
                                  ? const Color(0x70FFFFFF)
                                  : const Color(0x88FFFFFF),
                              bubbleMode: false,
                              flipY: lensFlipY,
                              originInBar: ui.Offset(
                                menuOffset + baseLeft,
                                pillTop,
                              ),
                              barSize: ui.Size(constraints.maxWidth, barHeight),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.items[selectedIndex].icon,
                                    size: 24,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.items[selectedIndex].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: labelStyle?.copyWith(
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search button gesture + press animation.
                  Positioned(
                    right: 0,
                    top: 0,
                    width: searchSize,
                    height: barHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onSearchTap,
                      onTapDown: (_) => setState(() => _searchPressed = true),
                      onTapUp: (_) => setState(() => _searchPressed = false),
                      onTapCancel: () => setState(() => _searchPressed = false),
                      onLongPressStart: (_) =>
                          setState(() => _searchPressed = true),
                      onLongPressEnd: (_) =>
                          setState(() => _searchPressed = false),
                      onPanStart: (_) => setState(() => _searchPressed = true),
                      onPanUpdate: (details) {
                        const maxDrag = 10.0;
                        final next = Offset(
                          (_searchDragOffset.dx + details.delta.dx).clamp(
                            -maxDrag,
                            maxDrag,
                          ),
                          (_searchDragOffset.dy + details.delta.dy).clamp(
                            -maxDrag,
                            maxDrag,
                          ),
                        );
                        setState(() => _searchDragOffset = next);
                      },
                      onPanEnd: (_) => setState(() {
                        _searchPressed = false;
                        _searchDragOffset = Offset.zero;
                      }),
                      onPanCancel: () => setState(() {
                        _searchPressed = false;
                        _searchDragOffset = Offset.zero;
                      }),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        scale: _searchPressed ? 0.94 : 1.0,
                        child: Builder(
                          builder: (context) {
                            const maxDrag = 14.0;
                            final dxT = (_searchDragOffset.dx.abs() / maxDrag)
                                .clamp(0.0, 1.0);
                            final dyT = (_searchDragOffset.dy.abs() / maxDrag)
                                .clamp(0.0, 1.0);

                            final stretchX = 1.0 + (dxT * 0.18);
                            final stretchY = 1.0 + (dyT * 0.18);

                            final ax = _searchDragOffset.dx == 0
                                ? 0.0
                                : -_searchDragOffset.dx.sign;
                            final ay = _searchDragOffset.dy == 0
                                ? 0.0
                                : -_searchDragOffset.dy.sign;
                            final stretchAlignment = Alignment(ax, ay);

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              transform: Matrix4.diagonal3Values(stretchX, stretchY, 1.0),
                              transformAlignment: stretchAlignment,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  searchSize / 2,
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CupertinoLiquidGlass(
                                      theme: isDark
                                          ? LiquidGlassThemeData.dark()
                                          : LiquidGlassThemeData.light(),
                                      blurSigma: 44,
                                      tintOpacity: isDark ? 0.20 : 0.14,
                                      borderRadius: BorderRadius.circular(
                                        searchSize / 2,
                                      ),
                                      edgeLightColor: isDark
                                          ? const Color(0x70FFFFFF)
                                          : const Color(0x55FFFFFF),
                                      child: const SizedBox.expand(),
                                    ),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          searchSize / 2,
                                        ),
                                        border: Border.all(color: border),
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                    Center(
                                      child: Icon(
                                        Icons.search,
                                        size: 26,
                                        color: cs.onSurface.withValues(alpha:0.92),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({
    required this.onProfileTap,
    required this.onNotesTap,
    required this.onSettingsTap,
    required this.themeMode,
    required this.onThemeChanged,
    super.key,
  });

  final VoidCallback onProfileTap;
  final VoidCallback onNotesTap;
  final VoidCallback onSettingsTap;
  final ThemeMode themeMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    final updateLinkFuture = Supabase.instance.client
        .from('new_version_app')
        .select('link')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'RAS',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Redundant Access Server',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Я'),
                onTap: onProfileTap,
              ),
              ListTile(
                leading: Transform.translate(
                  offset: const Offset(-8, 0),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icons/zametki_logo.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                title: Transform.translate(
                  offset: const Offset(-10, 0),
                  child: const Text('Заметки', style: TextStyle(fontSize: 18)),
                ),
                onTap: onNotesTap,
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Настройки'),
                onTap: onSettingsTap,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        FutureBuilder<Map<String, dynamic>?>(
          future: updateLinkFuture,
          builder: (context, snapshot) {
            final row = snapshot.data;
            final link = (row?['link'] ?? '').toString().trim();
            if (link.isEmpty) return const SizedBox.shrink();

            return ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text('Обновить'),
              onTap: () async {
                final uri = Uri.tryParse(link);
                if (uri == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Некорректная ссылка')),
                  );
                  return;
                }

                final ok = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!ok) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Не удалось открыть ссылку')),
                  );
                }
              },
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SwitchListTile(
            value: isDark,
            onChanged: onThemeChanged,
            secondary: const Icon(Icons.nights_stay),
            title: const Text('Тёмный режим'),
          ),
        ),
      ],
    );
  }
}

class _SupabaseChatsSection extends StatelessWidget {
  const _SupabaseChatsSection({
    required this.query,
    required this.selectedChatUuids,
    required this.selectionMode,
    required this.onToggleSelected,
    required this.onEnterSelection,
  });

  final String query;
  final Set<String> selectedChatUuids;
  final bool selectionMode;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<String> onEnterSelection;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final data = app.addedChats.where((row) {
          if (query.isEmpty) return true;
          final chatId = (row['chatId'] ?? '').toString().toLowerCase();
          final chatName = (row['chatName'] ?? '').toString().toLowerCase();
          final chatUuid = (row['chatUuid'] ?? '').toString();
          final displayName = app
              .getChatDisplayName(
                chatUuid: chatUuid,
                fallback: row['chatName'] ?? '',
              )
              .toLowerCase();
          return chatId.contains(query) ||
              chatName.contains(query) ||
              displayName.contains(query);
        }).toList();
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            ...data.map((row) {
              final chatUuid = (row['chatUuid'] ?? '').toString();
              final chatId = (row['chatId'] ?? '').toString();
              final name = (row['chatName'] ?? '').toString();
              final selected =
                  chatUuid.isNotEmpty && selectedChatUuids.contains(chatUuid);
              final fallback = name.isEmpty
                  ? (chatId.isEmpty ? 'Чат' : chatId)
                  : name;
              final title = AppScope.of(
                context,
              ).getChatDisplayName(chatUuid: chatUuid, fallback: fallback);

              void openChat() {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatPage(
                      chatUuid: chatUuid,
                      chatId: chatId,
                      chatName: title,
                    ),
                  ),
                );
              }

              void toggle() {
                if (chatUuid.isEmpty) return;
                onToggleSelected(chatUuid);
              }

              void enterSelection() {
                if (chatUuid.isEmpty) return;
                onEnterSelection(chatUuid);
              }

              Timer? holdTimer;

              void startHoldTimer() {
                if (chatUuid.isEmpty) return;
                holdTimer?.cancel();
                holdTimer = Timer(const Duration(milliseconds: 350), () {
                  enterSelection();
                });
              }

              void cancelHoldTimer() {
                holdTimer?.cancel();
                holdTimer = null;
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => startHoldTimer(),
                onTapUp: (_) => cancelHoldTimer(),
                onTapCancel: cancelHoldTimer,
                onSecondaryTap: enterSelection,
                onLongPress: () {
                  cancelHoldTimer();
                  enterSelection();
                },
                onTap: () {
                  cancelHoldTimer();
                  if (chatUuid.isEmpty) return;
                  if (selectionMode) {
                    toggle();
                    return;
                  }
                  openChat();
                },
                child: ListTile(
                  leading: selected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : Transform.translate(
                          offset: const Offset(-12, 0),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icons/chat_standart_icon.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                  title: Transform.translate(
                    offset: const Offset(-15, 0),
                    child: Text(title, style: const TextStyle(fontSize: 18)),
                  ),
                  selected: selected,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _E2ee {
  static final _algo = AesGcm.with256bits();

  static Future<String> encrypt({
    required String chatToken,
    required Map<String, dynamic> payload,
  }) async {
    final keyBytes = await Sha256().hash(utf8.encode(chatToken));
    final secretKey = SecretKey(keyBytes.bytes);
    final nonce = _algo.newNonce();
    final clearText = utf8.encode(jsonEncode(payload));
    final secretBox = await _algo.encrypt(
      clearText,
      secretKey: secretKey,
      nonce: nonce,
    );
    return jsonEncode({
      'v': 1,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  static Future<Map<String, dynamic>> decrypt({
    required String chatToken,
    required String encrypted,
  }) async {
    final obj = jsonDecode(encrypted) as Map<String, dynamic>;
    final nonce = base64Decode(obj['nonce'] as String);
    final cipherText = base64Decode(obj['ciphertext'] as String);
    final macBytes = base64Decode(obj['mac'] as String);
    final keyBytes = await Sha256().hash(utf8.encode(chatToken));
    final secretKey = SecretKey(keyBytes.bytes);
    final clear = await _algo.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: secretKey,
    );
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    required this.chatUuid,
    required this.chatId,
    required this.chatName,
    super.key,
  });

  final String chatUuid;
  final String chatId;
  final String chatName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  bool _composerFocused = false;
  int _lastRowCount = 0;
  final List<_OptimisticChatMessage> _optimistic = <_OptimisticChatMessage>[];
  bool _scrollScheduled = false;
  bool _userNearBottom = true;
  bool _userScrolling = false;
  bool _sending = false;
  final GlobalKey _composerKey = GlobalKey();
  double _composerHeight = 0;

  bool _showJumpToBottom = false;

  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _loadingCached = true;
  List<Map<String, dynamic>> _cachedRows = const <Map<String, dynamic>>[];

  String? _editingMessageId;
  String? _replyToMessageId;
  String _replyToSenderName = '';
  String _replyToText = '';

  final Map<String, Future<Map<String, dynamic>>> _decryptFutureByCiphertext =
      <String, Future<Map<String, dynamic>>>{};

  String _friendlyNetworkText(Object? error) {
    final s = (error ?? '').toString().toLowerCase();
    if (s.contains('socketexception') ||
        s.contains('connection') ||
        s.contains('failed host lookup') ||
        s.contains('network')) {
      return 'Подключение к сети отсутствует или плохая связь. Проверьте свою сеть';
    }
    return 'Ошибка загрузки сообщений';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _composerFocusNode.addListener(_onComposerFocusChanged);

    NotificationsService.instance.setActiveChatUuid(widget.chatUuid);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppScope.of(context).setInChatPage(true);
      }
    });

    _initConnectivityAndCache();
  }

  void _onComposerFocusChanged() {
    final next = _composerFocusNode.hasFocus;
    if (next == _composerFocused) return;
    if (!mounted) return;
    setState(() => _composerFocused = next);
  }

  String get _chatCacheKey => 'chat_cache:${widget.chatUuid}';

  Future<void> _initConnectivityAndCache() async {
    try {
      final res = await Connectivity().checkConnectivity();
      if (!mounted) return;
      setState(() {
        _online = !res.contains(ConnectivityResult.none);
      });
    } catch (_) {}

    await _loadCachedRows();

    _connectivitySub = Connectivity().onConnectivityChanged.listen((res) {
      if (!mounted) return;
      final nextOnline = !res.contains(ConnectivityResult.none);
      if (nextOnline == _online) return;
      setState(() {
        _online = nextOnline;
      });
    });
  }

  Future<void> _loadCachedRows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatCacheKey);
      if (raw == null || raw.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cachedRows = const <Map<String, dynamic>>[];
          _loadingCached = false;
        });
        return;
      }
      final decoded = jsonDecode(raw);
      final list = <Map<String, dynamic>>[];
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _cachedRows = list;
        _loadingCached = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cachedRows = const <Map<String, dynamic>>[];
        _loadingCached = false;
      });
    }
  }

  Future<void> _saveRowsToCache(List<Map<String, dynamic>> rows) async {
    try {
      final trimmed = rows.length > 500 ? rows.sublist(0, 500) : rows;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatCacheKey, jsonEncode(trimmed));
      if (!mounted) return;
      _cachedRows = trimmed;
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _connectivitySub?.cancel();
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _composerFocusNode.dispose();

    NotificationsService.instance.setActiveChatUuid(null);

    try {
      AppScope.of(context).setInChatPage(false);
    } catch (_) {}

    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions) return;
    final near = pos.pixels <= (pos.minScrollExtent + 24);
    _userNearBottom = near;

    final shouldShow = !near;
    if (shouldShow != _showJumpToBottom && mounted) {
      setState(() {
        _showJumpToBottom = shouldShow;
      });
    }
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToSenderName = '';
      _replyToText = '';
    });
  }

  Future<void> _copyMessage({
    required String text,
    required String? imageUrl,
  }) async {
    final value = (imageUrl != null && imageUrl.trim().isNotEmpty)
        ? imageUrl.trim()
        : text;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Скопировано')));
  }

  Future<void> _confirmAndDelete(String messageId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить сообщение'),
          content: const Text('Вы точно хотите удалить это сообщение?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось удалить: $e')));
    }
  }

  Future<void> _showMessageActions({
    required Offset tapPosition,
    required String messageId,
    required String text,
    required String? imageUrl,
    required String senderName,
    required bool isMe,
    required bool canEdit,
  }) async {
    final screen = MediaQuery.of(context).size;
    const menuWidth = 186.0;
    const menuHeight = 52.0;
    final left = (tapPosition.dx - (menuWidth / 2)).clamp(
      12.0,
      screen.width - 12 - menuWidth,
    );
    final top = (tapPosition.dy - (menuHeight / 2)).clamp(
      12.0,
      screen.height - 12 - menuHeight,
    );

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'actions',
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, _) {
        final cs = Theme.of(context).colorScheme;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: StatefulBuilder(
                  builder: (context, setSheetState) {
                    Widget shell({required Widget child}) {
                      return DecoratedBox(
                        decoration: ShapeDecoration(
                          color: cs.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: cs.onSurface.withValues(alpha:0.08),
                            ),
                          ),
                          shadows: const [
                            BoxShadow(
                              blurRadius: 18,
                              offset: Offset(0, 10),
                              color: Color(0x33000000),
                            ),
                          ],
                        ),
                        child: child,
                      );
                    }

                    Widget iconButton(String action, IconData icon) {
                      return IconButton(
                        onPressed: () => Navigator.of(context).pop(action),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(icon, size: 20),
                      );
                    }

                    return shell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            iconButton('reply', Icons.reply),
                            if (isMe)
                              iconButton('delete', Icons.delete_outline),
                            iconButton('copy', Icons.content_copy),
                            if (isMe)
                              IconButton(
                                onPressed: canEdit
                                    ? () => Navigator.of(context).pop('edit')
                                    : null,
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(36, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    switch (action) {
      case 'reply':
        setState(() {
          _replyToMessageId = messageId;
          final s = senderName.trim();
          _replyToSenderName = s.isNotEmpty ? s : (isMe ? 'Вы' : 'Собеседник');
          final t = text.trim();
          if (t.isNotEmpty) {
            _replyToText = t;
          } else if ((imageUrl ?? '').trim().isNotEmpty) {
            _replyToText = 'Фото';
          } else {
            _replyToText = 'Сообщение';
          }
        });
        break;
      case 'delete':
        if (!isMe) return;
        await _confirmAndDelete(messageId);
        break;
      case 'copy':
        await _copyMessage(text: text, imageUrl: imageUrl);
        break;
      case 'edit':
        if (!isMe || !canEdit) return;
        setState(() {
          _editingMessageId = messageId;
          _controller.text = text;
          _controller.selection = TextSelection.collapsed(offset: text.length);
        });
        break;
    }
  }

  void _scheduleScrollToBottom({required bool animated}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (!pos.hasContentDimensions) {
        _scheduleScrollToBottom(animated: animated);
        return;
      }
      final target = pos.minScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _send(BuildContext context) async {
    if (_sending) return;
    _sending = true;
    try {
      final app = AppScope.of(context);
      final token = app.getChatToken(
        chatUuid: widget.chatUuid,
        legacyChatId: widget.chatId,
      );
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала добавьте чат через «Добавить чат»'),
          ),
        );
        return;
      }

      final text = _controller.text.trim();
      if (text.isEmpty) {
        return;
      }
      LogService.instance.chat(
        'Отправка в Supabase: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}"',
      );
      _controller.clear();

      final replyId = _replyToMessageId;
      final replyName = _replyToSenderName;
      final replyText = _replyToText;
      if (replyId != null) {
        _cancelReply();
      }

      final editingId = _editingMessageId;
      final isEditing = editingId != null;
      if (isEditing) {
        _cancelEditing();
      }

      final localId = const Uuid().v4();

      final encrypted = await _E2ee.encrypt(
        chatToken: token,
        payload: {
          'sender_token': app.characterToken,
          'sender_name': (app.displayName ?? '').toString(),
          'text': text,
          'ts': DateTime.now().toIso8601String(),
          'reply_to_id': ?replyId,
          if (replyId != null) 'reply_to_name': replyName,
          if (replyId != null) 'reply_to_text': replyText,
        },
      );

      _OptimisticChatMessage? optimistic;
      if (!isEditing) {
        optimistic = _OptimisticChatMessage(
          localId: localId,
          ciphertext: encrypted,
          senderToken: app.characterToken,
          senderName: (app.displayName ?? '').toString(),
          text: text,
          replyToName: replyId == null ? null : replyName,
          replyToText: replyId == null ? null : replyText,
        );
        setState(() {
          _optimistic.add(optimistic!);
        });
        if (_userNearBottom && !_userScrolling) {
          _scheduleScrollToBottom(animated: true);
        }
      }

      if (isEditing) {
        await Supabase.instance.client
            .from('messages')
            .update({'ciphertext': encrypted})
            .eq('id', editingId)
            .timeout(const Duration(seconds: 12));
      } else {
        await Supabase.instance.client
            .from('messages')
            .insert({
              'id': localId,
              'chat_id': widget.chatUuid,
              'ciphertext': encrypted,
              'sender_token': app.characterToken,
            })
            .timeout(const Duration(seconds: 12));
      }
    } catch (e) {
      LogService.instance.error('Ошибка отправки сообщения: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить сообщение: $e')),
      );
    } finally {
      _sending = false;
    }
  }

  Future<void> _captureAndSendImage(BuildContext context) async {
    await _pickAndSendImageFromSource(context, ImageSource.camera);
  }

  Future<void> _sendImageBytes(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required String caption,
  }) async {
    final app = AppScope.of(context);
    final token = app.getChatToken(
      chatUuid: widget.chatUuid,
      legacyChatId: widget.chatId,
    );
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте чат через «Добавить чат»'),
        ),
      );
      return;
    }

    final base64Content = base64Encode(bytes);
    final localId = const Uuid().v4();

    final optimistic = _OptimisticChatMessage(
      localId: localId,
      ciphertext: null,
      senderToken: app.characterToken,
      senderName: (app.displayName ?? '').toString(),
      text: caption,
      imageUrl: null,
    );

    setState(() {
      _optimistic.add(optimistic);
    });
    if (_userNearBottom && !_userScrolling) {
      _scheduleScrollToBottom(animated: true);
    }

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'super-responder',
        body: {'file_name': fileName, 'content_base64': base64Content},
      );
      final rawUrl = (res.data?['raw_url'] ?? '').toString();
      if (rawUrl.isEmpty) {
        throw Exception('Edge Function не вернула raw_url');
      }

      setState(() {
        optimistic.imageUrl = rawUrl;
      });

      final encrypted = await _E2ee.encrypt(
        chatToken: token,
        payload: {
          'sender_token': app.characterToken,
          'sender_name': (app.displayName ?? '').toString(),
          'text': caption,
          'ts': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        optimistic.ciphertext = encrypted;
      });

      await Supabase.instance.client.from('messages').insert({
        'id': localId,
        'chat_id': widget.chatUuid,
        'ciphertext': encrypted,
        'sender_token': app.characterToken,
        'image_url': rawUrl,
      });
    } catch (_) {
      if (!context.mounted) return;
      setState(() {
        _optimistic.remove(optimistic);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить файл')),
      );
    }
  }

  Future<void> _openMediaPreviewAndSend({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final draft = await Navigator.of(context).push<_MediaDraft?>(
      MaterialPageRoute<_MediaDraft?>(
        builder: (_) =>
            _MediaSendPage(chatTitle: widget.chatName, bytes: bytes),
      ),
    );
    if (draft == null) return;
    if (!mounted) return;
    await _sendImageBytes(
      context,
      bytes: draft.bytes,
      fileName: fileName,
      caption: draft.caption,
    );
  }

  Future<void> _sendAssetEntity(
    BuildContext context,
    AssetEntity entity,
  ) async {
    final app = AppScope.of(context);
    final token = app.getChatToken(
      chatUuid: widget.chatUuid,
      legacyChatId: widget.chatId,
    );
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте чат через «Добавить чат»'),
        ),
      );
      return;
    }

    final file = await entity.file;
    if (file == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть файл из галереи')),
      );
      return;
    }

    final bytes = await file.readAsBytes();
    final ext = entity.type == AssetType.video ? 'mp4' : 'jpg';
    final fileName =
        'media_${DateTime.now().millisecondsSinceEpoch}.${ext.toLowerCase()}';
    await _openMediaPreviewAndSend(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
    );
  }

  Future<void> _openTelegramAttachSheet(BuildContext context) async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет доступа к галерее')));
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final height = MediaQuery.of(sheetContext).size.height;
        return SizedBox(
          height: height * 0.55,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: Center(
                  child: SizedBox(
                    width: 42,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x33000000),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                child: _GalleryPickerSheet(
                  onPick: (entity) async {
                    Navigator.of(sheetContext).pop();
                    await _sendAssetEntity(context, entity);
                  },
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: Material(
                  color: cs.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _captureAndSendImage(context);
                    },
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.photo_camera, color: cs.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImageFromSource(
    BuildContext context,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    final fileName = xfile.name.isNotEmpty
        ? xfile.name
        : 'image_${DateTime.now().millisecondsSinceEpoch}.png';
    await _openMediaPreviewAndSend(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
    );
  }

  Future<void> _sendSticker(BuildContext context, String stickerUrl) async {
    final app = AppScope.of(context);
    final token = app.getChatToken(
      chatUuid: widget.chatUuid,
      legacyChatId: widget.chatId,
    );
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте чат через «Добавить чат»'),
        ),
      );
      return;
    }

    final localId = const Uuid().v4();

    final optimistic = _OptimisticChatMessage(
      localId: localId,
      ciphertext: null,
      senderToken: app.characterToken,
      senderName: (app.displayName ?? '').toString(),
      text: '',
      imageUrl: stickerUrl,
      isSticker: true,
    );

    setState(() {
      _optimistic.add(optimistic);
    });
    if (_userNearBottom && !_userScrolling) {
      _scheduleScrollToBottom(animated: true);
    }

    try {
      final encrypted = await _E2ee.encrypt(
        chatToken: token,
        payload: {
          'sender_token': app.characterToken,
          'sender_name': (app.displayName ?? '').toString(),
          'text': '',
          'ts': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        optimistic.ciphertext = encrypted;
      });

      await Supabase.instance.client
          .from('messages')
          .insert({
            'id': localId,
            'chat_id': widget.chatUuid,
            'ciphertext': encrypted,
            'sender_token': app.characterToken,
            'sticker_url': stickerUrl,
          })
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      if (!context.mounted) return;
      setState(() {
        _optimistic.remove(optimistic);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить стикер')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final token = app.getChatToken(
      chatUuid: widget.chatUuid,
      legacyChatId: widget.chatId,
    );
    final wallpaper = app.chatWallpaper;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayBg = isDark ? Colors.black : Colors.white;
    final overlayFg = isDark ? Colors.white : Colors.black;
    final baseBg = Theme.of(context).colorScheme.surface;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
      final h = box?.hasSize == true ? box!.size.height : 0.0;
      if ((h - _composerHeight).abs() > 1) {
        setState(() => _composerHeight = h);
      }
    });

    return Scaffold(
      floatingActionButton: _showJumpToBottom
          ? FloatingActionButton.small(
              onPressed: () {
                _scheduleScrollToBottom(animated: true);
              },
              child: const Icon(Icons.arrow_downward),
            )
          : null,
      extendBodyBehindAppBar: wallpaper != null,
      backgroundColor: wallpaper != null ? Colors.transparent : baseBg,
      appBar: AppBar(
        leading: wallpaper != null
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: overlayBg,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: overlayFg),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatInfoPage(
                  chatUuid: widget.chatUuid,
                  chatId: widget.chatId,
                  chatName: widget.chatName,
                ),
              ),
            );
          },
          child: Builder(
            builder: (ctx) {
              final app = AppScope.of(ctx);
              final displayName = app.getChatDisplayName(
                chatUuid: widget.chatUuid,
                fallback: widget.chatName,
              );
              return wallpaper != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: overlayBg,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: overlayFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Text(displayName);
            },
          ),
        ),
        backgroundColor: wallpaper != null ? Colors.transparent : null,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (wallpaper != null)
            Image.asset(wallpaper, fit: BoxFit.cover)
          else
            ColoredBox(color: baseBg),
          Positioned.fill(
            child: !_online
                ? (_loadingCached
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                          builder: (context) {
                            return _buildMessageList(
                              context,
                              rows: _cachedRows,
                              token: token,
                              app: app,
                            );
                          },
                        ))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('messages')
                        .stream(primaryKey: ['id'])
                        .eq('chat_id', widget.chatUuid)
                        .order('created_at', ascending: false),
                    builder: (context, snapshot) {
                      final rawRows =
                          snapshot.data ?? const <Map<String, dynamic>>[];
                      final rows = _dedupeServerRows(rawRows);
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _friendlyNetworkText(snapshot.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (rawRows.isNotEmpty) {
                        unawaited(_saveRowsToCache(rows));
                      }

                      return _buildMessageList(
                        context,
                        rows: rows,
                        token: token,
                        app: app,
                      );
                    },
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ChatComposer(
              key: _composerKey,
              controller: _controller,
              focusNode: _composerFocusNode,
              onSend: () => _send(context),
              advancedComposerEnabled: app.advancedComposerEnabled,
              iosInputPanelEnabled: app.iosInputPanelEnabled,
              headerTitle: _editingMessageId != null
                  ? 'Редактирование'
                  : (_replyToMessageId != null ? _replyToSenderName : null),
              headerSubtitle: _editingMessageId != null
                  ? null
                  : (_replyToMessageId != null ? _replyToText : null),
              headerIcon: _editingMessageId != null ? Icons.edit : Icons.reply,
              onCloseHeader: _editingMessageId != null
                  ? _cancelEditing
                  : _cancelReply,
              onAttach: () => _openTelegramAttachSheet(context),
              onCamera: () => _captureAndSendImage(context),
              onSendSticker: (url) => _sendSticker(context, url),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _dedupeServerRows(
    List<Map<String, dynamic>> rawRows,
  ) {
    final rows = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    final seenServerImages = <String>{};
    for (final r in rawRows) {
      final id = (r['id'] ?? '').toString();
      if (id.isNotEmpty) {
        if (seenIds.contains(id)) continue;
        seenIds.add(id);
      }

      final sender = (r['sender_token'] ?? '').toString();
      final imageUrl = (r['image_url'] ?? '').toString().trim();
      if (sender.isNotEmpty && imageUrl.isNotEmpty) {
        final k = '$sender|$imageUrl';
        if (seenServerImages.contains(k)) continue;
        seenServerImages.add(k);
      }

      rows.add(r);
    }
    return rows;
  }

  Widget _buildMessageList(
    BuildContext context, {
    required List<Map<String, dynamic>> rows,
    required String? token,
    required AppController app,
  }) {
    final serverIds = rows
        .map((e) => (e['id'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet();

    final serverCiphertexts = rows
        .map((e) => (e['ciphertext'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet();

    final serverImageKeys = rows
        .map((e) {
          final sender = (e['sender_token'] ?? '').toString();
          final url = (e['image_url'] ?? '').toString().trim();
          if (sender.isEmpty || url.isEmpty) return '';
          return '$sender|$url';
        })
        .where((e) => e.isNotEmpty)
        .toSet();

    final optimisticById = <String, _OptimisticChatMessage>{
      for (final m in _optimistic)
        if (m.localId.isNotEmpty) m.localId: m,
    };

    final optimisticByCiphertext = <String, _OptimisticChatMessage>{
      for (final m in _optimistic)
        if ((m.ciphertext ?? '').isNotEmpty) (m.ciphertext ?? ''): m,
    };

    final optimistic = _optimistic.where((m) {
      if (m.localId.isNotEmpty && serverIds.contains(m.localId)) {
        return false;
      }

      final img = (m.imageUrl ?? '').toString().trim();
      if (img.isNotEmpty) {
        final key = '${m.senderToken}|$img';
        if (serverImageKeys.contains(key)) {
          return false;
        }
      }

      final c = m.ciphertext ?? '';
      if (c.isEmpty) return true;
      return !serverCiphertexts.contains(c);
    }).toList();

    final combined = <Object>[...optimistic, ...rows];
    if (combined.isEmpty) {
      return const Center(child: Text('Пока нет сообщений'));
    }

    if (combined.length != _lastRowCount) {
      _lastRowCount = combined.length;
    }

    final iosInputEnabled = app.iosInputPanelEnabled;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification) {
              if (n.dragDetails != null) {
                _userScrolling = true;
              }
            } else if (n is ScrollEndNotification) {
              _userScrolling = false;
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + (_composerHeight <= 0 ? 64 : _composerHeight),
            ),
            itemCount: combined.length,
            itemBuilder: (context, index) {
              final item = combined[index];
              if (item is _OptimisticChatMessage) {
                final isMe = item.senderToken == app.characterToken;
                return _ChatBubble(
                  key: ValueKey<String>('optimistic:${item.localId}'),
                  isMe: isMe,
                  text: item.text,
                  senderName: item.senderName,
                  replyToName: item.replyToName,
                  replyToText: item.replyToText,
                  imageUrl: item.imageUrl,
                  isSticker: item.isSticker,
                  dimmed: true,
                );
              }

              final row = item as Map<String, dynamic>;
              final rowId = (row['id'] ?? '').toString();
              final ciphertext = (row['ciphertext'] ?? '').toString();
              if (token == null || token.isEmpty || ciphertext.isEmpty) {
                return const SizedBox.shrink();
              }

              return FutureBuilder<Map<String, dynamic>>(
                future: _decryptFutureByCiphertext.putIfAbsent(
                  ciphertext,
                  () => _E2ee.decrypt(chatToken: token, encrypted: ciphertext),
                ),
                builder: (context, snap) {
                  final optimisticByRowId = rowId.isEmpty
                      ? null
                      : optimisticById[rowId];
                  final optimisticMatch = optimisticByCiphertext[ciphertext];
                  final imageUrl = (row['image_url'] ?? '').toString().trim();
                  final stickerUrl = (row['sticker_url'] ?? '')
                      .toString()
                      .trim();
                  final mediaUrl = stickerUrl.isNotEmpty
                      ? stickerUrl
                      : (imageUrl.isEmpty ? '' : imageUrl);

                  if (snap.hasError) {
                    return _ChatBubble(
                      isMe: false,
                      text: 'Не удалось расшифровать сообщение',
                      senderName: '',
                      replyToName: null,
                      replyToText: null,
                      imageUrl: mediaUrl.isEmpty ? null : mediaUrl,
                      isSticker: stickerUrl.isNotEmpty,
                      dimmed: false,
                    );
                  }

                  if (!snap.hasData) {
                    final pending = optimisticByRowId ?? optimisticMatch;
                    if (pending != null) {
                      final isMe = pending.senderToken == app.characterToken;
                      return _ChatBubble(
                        isMe: isMe,
                        text: pending.text,
                        senderName: pending.senderName,
                        replyToName: pending.replyToName,
                        replyToText: pending.replyToText,
                        imageUrl: pending.imageUrl,
                        isSticker: pending.isSticker,
                        dimmed: true,
                      );
                    }
                    return const SizedBox(height: 48);
                  }

                  final payload = snap.data!;
                  final senderToken = (payload['sender_token'] ?? '')
                      .toString();
                  final sender = (payload['sender_name'] ?? '').toString();
                  final text = (payload['text'] ?? '').toString();
                  final replyToName = (payload['reply_to_name'] ?? '')
                      .toString();
                  final replyToText = (payload['reply_to_text'] ?? '')
                      .toString();

                  final isMe =
                      senderToken.isNotEmpty &&
                      senderToken == app.characterToken;

                  final msgId = (row['id'] ?? '').toString();
                  final canEdit =
                      isMe && imageUrl.isEmpty && stickerUrl.isEmpty;

                  final bubble = _ChatBubble(
                    key: ValueKey<String>('server:$msgId'),
                    isMe: isMe,
                    text: text,
                    senderName: sender,
                    replyToName: replyToName.isEmpty ? null : replyToName,
                    replyToText: replyToText.isEmpty ? null : replyToText,
                    imageUrl: mediaUrl.isEmpty ? null : mediaUrl,
                    isSticker: stickerUrl.isNotEmpty,
                    dimmed: false,
                  );

                  if (msgId.isEmpty) return bubble;

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (d) {
                      _showMessageActions(
                        tapPosition: d.globalPosition,
                        messageId: msgId,
                        text: text,
                        imageUrl: mediaUrl.isEmpty ? null : mediaUrl,
                        senderName: sender,
                        isMe: isMe,
                        canEdit: canEdit,
                      );
                    },
                    child: bubble,
                  );
                },
              );
            },
          ),
        ),
        if (iosInputEnabled && _composerFocused)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              onTap: () {},
            ),
          ),
      ],
    );
  }
}

enum _ChatInfoTab { participants, files }

class ChatInfoPage extends StatefulWidget {
  const ChatInfoPage({
    required this.chatUuid,
    required this.chatId,
    required this.chatName,
    super.key,
  });

  final String chatUuid;
  final String chatId;
  final String chatName;

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  _ChatInfoTab _tab = _ChatInfoTab.participants;
  bool _loading = true;
  String? _error;
  List<String> _memberTokens = const [];
  Map<String, String> _tokenToName = const {};
  bool _membersUnavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    LogService.instance.info('Загрузка информации о чате: ${widget.chatUuid}');
    setState(() {
      _loading = true;
      _error = null;
      _membersUnavailable = false;
    });

    try {
      final chatRow = await Supabase.instance.client
          .from('chats')
          .select('member_tokens')
          .eq('id', widget.chatUuid)
          .limit(1)
          .maybeSingle();
      LogService.instance.api('Supabase: получены участники чата');

      final raw = chatRow == null ? null : chatRow['member_tokens'];

      final tokens = <String>[];
      if (raw is List) {
        for (final e in raw) {
          final t = (e ?? '').toString().trim();
          if (t.isNotEmpty) tokens.add(t);
        }
      }

      Map<String, String> names = <String, String>{};
      if (tokens.isNotEmpty) {
        try {
          final dynamic rows = await Supabase.instance.client
              .from('characters')
              .select('token, name')
              .inFilter('token', tokens);

          if (rows is List) {
            for (final r in rows) {
              if (r is! Map) continue;
              final t = (r['token'] ?? '').toString();
              if (t.isEmpty) continue;
              final n = (r['name'] ?? '').toString().trim();
              if (n.isNotEmpty) names[t] = n;
            }
          }
        } catch (_) {
          // Ignore character lookup errors; fall back to showing tokens.
        }
      }

      if (!mounted) return;
      setState(() {
        _memberTokens = tokens;
        _tokenToName = names;
        _loading = false;
      });
    } catch (e) {
      final isMissingMembersColumn =
          e is PostgrestException &&
          (e.code == '42703' ||
              e.message.toLowerCase().contains('member_tokens') ||
              (e.details?.toString().toLowerCase().contains('member_tokens') ??
                  false));

      if (isMissingMembersColumn) {
        if (!mounted) return;
        setState(() {
          _memberTokens = const [];
          _tokenToName = const {};
          _membersUnavailable = true;
          _loading = false;
          _error = null;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _pillButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primary : cs.surfaceContainerHighest;
    final fg = selected ? cs.onPrimary : cs.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _valueBlock({required String value, required String label}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha:0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final token = app.getChatToken(
      chatUuid: widget.chatUuid,
      legacyChatId: widget.chatId,
    );

    final count = _memberTokens.length;
    final countText = '$count участников';
    final cs = Theme.of(context).colorScheme;
    final displayName = app.getChatDisplayName(
      chatUuid: widget.chatUuid,
      fallback: widget.chatName,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatSettingsPage(
                    chatUuid: widget.chatUuid,
                    chatId: widget.chatId,
                    chatName: displayName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              countText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha:0.7),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _valueBlock(value: (token ?? '—'), label: 'Токен чата'),
          const SizedBox(height: 10),
          _valueBlock(
            value: widget.chatId.isEmpty ? '—' : widget.chatId,
            label: 'ID чата',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _pillButton(
                  text: 'Участники',
                  selected: _tab == _ChatInfoTab.participants,
                  onTap: () => setState(() => _tab = _ChatInfoTab.participants),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pillButton(
                  text: 'Файлы',
                  selected: _tab == _ChatInfoTab.files,
                  onTap: () => setState(() => _tab = _ChatInfoTab.files),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Ошибка: $_error',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.error),
              ),
            )
          else if (_tab == _ChatInfoTab.files)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Пока не работает',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha:0.7),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _memberTokens.isEmpty
                  ? [
                      if (_membersUnavailable)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Участники недоступны (в Supabase нет колонки member_tokens в таблице chats)',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha:0.7),
                                ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Пока никого нет',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha:0.7),
                                ),
                          ),
                        ),
                    ]
                  : _memberTokens.map((t) {
                      final name = _tokenToName[t];
                      final shown = (name == null || name.isEmpty) ? t : name;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          shown,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      );
                    }).toList(),
            ),
        ],
      ),
    );
  }
}

class _OptimisticChatMessage {
  _OptimisticChatMessage({
    this.localId = '',
    required this.ciphertext,
    required this.senderToken,
    required this.senderName,
    required this.text,
    this.replyToName,
    this.replyToText,
    this.imageUrl,
    this.isSticker = false,
  });

  final String localId;
  String? ciphertext;
  final String senderToken;
  final String senderName;
  final String text;
  final String? replyToName;
  final String? replyToText;
  String? imageUrl;
  final bool isSticker;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    super.key,
    required this.isMe,
    required this.text,
    required this.senderName,
    required this.replyToName,
    required this.replyToText,
    required this.imageUrl,
    required this.isSticker,
    required this.dimmed,
  });

  final bool isMe;
  final String text;
  final String senderName;
  final String? replyToName;
  final String? replyToText;
  final String? imageUrl;
  final bool isSticker;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * (isMe ? 0.68 : 0.74);
    final bg = isMe
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = isMe ? Theme.of(context).colorScheme.onPrimary : null;

    final hasImage = imageUrl != null;
    final nameTrimmed = senderName.trim();
    final replyNameTrimmed = (replyToName ?? '').trim();
    final replyTextTrimmed = (replyToText ?? '').trim();
    final hasReply = replyNameTrimmed.isNotEmpty || replyTextTrimmed.isNotEmpty;

    final showSenderUi = !isMe && nameTrimmed.isNotEmpty;

    Widget bubbleBody() {
      return Opacity(
        opacity: dimmed ? 0.75 : 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: hasImage
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showSenderUi) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 6),
                          child: Text(
                            nameTrimmed,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha:0.8),
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                      if (hasReply) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 3,
                                height: 34,
                                decoration: BoxDecoration(
                                  color:
                                      (fg ??
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary)
                                          .withValues(alpha:0.9),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (replyNameTrimmed.isNotEmpty)
                                      Text(
                                        replyNameTrimmed,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: fg,
                                          height: 1,
                                        ),
                                      ),
                                    if (replyTextTrimmed.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        replyTextTrimmed,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: fg,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isSticker
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder<void>(
                                        opaque: false,
                                        pageBuilder: (_, _, _) =>
                                            _FullscreenImageViewer(
                                              imageUrl: imageUrl!,
                                            ),
                                      ),
                                    );
                                  },
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _CachedMediaSquare(
                                url: imageUrl!,
                                isSticker: isSticker,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showSenderUi) ...[
                          Text(
                            nameTrimmed,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha:0.8),
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (hasReply) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 3,
                                height: 34,
                                decoration: BoxDecoration(
                                  color:
                                      (fg ??
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary)
                                          .withValues(alpha:0.9),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (replyNameTrimmed.isNotEmpty)
                                      Text(
                                        replyNameTrimmed,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: fg,
                                          height: 1,
                                        ),
                                      ),
                                    if (replyTextTrimmed.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        replyTextTrimmed,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: fg,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        DefaultTextStyle.merge(
                          style: TextStyle(color: fg),
                          child: _MessageText(text: text),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final avatarBg = cs.surfaceContainerHighest;
    final avatarFg = cs.onSurface.withValues(alpha:0.85);

    Widget avatar() {
      final letter = nameTrimmed.isNotEmpty
          ? nameTrimmed.characters.first.toUpperCase()
          : '?';
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: avatarBg,
          shape: BoxShape.circle,
          border: Border.all(color: cs.onSurface.withValues(alpha:0.08)),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: avatarFg,
            height: 1,
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: isMe
          ? bubbleBody()
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: avatar(),
                ),
                const SizedBox(width: 10),
                bubbleBody(),
              ],
            ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _MediaDraft {
  _MediaDraft({required this.bytes, required this.caption});

  final Uint8List bytes;
  final String caption;
}

class _MediaSendPage extends StatefulWidget {
  const _MediaSendPage({required this.chatTitle, required this.bytes});

  final String chatTitle;
  final Uint8List bytes;

  @override
  State<_MediaSendPage> createState() => _MediaSendPageState();
}

class _MediaSendPageState extends State<_MediaSendPage> {
  final TextEditingController _captionController = TextEditingController();
  late Uint8List _bytes;
  bool _hd = true;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.bytes;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop<_MediaDraft?>(null);

  Future<Uint8List> _applyQuality(Uint8List bytes) async {
    if (_hd) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final maxSide = 1280;
      final resized = (decoded.width > maxSide || decoded.height > maxSide)
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxSide : null,
              height: decoded.height > decoded.width ? maxSide : null,
              interpolation: img.Interpolation.average,
            )
          : decoded;
      final jpg = img.encodeJpg(resized, quality: 82);
      return Uint8List.fromList(jpg);
    } catch (_) {
      return bytes;
    }
  }

  Future<void> _send() async {
    final finalBytes = await _applyQuality(_bytes);
    if (!mounted) return;
    Navigator.of(context).pop<_MediaDraft?>(
      _MediaDraft(bytes: finalBytes, caption: _captionController.text.trim()),
    );
  }

  Future<void> _crop() async {
    if (_isCropping) return;
    try {
      setState(() => _isCropping = true);
      final outBytes = await Navigator.of(context).push<Uint8List?>(
        MaterialPageRoute<Uint8List?>(
          builder: (_) => _CropImagePage(bytes: _bytes),
          fullscreenDialog: true,
        ),
      );
      if (outBytes == null) return;
      if (!mounted) return;
      setState(() => _bytes = outBytes);
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  Future<void> _draw() async {
    final edited = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        builder: (_) => _ImageDrawPage(bytes: _bytes),
      ),
    );
    if (edited == null) return;
    if (!mounted) return;
    setState(() => _bytes = edited);
  }

  void _toggleQuality() {
    setState(() => _hd = !_hd);
    final text = _hd
        ? 'Фотография будет в высоком разрешении.'
        : 'Фотография будет в обычном разрешении.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _adjust() async {
    final edited = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        builder: (_) => _ImageAdjustPage(bytes: _bytes),
        fullscreenDialog: true,
      ),
    );
    if (edited == null) return;
    if (!mounted) return;
    setState(() => _bytes = edited);
  }

  Future<void> _filters() async {
    final edited = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        builder: (_) => _ImageFiltersPage(bytes: _bytes),
        fullscreenDialog: true,
      ),
    );
    if (edited == null) return;
    if (!mounted) return;
    setState(() => _bytes = edited);
  }

  Future<void> _addText() async {
    final edited = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        builder: (_) => _ImageTextPage(bytes: _bytes),
        fullscreenDialog: true,
      ),
    );
    if (edited == null) return;
    if (!mounted) return;
    setState(() => _bytes = edited);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(child: Image.memory(_bytes, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    widget.chatTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: TextField(
                            controller: _captionController,
                            style: const TextStyle(color: Colors.white),
                            minLines: 1,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Добавить подпись…',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: cs.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _send(),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.send, color: cs.onPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 84 + bottomPadding,
              child: Row(
                children: [
                  _BottomAction(
                    icon: Icons.crop,
                    onTap: _crop,
                    enabled: !_isCropping,
                  ),
                  const SizedBox(width: 10),
                  _BottomAction(icon: Icons.brush_outlined, onTap: _draw),
                  const SizedBox(width: 10),
                  _BottomAction(icon: Icons.tune, onTap: _adjust),
                  const SizedBox(width: 10),
                  _BottomAction(icon: Icons.filter_vintage, onTap: _filters),
                  const SizedBox(width: 10),
                  _BottomAction(icon: Icons.text_fields, onTap: _addText),
                  const SizedBox(width: 10),
                  _QualityAction(hd: _hd, onTap: _toggleQuality),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  final TransformationController _tc = TransformationController();
  bool _panEnabled = false;

  Future<File?>? _fileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fileFuture ??= () async {
      return CacheService.instance.getOrDownloadFile(
        widget.imageUrl,
        allowDownload: true,
        forceDownload: false,
      );
    }();
  }

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _tc.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _tc.value.getMaxScaleOnAxis();
    final pan = scale > 1.01;
    if (pan != _panEnabled) {
      setState(() {
        _panEnabled = pan;
      });
    }
    if (!pan) {
      final m = _tc.value;
      if (m.storage[12] != 0 || m.storage[13] != 0) {
        _tc.value = Matrix4.identity();
      }
    }
  }

  Future<void> _download(BuildContext context) async {
    try {
      final ok = await GallerySaver.saveImage(
        widget.imageUrl,
        albumName: 'RAS',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok == true ? 'Скачано в RAS' : 'Не удалось скачать'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка скачивания: $e')));
    }
  }

  Future<void> _openMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Скачать'),
                onTap: () => Navigator.of(context).pop('download'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'download' && context.mounted) {
      await _download(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Material(
      color: Colors.black.withValues(alpha:0.72),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _tc,
              panEnabled: _panEnabled,
              scaleEnabled: true,
              boundaryMargin: EdgeInsets.zero,
              minScale: 0.8,
              maxScale: 4,
              child: FutureBuilder<File?>(
                future: _fileFuture,
                builder: (context, snap) {
                  final file = snap.data;
                  if (file != null) {
                    return Image.file(file, fit: BoxFit.contain);
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  final u = widget.imageUrl.trim();
                  if (!u.contains('://')) {
                    final f = File(u);
                    return Image.file(f, fit: BoxFit.contain);
                  }
                  if (u.startsWith('file://')) {
                    final path = Uri.tryParse(u)?.toFilePath();
                    if (path != null) {
                      return Image.file(File(path), fit: BoxFit.contain);
                    }
                  }
                  return Image.network(u, fit: BoxFit.contain);
                },
              ),
            ),
          ),
          Positioned(
            top: top + 12,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Positioned(
            top: top + 12,
            right: 12,
            child: IconButton(
              onPressed: () => _openMenu(context),
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class NotesChatPage extends StatefulWidget {
  const NotesChatPage({super.key});

  @override
  State<NotesChatPage> createState() => _NotesChatPageState();
}

class _NotesChatPageState extends State<NotesChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];
  String? _replyToMessageId;
  String? _replyToSenderName;
  String? _replyToText;
  String? _editingMessageId;

  String get _prefsKey => 'notes_chat_rows_v1';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        if (!mounted) return;
        setState(() {
          _rows = const <Map<String, dynamic>>[];
          _loading = false;
        });
        return;
      }
      final decoded = jsonDecode(raw);
      final list = <Map<String, dynamic>>[];
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) list.add(Map<String, dynamic>.from(e));
        }
      }
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = const <Map<String, dynamic>>[];
        _loading = false;
      });
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_rows));
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToSenderName = null;
      _replyToText = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
    });
  }

  Future<void> _copyMessage({
    required String text,
    required String? imagePath,
  }) async {
    final value = (imagePath != null && imagePath.trim().isNotEmpty)
        ? imagePath.trim()
        : text;
    await Clipboard.setData(ClipboardData(text: value));
  }

  Future<void> _deleteNoteMessage(String id) async {
    final next = _rows.where((r) => (r['id'] ?? '').toString() != id).toList();
    setState(() {
      _rows = next;
      if (_replyToMessageId == id) _cancelReply();
      if (_editingMessageId == id) _cancelEditing();
    });
    await _persist();
  }

  Future<void> _showNoteMessageActions({
    required Offset tapPosition,
    required String messageId,
    required String senderName,
    required String text,
    required String? imagePath,
    required bool isSticker,
  }) async {
    final screen = MediaQuery.of(context).size;
    const menuWidth = 186.0;
    const menuHeight = 52.0;
    final left = (tapPosition.dx - (menuWidth / 2)).clamp(
      12.0,
      screen.width - 12 - menuWidth,
    );
    final top = (tapPosition.dy - (menuHeight / 2)).clamp(
      12.0,
      screen.height - 12 - menuHeight,
    );

    final canEdit = !isSticker && (imagePath ?? '').trim().isEmpty;

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'actions',
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, _) {
        final cs = Theme.of(context).colorScheme;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: cs.onSurface.withValues(alpha:0.08)),
                    ),
                    shadows: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        color: Color(0x33000000),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop('reply'),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.reply, size: 20),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop('delete'),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop('copy'),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.content_copy, size: 20),
                        ),
                        IconButton(
                          onPressed: canEdit
                              ? () => Navigator.of(context).pop('edit')
                              : null,
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    switch (action) {
      case 'reply':
        setState(() {
          _replyToMessageId = messageId;
          final s = senderName.trim();
          _replyToSenderName = s.isNotEmpty ? s : 'Вы';
          final t = text.trim();
          if (t.isNotEmpty) {
            _replyToText = t;
          } else if ((imagePath ?? '').trim().isNotEmpty) {
            _replyToText = isSticker ? 'Стикер' : 'Фото';
          } else {
            _replyToText = 'Сообщение';
          }
        });
        break;
      case 'delete':
        await _deleteNoteMessage(messageId);
        break;
      case 'copy':
        await _copyMessage(text: text, imagePath: imagePath);
        break;
      case 'edit':
        if (!canEdit) return;
        setState(() {
          _editingMessageId = messageId;
          _controller.text = text;
          _controller.selection = TextSelection.collapsed(offset: text.length);
        });
        break;
    }
  }

  Future<Directory> _mediaDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory('${dir.path}/notes_media');
    if (!await media.exists()) {
      await media.create(recursive: true);
    }
    return media;
  }

  Future<String> _saveBytesToLocalFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final media = await _mediaDir();
    final safeName = fileName.trim().isEmpty ? const Uuid().v4() : fileName;
    final out = File('${media.path}/$safeName');
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    LogService.instance.chat(
      'Отправка сообщения: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}"',
    );
    _controller.clear();
    final app = AppScope.of(context);

    final editingId = _editingMessageId;
    final isEditing = editingId != null;
    if (isEditing) {
      final next = <Map<String, dynamic>>[];
      for (final r in _rows) {
        final id = (r['id'] ?? '').toString();
        if (id != editingId) {
          next.add(r);
          continue;
        }
        final updated = Map<String, dynamic>.from(r);
        updated['text'] = text;
        next.add(updated);
      }
      setState(() {
        _rows = next;
        _editingMessageId = null;
      });
      await _persist();
      return;
    }

    final replyId = _replyToMessageId;
    final replyName = _replyToSenderName;
    final replyText = _replyToText;
    if (replyId != null) {
      _cancelReply();
    }

    final row = <String, dynamic>{
      'id': const Uuid().v4(),
      'sender_name': (app.displayName ?? '').toString(),
      'text': text,
      'reply_to_id': replyId,
      if (replyId != null) 'reply_to_name': replyName,
      if (replyId != null) 'reply_to_text': replyText,
      'image_path': '',
      'is_sticker': false,
      'ts': DateTime.now().toIso8601String(),
    };
    setState(() {
      _rows = [row, ..._rows];
    });
    await _persist();
  }

  Future<void> _sendImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String caption,
  }) async {
    final app = AppScope.of(context);
    final localPath = await _saveBytesToLocalFile(
      bytes: bytes,
      fileName: fileName,
    );

    final replyId = _replyToMessageId;
    final replyName = _replyToSenderName;
    final replyText = _replyToText;
    if (replyId != null) {
      _cancelReply();
    }

    final row = <String, dynamic>{
      'id': const Uuid().v4(),
      'sender_name': (app.displayName ?? '').toString(),
      'text': caption,
      'reply_to_id': replyId,
      if (replyId != null) 'reply_to_name': replyName,
      if (replyId != null) 'reply_to_text': replyText,
      'image_path': localPath,
      'is_sticker': false,
      'ts': DateTime.now().toIso8601String(),
    };
    setState(() {
      _rows = [row, ..._rows];
    });
    await _persist();
  }

  Future<void> _openMediaPreviewAndSend({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final draft = await Navigator.of(context).push<_MediaDraft?>(
      MaterialPageRoute<_MediaDraft?>(
        builder: (_) => _MediaSendPage(chatTitle: 'Заметки', bytes: bytes),
      ),
    );
    if (draft == null) return;
    if (!mounted) return;
    await _sendImageBytes(
      bytes: draft.bytes,
      fileName: fileName,
      caption: draft.caption,
    );
  }

  Future<void> _pickAndSendImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final fileName = xfile.name.isNotEmpty
        ? xfile.name
        : 'image_${DateTime.now().millisecondsSinceEpoch}.png';
    await _openMediaPreviewAndSend(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
    );
  }

  Future<void> _sendAssetEntity(AssetEntity entity) async {
    final file = await entity.file;
    if (file == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть файл из галереи')),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    final ext = entity.type == AssetType.video ? 'mp4' : 'jpg';
    final fileName =
        'media_${DateTime.now().millisecondsSinceEpoch}.${ext.toLowerCase()}';
    await _openMediaPreviewAndSend(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
    );
  }

  Future<void> _openAttachSheet() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет доступа к галерее')));
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final height = MediaQuery.of(sheetContext).size.height;
        return SizedBox(
          height: height * 0.55,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: Center(
                  child: SizedBox(
                    width: 42,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x33000000),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                child: _GalleryPickerSheet(
                  onPick: (entity) async {
                    Navigator.of(sheetContext).pop();
                    await _sendAssetEntity(entity);
                  },
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: Material(
                  color: cs.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _pickAndSendImageFromSource(ImageSource.camera);
                    },
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.photo_camera, color: cs.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendSticker(String stickerUrl) async {
    final app = AppScope.of(context);
    String localPath = stickerUrl.trim();
    if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
      try {
        final uri = Uri.parse(localPath);
        final client = HttpClient();
        final req = await client.getUrl(uri);
        final res = await req.close();
        final chunks = <int>[];
        await for (final c in res) {
          chunks.addAll(c);
        }
        final bytes = Uint8List.fromList(chunks);
        client.close();
        final fileName =
            'sticker_${DateTime.now().millisecondsSinceEpoch}.webp';
        localPath = await _saveBytesToLocalFile(
          bytes: bytes,
          fileName: fileName,
        );
      } catch (_) {}
    }

    final row = <String, dynamic>{
      'id': const Uuid().v4(),
      'sender_name': (app.displayName ?? '').toString(),
      'text': '',
      'reply_to_id': null,
      'image_path': localPath,
      'is_sticker': true,
      'ts': DateTime.now().toIso8601String(),
    };
    setState(() {
      _rows = [row, ..._rows];
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final wallpaper = controller.chatWallpaper;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayBg = isDark ? Colors.black : Colors.white;
    final overlayFg = isDark ? Colors.white : Colors.black;
    final baseBg = Theme.of(context).colorScheme.surface;

    return Scaffold(
      extendBodyBehindAppBar: wallpaper != null,
      backgroundColor: wallpaper != null ? Colors.transparent : baseBg,
      appBar: AppBar(
        title: wallpaper != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: ShapeDecoration(
                  color: overlayBg,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Заметки',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: overlayFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : const Text('Заметки'),
        backgroundColor: wallpaper != null ? Colors.transparent : null,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: wallpaper != null
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: overlayBg,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: overlayFg),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (wallpaper != null)
            Image.asset(wallpaper, fit: BoxFit.cover)
          else
            ColoredBox(color: baseBg),
          Column(
            children: [
              if (wallpaper != null)
                SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight,
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                    ? const Center(
                        child: Text('Вы ещё ничего не добавили в заметки'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final id = (row['id'] ?? '').toString();
                          final senderName = (row['sender_name'] ?? '')
                              .toString();
                          final text = (row['text'] ?? '').toString();
                          final replyToName = (row['reply_to_name'] ?? '')
                              .toString()
                              .trim();
                          final replyToText = (row['reply_to_text'] ?? '')
                              .toString()
                              .trim();
                          final imagePath = (row['image_path'] ?? '')
                              .toString()
                              .trim();
                          final isSticker = row['is_sticker'] == true;
                          final url = imagePath.isEmpty ? null : imagePath;
                          final bubble = _ChatBubble(
                            key: ValueKey<String>('notes:$id'),
                            isMe: true,
                            text: text,
                            senderName: senderName,
                            replyToName: replyToName.isEmpty
                                ? null
                                : replyToName,
                            replyToText: replyToText.isEmpty
                                ? null
                                : replyToText,
                            imageUrl: url,
                            isSticker: isSticker,
                            dimmed: false,
                          );
                          if (id.isEmpty) return bubble;
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (d) {
                              _showNoteMessageActions(
                                tapPosition: d.globalPosition,
                                messageId: id,
                                senderName: senderName,
                                text: text,
                                imagePath: url,
                                isSticker: isSticker,
                              );
                            },
                            child: bubble,
                          );
                        },
                      ),
              ),
              _ChatComposer(
                controller: _controller,
                onSend: _sendText,
                advancedComposerEnabled: AppScope.of(
                  context,
                ).advancedComposerEnabled,
                iosInputPanelEnabled: AppScope.of(context).iosInputPanelEnabled,
                headerTitle: _editingMessageId != null
                    ? 'Редактирование'
                    : (_replyToSenderName ?? '').trim().isEmpty
                    ? null
                    : _replyToSenderName,
                headerSubtitle: _editingMessageId != null
                    ? 'Изменить сообщение'
                    : _replyToText,
                headerIcon: _editingMessageId != null
                    ? Icons.edit_outlined
                    : Icons.reply,
                onCloseHeader: () {
                  if (_editingMessageId != null) {
                    _cancelEditing();
                  } else {
                    _cancelReply();
                  }
                },
                onAttach: _openAttachSheet,
                onCamera: () => _pickAndSendImageFromSource(ImageSource.camera),
                onSendSticker: _sendSticker,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text});

  final String text;

  static final RegExp _urlRe = RegExp(r'(https?:\/\/[^\s]+)');

  List<InlineSpan> _parseStyledSpans(String input, TextStyle baseStyle) {
    final spans = <InlineSpan>[];

    final buf = StringBuffer();
    var bold = false;
    var strike = false;

    TextStyle currentStyle() {
      var s = baseStyle;
      if (bold) s = s.copyWith(fontWeight: FontWeight.w700);
      if (strike) {
        s = s.copyWith(decoration: TextDecoration.lineThrough);
      }
      return s;
    }

    void flush() {
      if (buf.isEmpty) return;
      spans.add(TextSpan(text: buf.toString(), style: currentStyle()));
      buf.clear();
    }

    var i = 0;
    while (i < input.length) {
      final rest = input.substring(i);
      if (rest.startsWith('**')) {
        flush();
        bold = !bold;
        i += 2;
        continue;
      }
      if (rest.startsWith('~~')) {
        flush();
        strike = !strike;
        i += 2;
        continue;
      }
      buf.write(input[i]);
      i += 1;
    }
    flush();

    return spans;
  }

  List<InlineSpan> _linkifySpans(BuildContext context, List<InlineSpan> spans) {
    final out = <InlineSpan>[];
    final cs = Theme.of(context).colorScheme;
    final textColor = DefaultTextStyle.of(context).style.color ?? cs.primary;
    final linkStyleBase = TextStyle(
      color: textColor,
      decoration: TextDecoration.underline,
      decorationColor: textColor.withValues(alpha: 0.7),
    );

    for (final s in spans) {
      if (s is! TextSpan) {
        out.add(s);
        continue;
      }

      final raw = s.text ?? '';
      if (raw.isEmpty) {
        out.add(s);
        continue;
      }

      final matches = _urlRe.allMatches(raw).toList(growable: false);
      if (matches.isEmpty) {
        out.add(s);
        continue;
      }

      var start = 0;
      for (final m in matches) {
        if (m.start > start) {
          out.add(
            TextSpan(text: raw.substring(start, m.start), style: s.style),
          );
        }

        final url = raw.substring(m.start, m.end);
        out.add(
          TextSpan(
            text: url,
            style: (s.style ?? const TextStyle()).merge(linkStyleBase),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.tryParse(url);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
          ),
        );
        start = m.end;
      }

      if (start < raw.length) {
        out.add(TextSpan(text: raw.substring(start), style: s.style));
      }
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;

    if (!text.contains('||')) {
      return RichText(
        text: TextSpan(
          style: baseStyle,
          children: _linkifySpans(context, _parseStyledSpans(text, baseStyle)),
        ),
      );
    }

    final parts = text.split('||');
    final children = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.isEmpty) continue;
      final isSpoiler = i.isOdd;
      if (!isSpoiler) {
        children.addAll(
          _linkifySpans(context, _parseStyledSpans(p, baseStyle)),
        );
      } else {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _SpoilerText(text: p),
          ),
        );
      }
    }
    return RichText(
      text: TextSpan(style: baseStyle, children: children),
    );
  }
}

class _SpoilerText extends StatefulWidget {
  const _SpoilerText({required this.text});

  final String text;

  @override
  State<_SpoilerText> createState() => _SpoilerTextState();
}

class _SpoilerTextState extends State<_SpoilerText> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.onSurface.withValues(alpha: 0.12);
    final fg = cs.onSurface;

    return InkWell(
      onTap: () => setState(() => _revealed = !_revealed),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _revealed ? Colors.transparent : bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _revealed ? widget.text : '•••',
          style: TextStyle(color: fg),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.advancedComposerEnabled,
    required this.iosInputPanelEnabled,
    this.focusNode,
    this.headerTitle,
    this.headerSubtitle,
    this.headerIcon,
    this.onCloseHeader,
    this.onAttach,
    this.onCamera,
    this.onSendSticker,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool advancedComposerEnabled;
  final bool iosInputPanelEnabled;
  final FocusNode? focusNode;
  final String? headerTitle;
  final String? headerSubtitle;
  final IconData? headerIcon;
  final VoidCallback? onCloseHeader;
  final Future<void> Function()? onAttach;
  final Future<void> Function()? onCamera;
  final void Function(String url)? onSendSticker;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  TextSelection get _selection => widget.controller.selection;
  bool _quickEmojiOpen = false;
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final bool _ownsFocusNode = widget.focusNode == null;
  bool _hasText = false;
  bool _iosEmojiOpen = false;

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next == _hasText) return;
    setState(() => _hasText = next);
  }

  void _toggleIosEmojiPanel() {
    if (_iosEmojiOpen) {
      setState(() => _iosEmojiOpen = false);
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_focusNode);
      });
      return;
    }

    _focusNode.unfocus();
    setState(() => _iosEmojiOpen = true);
  }

  void _toggleKeyboard() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    } else {
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  void _insertAtCursor(String value) {
    final text = widget.controller.text;
    final sel = _selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, value);
    widget.controller.text = newText;
    final newOffset = start + value.length;
    widget.controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _wrapSelection(String left, String right) {
    final text = widget.controller.text;
    final sel = _selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = start <= end ? text.substring(start, end) : '';
    final replacement = '$left$selected$right';
    final newText = text.replaceRange(start, end, replacement);
    widget.controller.text = newText;
    final cursor = start + replacement.length;
    widget.controller.selection = TextSelection.collapsed(offset: cursor);
  }

  Future<void> _openFormattingSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.format_bold),
                title: const Text('Жирный'),
                onTap: () => Navigator.of(context).pop('bold'),
              ),
              ListTile(
                leading: const Icon(Icons.format_strikethrough),
                title: const Text('Зачеркнутый'),
                onTap: () => Navigator.of(context).pop('strike'),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Скрытый (спойлер)'),
                onTap: () => Navigator.of(context).pop('spoiler'),
              ),
            ],
          ),
        );
      },
    );

    switch (action) {
      case 'bold':
        _wrapSelection('**', '**');
        break;
      case 'strike':
        _wrapSelection('~~', '~~');
        break;
      case 'spoiler':
        _wrapSelection('||', '||');
        break;
    }
  }

  Future<void> _openFullscreenComposer() async {
    final initial = widget.controller.text;
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _FullscreenComposerPage(initialText: initial),
        fullscreenDialog: true,
      ),
    );

    if (updated != null && mounted) {
      widget.controller.text = updated;
      widget.controller.selection = TextSelection.collapsed(
        offset: updated.length,
      );
      FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = cs.onSurface.withValues(alpha:0.7);

    final bottomIconTheme = IconThemeData(color: iconColor, size: 22);
    final hasHeader = (widget.headerTitle ?? '').trim().isNotEmpty;

    if (widget.iosInputPanelEnabled) {
      final fieldBg = Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2F3C4A).withValues(alpha:0.92)
          : const Color(0xFF3E5465).withValues(alpha:0.88);
      final circleBg = Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A3340).withValues(alpha:0.94)
          : const Color(0xFF2F4658).withValues(alpha:0.90);
      final hintColor = Colors.white.withValues(alpha:0.55);
      final textColor = Colors.white.withValues(alpha:0.95);
      final innerIconColor = Colors.white.withValues(alpha:0.65);
      final sendBg = cs.primary;
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: circleBg,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          final f = widget.onAttach;
                          if (f != null) await f();
                        },
                        child: Center(
                          child: Icon(
                            Icons.attach_file,
                            color: Colors.white.withValues(alpha:0.90),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 3,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (widget.headerIcon == Icons.edit)
                                              ? widget.headerTitle!
                                              : 'В ответ ${widget.headerTitle!}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.1,
                                            fontWeight: FontWeight.w600,
                                            color: cs.primary,
                                          ),
                                        ),
                                        if ((widget.headerSubtitle ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              widget.headerSubtitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.1,
                                                color: Colors.white.withValues(alpha:
                                                  0.70,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: widget.onCloseHeader,
                                      icon: Icon(
                                        Icons.close,
                                        size: 22,
                                        color: Colors.white.withValues(alpha:0.70),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _iosEmojiOpen
                                    ? GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          setState(() => _iosEmojiOpen = false);
                                          Future<void>.delayed(
                                            const Duration(milliseconds: 100),
                                                () {
                                              if (!context.mounted) return;
                                              FocusScope.of(
                                                context,
                                              ).requestFocus(_focusNode);
                                            },
                                          );
                                        },
                                        child: AbsorbPointer(
                                          child: TextField(
                                            focusNode: _focusNode,
                                            controller: widget.controller,
                                            minLines: 1,
                                            maxLines: 7,
                                            keyboardType:
                                                TextInputType.multiline,
                                            textInputAction:
                                                TextInputAction.newline,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 17,
                                            ),
                                            textAlignVertical:
                                                TextAlignVertical.top,
                                            decoration: InputDecoration(
                                              hintText: 'Сообщение',
                                              hintStyle: TextStyle(
                                                color: hintColor,
                                                fontSize: 17,
                                              ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.fromLTRB(
                                                    0,
                                                    hasHeader ? 0 : 12,
                                                    0,
                                                    12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : TextField(
                                        focusNode: _focusNode,
                                        controller: widget.controller,
                                        minLines: 1,
                                        maxLines: 7,
                                        keyboardType: TextInputType.multiline,
                                        textInputAction:
                                            TextInputAction.newline,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 17,
                                        ),
                                        textAlignVertical:
                                            TextAlignVertical.top,
                                        decoration: InputDecoration(
                                          hintText: 'Сообщение',
                                          hintStyle: TextStyle(
                                            color: hintColor,
                                            fontSize: 17,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.fromLTRB(
                                            0,
                                            hasHeader ? 0 : 12,
                                            0,
                                            12,
                                          ),
                                        ),
                                      ),
                              ),
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: _toggleIosEmojiPanel,
                                      icon: Icon(
                                        _iosEmojiOpen
                                            ? Icons.keyboard
                                            : (_hasText
                                                  ? Icons
                                                        .emoji_emotions_outlined
                                                  : Icons
                                                        .emoji_emotions_outlined),
                                        color: innerIconColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_hasText) ...[
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2.5,
                                        ),
                                        child: Material(
                                          key: const ValueKey(
                                            'ios_send_inside',
                                          ),
                                          color: sendBg,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: widget.onSend,
                                            child: Center(
                                              child: Icon(
                                                Icons.send,
                                                size: 20,
                                                color: Colors.white.withValues(alpha:
                                                  0.95,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerRight,
                      widthFactor: _hasText ? 0.0 : 1.0,
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              offset: _hasText
                                  ? const Offset(0.45, 0)
                                  : Offset.zero,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                                opacity: _hasText ? 0.0 : 1.0,
                                child: Material(
                                  key: const ValueKey('ios_mic_outside'),
                                  color: circleBg,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: null,
                                    child: Center(
                                      child: Icon(
                                        Icons.mic,
                                        color: Colors.white.withValues(alpha:0.92),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                reverseDuration: const Duration(milliseconds: 90),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation);
                  return ClipRect(
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: _iosEmojiOpen
                    ? Padding(
                        key: const ValueKey('ios_emoji_panel'),
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          height: 320,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha:0.92),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: EmojiPickerSheet(
                              onEmojiSelected: _insertAtCursor,
                              onStickerSelected: (url) {
                                final f = widget.onSendSticker;
                                if (f == null) return;
                                f(url);
                              },
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('ios_emoji_panel_empty')),
              ),
              if (widget.advancedComposerEnabled) ...[
                const SizedBox(height: 4),
                IconTheme(
                  data: bottomIconTheme,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _openFullscreenComposer,
                        icon: const Icon(Icons.open_in_full),
                      ),
                      const VerticalDivider(width: 8, thickness: 1),
                      IconButton(
                        onPressed: () => _insertAtCursor('@'),
                        icon: const Icon(Icons.alternate_email),
                      ),
                      IconButton(
                        onPressed: _openFormattingSheet,
                        icon: const Icon(Icons.text_fields),
                      ),
                      IconButton(
                        onPressed: widget.onCamera,
                        icon: const Icon(Icons.photo_camera),
                      ),
                      IconButton(
                        onPressed: _toggleKeyboard,
                        icon: const Icon(Icons.keyboard),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasHeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                          child: Row(
                            children: [
                              Icon(
                                widget.headerIcon ?? Icons.reply,
                                size: 18,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.headerTitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: cs.primary,
                                      ),
                                    ),
                                    if ((widget.headerSubtitle ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        widget.headerSubtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.1,
                                          color: cs.onSurface.withValues(alpha:0.7),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: widget.onCloseHeader,
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: cs.onSurface.withValues(alpha:0.55),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            EmojiPickerButton(
                              onEmojiSelected: _insertAtCursor,
                              iconColor: iconColor,
                            ),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 38,
                                ),
                                child: TextField(
                                  focusNode: _focusNode,
                                  controller: widget.controller,
                                  minLines: 1,
                                  maxLines: 7,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    hintText: 'Сообщение',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.fromLTRB(
                                      2,
                                      6,
                                      2,
                                      6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: widget.onAttach,
                                icon: Icon(Icons.attach_file, color: iconColor),
                              ),
                            ),
                            const SizedBox(width: 2),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: Material(
                                color: cs.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: widget.onSend,
                                  child: Icon(
                                    Icons.send,
                                    size: 18,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      if (widget.advancedComposerEnabled) ...[
                        const SizedBox(height: 4),
                        IconTheme(
                          data: bottomIconTheme,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _openFullscreenComposer,
                                icon: const Icon(Icons.open_in_full),
                              ),
                              const VerticalDivider(width: 8, thickness: 1),
                              IconButton(
                                onPressed: () => _insertAtCursor('@'),
                                icon: const Icon(Icons.alternate_email),
                              ),
                              IconButton(
                                onPressed: _openFormattingSheet,
                                icon: const Icon(Icons.text_fields),
                              ),
                              IconButton(
                                onPressed: widget.onCamera,
                                icon: const Icon(Icons.photo_camera),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _quickEmojiOpen = !_quickEmojiOpen;
                                  });
                                },
                                icon: const Icon(Icons.emoji_emotions),
                              ),
                              IconButton(
                                onPressed: _toggleKeyboard,
                                icon: const Icon(Icons.keyboard),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(-0.15, 0),
                              end: Offset.zero,
                            ).animate(animation);
                            return ClipRect(
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                axisAlignment: -1,
                                child: SlideTransition(
                                  position: offset,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: _quickEmojiOpen
                              ? Padding(
                                  key: const ValueKey('quick_emojis'),
                                  padding: const EdgeInsets.only(top: 6),
                                  child: QuickEmojiRow(
                                    onEmojiSelected: _insertAtCursor,
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('quick_emojis_empty'),
                                ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenComposerPage extends StatefulWidget {
  const _FullscreenComposerPage({required this.initialText});

  final String initialText;

  @override
  State<_FullscreenComposerPage> createState() =>
      _FullscreenComposerPageState();
}

class _FullscreenComposerPageState extends State<_FullscreenComposerPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
        title: const Text(''),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Сообщение',
              border: OutlineInputBorder(),
            ),
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
