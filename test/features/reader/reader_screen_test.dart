import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aplikasi_komik/data/models.dart';
import 'package:aplikasi_komik/data/reader_settings.dart';
import 'package:aplikasi_komik/features/reader/reader_screen.dart';
import 'package:aplikasi_komik/features/reader/reader_session_image_cache.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';

void main() {
  test('reader memesan rasio halaman dari metadata sebelum gambar termuat', () {
    const page = SourcePage(
      index: 0,
      imageUrl: 'https://cdn.example/page.webp',
      width: 800,
      height: 12000,
    );

    expect(readerPageAspectRatio(page), closeTo(1 / 15, 0.000001));
    expect(
      readerPageAspectRatio(
        const SourcePage(index: 1, imageUrl: 'https://cdn.example/unknown'),
      ),
      isNull,
    );
    expect(
      readerPageAspectRatio(
        const SourcePage(index: 1, imageUrl: 'https://cdn.example/unknown'),
        measured: 0.125,
      ),
      0.125,
    );
    expect(
      readerPageAspectRatio(page, measured: 0.7),
      closeTo(1 / 15, 0.000001),
    );
  });

  test('decode reader tidak memperbesar gambar melebihi file asli', () {
    const page = SourcePage(
      index: 0,
      imageUrl: 'https://cdn.example/page.webp',
      width: 800,
      height: 5000,
    );
    const veryLong = SourcePage(
      index: 1,
      imageUrl: 'https://cdn.example/long.webp',
      width: 2000,
      height: 40000,
    );

    expect(readerPageCacheWidth(page, 412, 3), 800);
    expect(readerPageCacheWidth(veryLong, 412, 3), 600);
    expect(
      readerPageCacheWidth(
        const SourcePage(index: 2, imageUrl: 'https://cdn.example/unknown'),
        412,
        3,
      ),
      1236,
    );
  });

  test('decode manga menyiapkan detail zoom tanpa melewati batas memori', () {
    expect(
      readerMangaCacheWidth(
        const SourcePage(
          index: 0,
          imageUrl: 'https://cdn.example/page.jpg',
          width: 800,
          height: 1200,
        ),
        412,
        3,
      ),
      800,
    );
    expect(
      readerMangaCacheWidth(
        const SourcePage(index: 1, imageUrl: 'https://cdn.example/unknown.jpg'),
        412,
        3,
      ),
      2472,
    );
    expect(
      readerMangaCacheWidth(
        const SourcePage(index: 2, imageUrl: 'https://cdn.example/huge.jpg'),
        1000,
        3,
      ),
      4096,
    );
  });

  test('decode zoom webtoon tetap tajam tanpa membuka bitmap raksasa', () {
    expect(
      readerWebtoonZoomCacheWidth(
        const SourcePage(
          index: 0,
          imageUrl: 'https://cdn.example/page.webp',
          width: 800,
          height: 12000,
        ),
        1030,
        3,
      ),
      800,
    );
    expect(
      readerWebtoonZoomCacheWidth(
        const SourcePage(
          index: 1,
          imageUrl: 'https://cdn.example/unknown.webp',
        ),
        1030,
        3,
      ),
      2048,
    );
  });

  test('zoom webtoon paint-only menjaga anchor dan ruang ujung chapter', () {
    const viewport = Size(412, 916);
    const focal = Offset(206, 458);
    const scale = 2.5;
    final translation = readerWebtoonPaintTranslation(
      desiredTranslation: Offset(
        focal.dx - focal.dx * scale,
        focal.dy - focal.dy * scale,
      ),
      scale: scale,
      viewport: viewport,
    );
    final matrix = readerZoomMatrix(scale: scale, translation: translation);

    expect(MatrixUtils.transformPoint(matrix, focal), focal);
    expect(
      readerWebtoonEdgeInset(scale: scale, viewportHeight: viewport.height),
      closeTo(274.8, 0.0001),
    );
    expect(readerWebtoonEdgeInset(scale: 1, viewportHeight: 916), 0);
    expect(
      readerWebtoonPaintTranslation(
        desiredTranslation: const Offset(100, -5000),
        scale: 2,
        viewport: viewport,
      ),
      const Offset(0, -916),
    );
  });

  test('cache chapter mendahulukan halaman aktif dan halaman terdekat', () {
    expect(readerChapterCacheOrder(7, 3), [3, 4, 2, 5, 1, 6, 0]);
    expect(readerChapterCacheOrder(4, -20), [0, 1, 2, 3]);
    expect(readerChapterCacheOrder(4, 20), [3, 2, 1, 0]);
    expect(readerChapterCacheOrder(0, 0), isEmpty);
  });

  test('matrix zoom menjaga titik sentuh tetap di posisi semula', () {
    const focal = Offset(120, 260);
    final matrix = mangaZoomMatrix(focalPoint: focal, scale: 2.5);

    expect(matrix.getMaxScaleOnAxis(), closeTo(2.5, 0.0001));
    final transformed = MatrixUtils.transformPoint(matrix, focal);
    expect(transformed.dx, closeTo(focal.dx, 0.0001));
    expect(transformed.dy, closeTo(focal.dy, 0.0001));
  });

  test('matrix rail manga mempertahankan titik scene yang sedang dibaca', () {
    const scene = Offset(240, 520);
    const focal = Offset(120, 300);
    final matrix = mangaZoomMatrixForScenePoint(
      scenePoint: scene,
      focalPoint: focal,
      scale: 3,
    );

    final transformed = MatrixUtils.transformPoint(matrix, scene);
    expect(matrix.getMaxScaleOnAxis(), closeTo(3, 0.0001));
    expect(transformed.dx, closeTo(focal.dx, 0.0001));
    expect(transformed.dy, closeTo(focal.dy, 0.0001));
  });

  test('pengaturan rail zoom tetap kompatibel dengan data lama', () {
    expect(ReaderSettings.fromMap(const {}).sideZoomControls, isTrue);
    final restored = ReaderSettings.fromMap(
      const ReaderSettings(sideZoomControls: false).toMap(),
    );
    expect(restored.sideZoomControls, isFalse);
  });

  testWidgets('pinch dan double tap webtoon tidak mengubah zoom', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'reader_direction': 0,
      'reader_side_zoom_controls': false,
    });
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(
            comic: Comic(
              id: 'gesture-free-webtoon',
              title: 'Uji Gestur Webtoon',
              src: 'Demo',
              hue: 180,
              ch: 2,
            ),
            chapter: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reader-zoom-rail')), findsNothing);
    final transformFinder = find.byKey(
      const ValueKey('reader-webtoon-transform'),
    );
    final focal = tester.getCenter(transformFinder);
    await tester.tapAt(focal);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(focal);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(),
      1,
    );

    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(const Offset(150, 450));
    await second.down(const Offset(262, 450));
    await first.moveTo(const Offset(90, 450));
    await second.moveTo(const Offset(322, 450));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(),
      1,
    );

    final vertical = tester.widget<ListView>(find.byType(ListView)).controller!;
    await tester.dragFrom(const Offset(206, 700), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(vertical.offset, greaterThan(0));
  });

  testWidgets('mode halaman hanya menerima zoom dari rail', (tester) async {
    SharedPreferences.setMockInitialValues({
      'reader_direction': 1,
      'reader_side_zoom_controls': true,
    });
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(
            comic: Comic(
              id: 'rail-manga',
              title: 'Uji Rail Manga',
              src: 'Demo',
              hue: 210,
              ch: 2,
            ),
            chapter: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byType(InteractiveViewer);
    var viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewer.scaleEnabled, isFalse);
    final controller = viewer.transformationController!;
    final focal = tester.getCenter(viewerFinder);

    await tester.tapAt(focal);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(focal);
    await tester.pumpAndSettle();
    expect(controller.value.isIdentity(), isTrue);

    final first = await tester.createGesture(pointer: 11);
    final second = await tester.createGesture(pointer: 12);
    await first.down(const Offset(150, 450));
    await second.down(const Offset(262, 450));
    await first.moveTo(const Offset(90, 450));
    await second.moveTo(const Offset(322, 450));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(controller.value.isIdentity(), isTrue);

    await tester.tap(find.byKey(const ValueKey('reader-zoom-in')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.25, 0.001));
    viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewer.scaleEnabled, isFalse);
  });

  testWidgets('rail zoom paint-only menjaga anchor dan tombolnya beranimasi', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'reader_direction': 0,
      'reader_side_zoom_controls': true,
    });
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(
            comic: Comic(
              id: 'rail-webtoon',
              title: 'Uji Rail Webtoon',
              src: 'Demo',
              hue: 120,
              ch: 2,
            ),
            chapter: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reader-zoom-rail')), findsOneWidget);
    final transformFinder = find.byKey(
      const ValueKey('reader-webtoon-transform'),
    );
    final vertical = tester.widget<ListView>(find.byType(ListView)).controller!;
    final layoutWidth = tester.getSize(find.byType(ListView)).width;
    vertical.jumpTo(600);
    await tester.pump();
    final oldVerticalOffset = vertical.offset;
    final oldMaxExtent = vertical.position.maxScrollExtent;

    final sliderRect = tester.getRect(
      find.byKey(const ValueKey('reader-zoom-slider')),
    );
    final gesture = await tester.startGesture(
      Offset(sliderRect.center.dx, sliderRect.bottom - 8),
    );
    await gesture.moveTo(Offset(sliderRect.center.dx, sliderRect.top + 8));
    await tester.pump();

    final preview = tester.widget<Transform>(transformFinder);
    final previewScale = preview.transform.getMaxScaleOnAxis();
    expect(previewScale, greaterThan(2));
    expect(vertical.offset, oldVerticalOffset);
    expect(vertical.position.maxScrollExtent, oldMaxExtent);
    expect(tester.getSize(find.byType(ListView)).width, layoutWidth);
    final viewportSize = tester.getSize(transformFinder);
    final focal = Offset(viewportSize.width / 2, viewportSize.height / 2);
    expect(
      MatrixUtils.transformPoint(preview.transform, focal),
      offsetMoreOrLessEquals(focal, epsilon: 0.01),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    final committed = tester.widget<Transform>(transformFinder);
    final committedScale = committed.transform.getMaxScaleOnAxis();
    final edgeInset = readerWebtoonEdgeInset(
      scale: committedScale,
      viewportHeight: viewportSize.height,
    );
    expect(committedScale, closeTo(previewScale, 0.01));
    expect(vertical.offset, closeTo(oldVerticalOffset + edgeInset, 1));
    // Lazy ListView boleh memperbarui estimasi extent ketika footer baru
    // terpasang, tetapi kenaikannya hanya spacer tepi, bukan skala seluruh list.
    expect(vertical.position.maxScrollExtent, greaterThan(oldMaxExtent));
    expect(
      vertical.position.maxScrollExtent,
      lessThan(oldMaxExtent + edgeInset * 2 + 5),
    );
    expect(tester.getSize(find.byType(ListView)).width, layoutWidth);

    final beforeZoomedScroll = vertical.offset;
    await tester.dragFrom(const Offset(160, 700), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(vertical.offset, greaterThan(beforeZoomedScroll));
    expect(
      tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(),
      closeTo(committedScale, 0.001),
    );

    final beforePanX = committed.transform.getTranslation().x;
    await tester.dragFrom(const Offset(300, 450), const Offset(-120, 0));
    await tester.pump();
    final afterPan = tester.widget<Transform>(transformFinder);
    expect(afterPan.transform.getTranslation().x, lessThan(beforePanX));
    final offsetBeforeReset = vertical.offset;

    await tester.tap(find.byKey(const ValueKey('reader-zoom-reset')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final resettingScale = tester
        .widget<Transform>(transformFinder)
        .transform
        .getMaxScaleOnAxis();
    expect(resettingScale, greaterThan(1));
    expect(resettingScale, lessThan(committedScale));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(),
      closeTo(1, 0.001),
    );
    expect(vertical.offset, closeTo(offsetBeforeReset - edgeInset, 1));

    await tester.tap(find.byKey(const ValueKey('reader-zoom-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final animatingScale = tester
        .widget<Transform>(transformFinder)
        .transform
        .getMaxScaleOnAxis();
    expect(animatingScale, greaterThan(1));
    expect(animatingScale, lessThan(1.25));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(),
      closeTo(1.25, 0.001),
    );
  });

  testWidgets('image reader mengingat rasio asli setelah decode', (
    tester,
  ) async {
    final image = await _testImage(width: 10, height: 20);
    double? measured;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            child: StableReaderPageImage(
              imageProvider: _SynchronousImageProvider(image),
              placeholder: const ColoredBox(color: Colors.black),
              errorPlaceholder: const ColoredBox(color: Colors.red),
              onAspectRatioKnown: (value) => measured = value,
              onImageError: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(measured, 0.5);
    var aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 0.5);

    // Simulasikan lazy-list membuang widget + ImageCache kehilangan bitmap.
    // Provider pengganti sengaja belum selesai; tinggi hasil decode pertama
    // tetap harus dipakai agar viewport tidak meloncat ke awal chapter.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            child: StableReaderPageImage(
              imageProvider: _PendingImageProvider(),
              initialAspectRatio: measured,
              placeholder: const ColoredBox(color: Colors.black),
              errorPlaceholder: const ColoredBox(color: Colors.red),
              onAspectRatioKnown: (_) {},
              onImageError: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 0.5);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ganti resolusi zoom mempertahankan frame lama sampai siap', (
    tester,
  ) async {
    final image = await _testImage(width: 10, height: 20);

    Widget app(ImageProvider provider) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 100,
          child: StableReaderPageImage(
            imageProvider: provider,
            initialAspectRatio: 0.5,
            placeholder: const ColoredBox(
              key: ValueKey('placeholder-cache'),
              color: Colors.black,
            ),
            errorPlaceholder: const ColoredBox(color: Colors.red),
            onAspectRatioKnown: (_) {},
            onImageError: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(_SynchronousImageProvider(image)));
    await tester.pump();
    expect(find.byKey(const ValueKey('placeholder-cache')), findsNothing);

    await tester.pumpWidget(app(_PendingImageProvider()));
    await tester.pump();

    expect(find.byKey(const ValueKey('placeholder-cache')), findsNothing);
    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect(imageWidget.gaplessPlayback, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<ui.Image> _testImage({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  return recorder.endRecording().toImage(width, height);
}

class _SynchronousImageProvider
    extends ImageProvider<_SynchronousImageProvider> {
  const _SynchronousImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_SynchronousImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _SynchronousImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image)));
}

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  _PendingImageProvider();

  final Completer<ImageInfo> _completer = Completer<ImageInfo>();

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_completer.future);
}
