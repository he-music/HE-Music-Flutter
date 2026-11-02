import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_ui_theme.dart';

/// Native input selected by the user's interface style while keeping editing state.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.readOnly = false,
    this.canRequestFocus = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final bool readOnly;
  final bool canRequestFocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool? enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final GestureTapCallback? onTap;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final _controller = TextEditingController();
  late final _focusNode = FocusNode();
  bool? _cupertino;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _focusNode;

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != null && widget.controller == null) {
      _controller.value = oldWidget.controller!.value;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cupertino = AppUiTheme.usesCupertino(context);
    if (_cupertino != null &&
        _cupertino != cupertino &&
        _effectiveFocusNode.hasFocus) {
      final focusNode = _effectiveFocusNode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            identical(focusNode, _effectiveFocusNode) &&
            widget.canRequestFocus &&
            widget.enabled != false) {
          focusNode.requestFocus();
        }
      });
    }
    _cupertino = cupertino;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cupertino!) {
      return TextField(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        decoration: widget.decoration,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        style: widget.style,
        textAlign: widget.textAlign,
        autofocus: widget.autofocus,
        readOnly: widget.readOnly,
        canRequestFocus: widget.canRequestFocus,
        obscureText: widget.obscureText,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: widget.onEditingComplete,
        onTap: widget.onTap,
      );
    }
    final decoration = widget.decoration;
    final theme = Theme.of(context);
    final error = decoration.errorText;
    final prefix =
        decoration.prefixIcon ??
        decoration.prefix ??
        (decoration.prefixText == null ? null : Text(decoration.prefixText!));
    final suffix =
        decoration.suffixIcon ??
        decoration.suffix ??
        (decoration.suffixText == null ? null : Text(decoration.suffixText!));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (decoration.label != null || decoration.labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child:
                decoration.label ??
                Text(decoration.labelText!, style: decoration.labelStyle),
          ),
        ExcludeFocus(
          excluding: !widget.canRequestFocus,
          child: CupertinoTextField(
            controller: _effectiveController,
            focusNode: _effectiveFocusNode,
            placeholder: decoration.hintText,
            placeholderStyle: decoration.hintStyle,
            prefix: prefix,
            suffix: suffix,
            padding:
                decoration.contentPadding?.resolve(
                  Directionality.of(context),
                ) ??
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: decoration.filled == true
                  ? decoration.fillColor ??
                        CupertinoColors.tertiarySystemFill.resolveFrom(context)
                  : CupertinoColors.secondarySystemGroupedBackground
                        .resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error == null
                    ? CupertinoColors.separator.resolveFrom(context)
                    : theme.colorScheme.error,
              ),
            ),
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            style: widget.style,
            textAlign: widget.textAlign,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            obscureText: widget.obscureText,
            autocorrect: widget.autocorrect,
            enableSuggestions: widget.enableSuggestions,
            enabled: widget.enabled ?? true,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onEditingComplete: widget.onEditingComplete,
            onTap: widget.onTap,
          ),
        ),
        if (error != null || decoration.error != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child:
                  decoration.error ??
                  Text(
                    error!,
                    style:
                        decoration.errorStyle ??
                        theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                  ),
            ),
          )
        else if (decoration.helperText != null || decoration.helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child:
                decoration.helper ??
                Text(decoration.helperText!, style: decoration.helperStyle),
          ),
      ],
    );
  }
}

/// Form validation wrapper with the same reset semantics as TextFormField.
class AppTextFormField extends StatefulWidget {
  const AppTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.autofocus = false,
    this.readOnly = false,
    this.canRequestFocus = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
  }) : assert(controller == null || initialValue == null);

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? initialValue;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final bool autofocus;
  final bool readOnly;
  final bool canRequestFocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool? enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormControl extends FormField<String> {
  const _AppTextFormControl({
    super.key,
    super.initialValue,
    super.enabled,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
    super.onReset,
    required super.builder,
  });

  @override
  FormFieldState<String> createState() => _AppTextFormControlState();
}

class _AppTextFormControlState extends FormFieldState<String> {
  // Like TextFormField.didUpdateWidget, synchronize a replacement controller
  // during the parent build without notifying Form or marking an interaction.
  void syncControllerValue(String value) => setValue(value);
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  final _fieldKey = GlobalKey<_AppTextFormControlState>();
  late final _controller = TextEditingController(text: widget.initialValue);
  late String _initialValue =
      widget.controller?.text ?? widget.initialValue ?? '';
  bool _resetting = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller;

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (_resetting) return;
    final field = _fieldKey.currentState;
    if (field != null && field.value != _effectiveController.text) {
      field.didChange(_effectiveController.text);
    }
  }

  @override
  void didUpdateWidget(AppTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.initialValue != widget.initialValue) {
      _initialValue = widget.controller?.text ?? widget.initialValue ?? '';
    }
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _controller).removeListener(
        _handleControllerChanged,
      );
      if (widget.controller == null && oldWidget.controller != null) {
        _controller.value = oldWidget.controller!.value;
      }
      _effectiveController.addListener(_handleControllerChanged);
      _fieldKey.currentState?.syncControllerValue(_effectiveController.text);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _resetController() {
    _resetting = true;
    try {
      if (_effectiveController.text != _initialValue) {
        _effectiveController.value = TextEditingValue(text: _initialValue);
      }
    } finally {
      _resetting = false;
    }
    // TextFormField reports reset through onChanged after FormField.reset clears
    // its value, interaction state, and validation error.
    widget.onChanged?.call(_effectiveController.text);
  }

  @override
  Widget build(BuildContext context) {
    return _AppTextFormControl(
      key: _fieldKey,
      initialValue: _initialValue,
      enabled: widget.enabled ?? true,
      validator: widget.validator,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      onReset: _resetController,
      builder: (field) => AppTextField(
        controller: _effectiveController,
        focusNode: widget.focusNode,
        decoration: widget.decoration.copyWith(errorText: field.errorText),
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        style: widget.style,
        autofocus: widget.autofocus,
        readOnly: widget.readOnly,
        canRequestFocus: widget.canRequestFocus,
        obscureText: widget.obscureText,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onSubmitted: widget.onFieldSubmitted,
      ),
    );
  }
}
