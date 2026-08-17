import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'app_theme.dart';
import 'models.dart';

class CapturedGarment {
  final String path;
  final ClothingCategory category;
  const CapturedGarment(this.path, this.category);
}

class GarmentCameraPage extends StatefulWidget {
  final ClothingCategory initialCategory;
  const GarmentCameraPage({super.key, required this.initialCategory});

  @override
  State<GarmentCameraPage> createState() => _GarmentCameraPageState();
}

class _GarmentCameraPageState extends State<GarmentCameraPage>
    with WidgetsBindingObserver {
  static const _processor = MethodChannel(
    'com.dressfit.dressfit_app/garment_processor',
  );
  CameraController? controller;
  late ClothingCategory category = widget.initialCategory;
  String? error;
  String? pendingPhotoPath;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _warmUpOfflineModel();
    _start();
  }

  Future<void> _warmUpOfflineModel() async {
    try {
      final ready = await _processor.invokeMethod<bool>('prepareModel');
      debugPrint('Offline garment model ready: $ready');
    } catch (exception) {
      // Actual processing still reports a visible error if local initialization fails.
      debugPrint('Offline garment model warm-up failed: $exception');
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('没有可用相机');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted) return next.dispose();
      setState(() => controller = next);
    } catch (_) {
      if (mounted) setState(() => error = '无法打开相机，请检查相机权限');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed && controller == null) {
      _start();
    }
  }

  Future<void> _takePhoto() async {
    final current = controller;
    if (current == null ||
        !current.value.isInitialized ||
        current.value.isTakingPicture) {
      return;
    }
    if (processing) return;
    final shot = await current.takePicture();
    pendingPhotoPath = shot.path;
    await _processPhoto(shot.path);
  }

  Future<void> _pickFromGallery() async {
    if (processing) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      pendingPhotoPath = image.path;
      await _processPhoto(image.path);
    } on PlatformException {
      if (!mounted) return;
      await _showGalleryError('无法读取这张图片，请检查相册权限后重试');
    } catch (_) {
      if (!mounted) return;
      await _showGalleryError('无法打开相册，请稍后重试');
    }
  }

  Future<void> _showGalleryError(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('没有读取到图片'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Future<void> _processPhoto(String inputPath) async {
    if (processing) return;
    setState(() => processing = true);
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/garment_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      final processedPath = await _processor.invokeMethod<String>(
        'processGarment',
        {'inputPath': inputPath, 'outputPath': path, 'category': category.name},
      );
      if (!mounted) return;
      Navigator.pop(context, CapturedGarment(processedPath ?? path, category));
    } on PlatformException catch (exception) {
      if (!mounted) return;
      setState(() => processing = false);
      await _showProcessingError(exception.message ?? '没有识别到完整衣物，请重新拍摄');
    } catch (_) {
      if (!mounted) return;
      setState(() => processing = false);
      await _showProcessingError('智能抠图暂时不可用，请重试');
    }
  }

  Future<void> _showProcessingError(String message) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要再试一次'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'retake'),
            child: const Text('重新拍摄'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'original'),
            child: const Text('保留原图'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'retry'),
            child: const Text('重试抠图'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'retry' && pendingPhotoPath != null) {
      await _processPhoto(pendingPhotoPath!);
    } else if (action == 'original' && pendingPhotoPath != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/garment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(pendingPhotoPath!).copy(path);
      if (mounted) Navigator.pop(context, CapturedGarment(path, category));
    } else if (action == 'retake') {
      pendingPhotoPath = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller!.value.isInitialized)
          Center(child: CameraPreview(controller!))
        else
          Center(
            child: Text(
              error ?? '正在打开相机…',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        CustomPaint(painter: _GarmentGuidePainter(category)),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    _GlassButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const Text(
                      '拍下我的衣服',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '将${category.label}平铺并放入虚线框',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: ClothingCategory.values
                      .map(
                        (item) => Expanded(
                          child: GestureDetector(
                            onTap: processing
                                ? null
                                : () => setState(() => category = item),
                            child: AnimatedContainer(
                              duration: AppTheme.fast,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: category == item
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: category == item
                                      ? AppTheme.ink
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 24,
                      child: _GalleryButton(
                        enabled: !processing,
                        onTap: _pickFromGallery,
                      ),
                    ),
                    GestureDetector(
                      onTap: processing ? null : _takePhoto,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white54, width: 5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
                        child: const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: SizedBox(width: 58, height: 58),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (processing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3EF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 3),
                      SizedBox(height: 16),
                      Text(
                        '正在抠出衣物…',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        '自动去除背景并整理为衣橱图片',
                        style: TextStyle(color: AppTheme.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _GalleryButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _GalleryButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '从相册选择衣服图片',
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: AppTheme.fast,
        opacity: enabled ? 1 : .45,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(
            Icons.photo_library_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
      ),
    ),
  );
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );
}

class _GarmentGuidePainter extends CustomPainter {
  final ClothingCategory category;
  _GarmentGuidePainter(this.category);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .43);
    final path = Path();
    switch (category) {
      case ClothingCategory.hat:
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: size.width * .58,
              height: size.height * .24,
            ),
            const Radius.circular(70),
          ),
        );
        break;
      case ClothingCategory.top:
        final w = size.width * .72, h = size.height * .42;
        path.moveTo(center.dx - w * .22, center.dy - h / 2);
        path.lineTo(center.dx - w / 2, center.dy - h * .27);
        path.lineTo(center.dx - w * .38, center.dy - h * .05);
        path.lineTo(center.dx - w * .25, center.dy - h * .13);
        path.lineTo(center.dx - w * .25, center.dy + h / 2);
        path.lineTo(center.dx + w * .25, center.dy + h / 2);
        path.lineTo(center.dx + w * .25, center.dy - h * .13);
        path.lineTo(center.dx + w * .38, center.dy - h * .05);
        path.lineTo(center.dx + w / 2, center.dy - h * .27);
        path.lineTo(center.dx + w * .22, center.dy - h / 2);
        path.close();
        break;
      case ClothingCategory.bottom:
        final w = size.width * .48, h = size.height * .55;
        path.moveTo(center.dx - w / 2, center.dy - h / 2);
        path.lineTo(center.dx + w / 2, center.dy - h / 2);
        path.lineTo(center.dx + w * .38, center.dy + h / 2);
        path.lineTo(center.dx + w * .04, center.dy + h / 2);
        path.lineTo(center.dx, center.dy - h * .05);
        path.lineTo(center.dx - w * .04, center.dy + h / 2);
        path.lineTo(center.dx - w * .38, center.dy + h / 2);
        path.close();
        break;
      case ClothingCategory.shoes:
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: size.width * .82,
              height: size.height * .25,
            ),
            const Radius.circular(44),
          ),
        );
        break;
    }
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        canvas.drawPath(
          metric.extractPath(start, (start + 10).clamp(0, metric.length)),
          paint,
        );
        start += 17;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GarmentGuidePainter oldDelegate) =>
      oldDelegate.category != category;
}
