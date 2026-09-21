import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:he_music_flutter/features/player/presentation/styles/fluid_player_backdrop.dart';

void main() {
  testWidgets('fluid motion stops when paused and resumes without remounting', (
    tester,
  ) async {
    Widget app(bool active) => MaterialApp(
      home: FluidPlayerBackdrop(imageProvider: null, active: active),
    );
    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 40));
    final moving = tester.widget<MeshGradient>(find.byType(MeshGradient));
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester.widget<MeshGradient>(find.byType(MeshGradient)),
      isNot(same(moving)),
    );
    await tester.pumpWidget(app(false));
    await tester.pump(const Duration(seconds: 1));
    final paused = tester.widget<MeshGradient>(find.byType(MeshGradient));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<MeshGradient>(find.byType(MeshGradient)),
      same(paused),
    );
    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester.widget<MeshGradient>(find.byType(MeshGradient)),
      isNot(same(paused)),
    );
  });

  testWidgets('fluid mesh skips high refresh frames and background motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FluidPlayerBackdrop(imageProvider: null)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 40));
    final first = tester.widget<MeshGradient>(find.byType(MeshGradient));
    await tester.pump(const Duration(milliseconds: 8));
    expect(tester.widget<MeshGradient>(find.byType(MeshGradient)), same(first));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    final hidden = tester.widget<MeshGradient>(find.byType(MeshGradient));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<MeshGradient>(find.byType(MeshGradient)),
      same(hidden),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester.widget<MeshGradient>(find.byType(MeshGradient)),
      isNot(same(hidden)),
    );
  });
}
