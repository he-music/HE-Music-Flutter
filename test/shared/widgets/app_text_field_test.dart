import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_text_field.dart';

void main() {
  Widget host(AppUiStyle style, Widget child) => MaterialApp(
    home: Scaffold(
      body: AppUiStyleScope(style: style, child: child),
    ),
  );

  for (final style in AppUiStyle.values) {
    for (final external in [false, true]) {
      testWidgets(
        '${style.name} reset follows updated ${external ? 'controller' : 'initial value'}',
        (tester) async {
          final revision = ValueNotifier(0);
          final first = TextEditingController(text: 'A');
          final second = TextEditingController(text: 'B');
          final form = GlobalKey<FormState>();
          final changes = <String>[];
          String? saved;
          addTearDown(revision.dispose);
          addTearDown(first.dispose);
          addTearDown(second.dispose);
          await tester.pumpWidget(
            host(
              style,
              ValueListenableBuilder<int>(
                valueListenable: revision,
                builder: (context, version, child) => Form(
                  key: form,
                  child: AppTextFormField(
                    controller: external
                        ? (version == 0 ? first : second)
                        : null,
                    initialValue: external ? null : (version == 0 ? 'A' : 'B'),
                    onChanged: changes.add,
                    onSaved: (value) => saved = value,
                  ),
                ),
              ),
            ),
          );
          final originalState = tester.state(find.byType(AppTextFormField));
          await tester.enterText(find.byType(EditableText), 'edited A');
          revision.value = 1;
          await tester.pump();
          expect(
            tester.state(find.byType(AppTextFormField)),
            same(originalState),
          );
          await tester.enterText(find.byType(EditableText), 'edited B');
          // Rebuilding with the same configuration must not turn this edit into
          // the reset baseline of the newly selected record/controller.
          revision.value = 2;
          await tester.pump();
          changes.clear();
          form.currentState!.reset();
          await tester.pump();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            'B',
          );
          expect(changes, ['B']);
          form.currentState!.save();
          expect(saved, 'B');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final external in [false, true]) {
    testWidgets(
      'style switch preserves ${external ? 'external' : 'owned'} state',
      (tester) async {
        final controller = external ? TextEditingController() : null;
        final focus = external ? FocusNode() : null;
        Widget field() =>
            AppTextField(controller: controller, focusNode: focus);
        await tester.pumpWidget(host(AppUiStyle.material, field()));
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(EditableText), 'draft music');
        const value = TextEditingValue(
          text: 'draft music',
          selection: TextSelection(baseOffset: 2, extentOffset: 5),
          composing: TextRange(start: 0, end: 5),
        );
        tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .value =
            value;
        await tester.pumpWidget(host(AppUiStyle.cupertino, field()));
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .value,
          value,
        );
        expect(find.byType(CupertinoTextField), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.pumpWidget(host(AppUiStyle.material, field()));
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .value,
          value,
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.pumpWidget(const SizedBox());
        controller?.dispose();
        focus?.dispose();
      },
    );
  }

  for (final style in AppUiStyle.values) {
    testWidgets('$style validates, submits, and tracks edits', (tester) async {
      final form = GlobalKey<FormState>();
      final controller = TextEditingController();
      String? submitted;
      String? saved;
      await tester.pumpWidget(
        host(
          style,
          Form(
            key: form,
            child: AppTextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
              ),
              autofillHints: const [AutofillHints.username],
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (value) => submitted = value,
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'listener');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, 'listener');
      expect(form.currentState!.validate(), isTrue);
      controller.text = 'programmatic';
      form.currentState!.save();
      expect(saved, 'programmatic');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    for (final external in [false, true]) {
      testWidgets(
        '$style reset restores ${external ? 'external' : 'owned'} initial value',
        (tester) async {
          final form = GlobalKey<FormState>();
          final controller = TextEditingController(text: 'original');
          final changed = <String>[];
          await tester.pumpWidget(
            host(
              style,
              Form(
                key: form,
                child: AppTextFormField(
                  controller: external ? controller : null,
                  initialValue: external ? null : 'original',
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value == 'original' ? 'Invalid initial' : null,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: changed.add,
                ),
              ),
            ),
          );
          await tester.enterText(find.byType(EditableText), 'edited');
          expect(form.currentState!.validate(), isTrue);
          expect(changed, ['edited']);
          form.currentState!.reset();
          await tester.pump();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            'original',
          );
          if (external) expect(controller.text, 'original');
          expect(form.currentState!.validate(), isFalse);
          await tester.pump();
          expect(
            tester
                .widget<AppTextField>(find.byType(AppTextField))
                .decoration
                .errorText,
            'Invalid initial',
          );
          expect(changed, ['edited', 'original']);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        },
      );
    }

    testWidgets('$style respects disabled and non-focusable inputs', (
      tester,
    ) async {
      final focus = FocusNode();
      await tester.pumpWidget(
        host(style, AppTextField(enabled: false, focusNode: focus)),
      );
      await tester.tap(find.byType(EditableText), warnIfMissed: false);
      expect(focus.hasFocus, isFalse);
      await tester.pumpWidget(
        host(style, AppTextField(canRequestFocus: false, focusNode: focus)),
      );
      await tester.tap(find.byType(EditableText));
      expect(focus.hasFocus, isFalse);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    });
  }
}
