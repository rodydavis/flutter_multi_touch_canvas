import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../classes/canvas_object.dart';
import '../classes/rect_points.dart';

/// Control the canvas and the objects on it
class CanvasController {
  /// Controller for the stream output
  final _controller = StreamController<CanvasController>();

  /// Reference to the stream to update the UI
  Stream<CanvasController> get stream => _controller.stream;

  /// Emit a new event to rebuild the UI
  void add([CanvasController val]) => _controller.add(val ?? this);

  /// Stop the stream and finish
  void close() {
    _controller.close();
    focusNode.dispose();
  }

  /// Start the stream
  void init() => add();

  // -- Canvas Objects --

  final List<CanvasObject<Widget>> _objects = [];

  /// Current Objects on the canvas
  List<CanvasObject<Widget>> get objects => _objects;

  /// Add an object to the canvas
  void addObject(CanvasObject<Widget> value) => _update(() {
        _objects.add(value);
      });

  /// Add an object to the canvas
  void updateObject(int i, CanvasObject<Widget> value) => _update(() {
        _objects[i] = value;
      });

  /// Remove an object from the canvas
  void removeObject(int i) => _update(() {
        _objects.removeAt(i);
      });

  /// Focus node for listening for keyboard shortcuts
  final focusNode = FocusNode();

  /// Raw events from keys pressed
  void rawKeyEvent(BuildContext context, RawKeyEvent key) {
    // Scale keys
    if (key.isKeyPressed(LogicalKeyboardKey.minus)) {
      zoomOut();
    }
    if (key.isKeyPressed(LogicalKeyboardKey.equal)) {
      zoomIn();
    }
    // Directional Keys
    if (key.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      offset = offset + Offset(offsetAdjust, 0.0);
    }
    if (key.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      offset = offset + Offset(-offsetAdjust, 0.0);
    }
    if (key.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      offset = offset + Offset(0.0, offsetAdjust);
    }
    if (key.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      offset = offset + Offset(0.0, -offsetAdjust);
    }

    _shiftPressed = key.isShiftPressed;
    _metaPressed = key.isMetaPressed;

    /// Update Controller Instance
    add(this);
  }

  /// Trigger Shift Press
  void shiftSelect() {
    _shiftPressed = true;
  }

  /// Trigger Meta Press
  void metaSelect() {
    _metaPressed = true;
  }

  final Map<int, Offset> _pointerMap = {};

  /// Number of inputs currently on the screen
  int get touchCount => _pointerMap.values.length;

  /// Marquee selection on the canvas
  RectPoints get marquee => _marquee;
  RectPoints _marquee;

  /// Dragging a canvas object
  bool get isMovingCanvasObject => _isMovingCanvasObject;
  bool _isMovingCanvasObject = false;

  final List<int> _selectedObjects = [];
  List<int> get selectedObjectsIndices => _selectedObjects;
  List<CanvasObject<Widget>> get selectedObjects =>
      _selectedObjects.map((i) => _objects[i]).toList();
  bool isObjectSelected(int i) => _selectedObjects.contains(i);

  /// Called every time a new input touches the screen
  void addTouch(int pointer, Offset offsetVal, Offset globalVal) {
    _pointerMap[pointer] = offsetVal;

    if (shiftPressed) {
      final pt = (offsetVal / scale) - (offset);
      _marquee = RectPoints(pt, pt);
    }

    /// Update Controller Instance
    add(this);
  }

  /// Called when any of the inputs update position
  void updateTouch(int pointer, Offset offsetVal, Offset globalVal) {
    if (_marquee != null) {
      // Update New Widget Rect
      final _pts = _marquee;
      final a = _pointerMap.values.first;
      _pointerMap[pointer] = offsetVal;
      final b = _pointerMap.values.first;
      final delta = (b - a) / scale;
      _pts.end = _pts.end + delta;
      _marquee = _pts;
      final _rect = Rect.fromPoints(_pts.start, _pts.end);
      _selectedObjects.clear();
      for (var i = 0; i < _objects.length; i++) {
        if (_rect.overlaps(_objects[i].rect)) {
          _selectedObjects.add(i);
        }
      }
    } else if (touchCount == 1) {
      // Widget Move
      _isMovingCanvasObject = true;
      final a = _pointerMap.values.first;
      _pointerMap[pointer] = offsetVal;
      final b = _pointerMap.values.first;
      if (_selectedObjects.isEmpty) {
        add(this);
        return;
      }
      for (final idx in _selectedObjects) {
        final widget = _objects[idx];
        final delta = (b - a) / scale;
        final _newOffset = widget.offset + delta;
        _objects[idx] = widget.copyWith(dx: _newOffset.dx, dy: _newOffset.dy);
      }
    } else if (touchCount == 2) {
      // Scale and Rotate Update
      _isMovingCanvasObject = false;
      final _rectA = _getRectFromPoints(_pointerMap.values.toList());
      _pointerMap[pointer] = offsetVal;
      final _rectB = _getRectFromPoints(_pointerMap.values.toList());
      final _delta = _rectB.center - _rectA.center;
      final _newOffset = offset + (_delta / scale);
      offset = _newOffset;
      final aDistance = (_rectA.topLeft - _rectA.bottomRight).distance;
      final bDistance = (_rectB.topLeft - _rectB.bottomRight).distance;
      final change = (bDistance / aDistance);
      scale = scale * change;
    } else {
      // Pan Update
      _isMovingCanvasObject = false;
      final _rectA = _getRectFromPoints(_pointerMap.values.toList());
      _pointerMap[pointer] = offsetVal;
      final _rectB = _getRectFromPoints(_pointerMap.values.toList());
      final _delta = _rectB.center - _rectA.center;
      offset = offset + (_delta / scale);
    }
    _pointerMap[pointer] = offsetVal;

    /// Update Controller Instance
    add(this);
  }

  /// Called when a input is removed from the screen
  void removeTouch(int pointer) {
    _pointerMap.remove(pointer);

    if (touchCount < 1) {
      _isMovingCanvasObject = false;
    }
    if (_marquee != null) {
      _marquee = null;
      _shiftPressed = false;
    }

    /// Update Controller Instance
    add(this);
  }

  void selectObject(int i) => _update(() {
        if (!_metaPressed) {
          _selectedObjects.clear();
        }
        _selectedObjects.add(0);
        final item = _objects.removeAt(i);
        _objects.insert(0, item);
      });

  /// Checks if the shift key on the keyboard is pressed
  bool get shiftPressed => _shiftPressed;
  bool _shiftPressed = false;

  /// Checks if the meta key on the keyboard is pressed
  bool get metaPressed => _metaPressed;
  bool _metaPressed = false;

  /// Scale of the canvas
  double get scale => _scale;
  double _scale = 1;
  set scale(double value) => _update(() {
        if (value <= minScale) {
          value = minScale;
        } else if (value >= maxScale) {
          value = maxScale;
        }
        _scale = value;
      });

  /// Max possible scale
  static const double maxScale = 3.0;

  /// Min possible scale
  static const double minScale = 0.2;

  /// How much to scale the canvas in increments
  static const double scaleAdjust = 0.05;

  /// How much to shift the canvas in increments
  static const double offsetAdjust = 15;

  /// Current offset of the canvas
  Offset get offset => _offset;
  Offset _offset = Offset.zero;
  set offset(Offset value) => _update(() {
        _offset = value;
      });

  static const double _scaleDefault = 1;
  static const Offset _offsetDefault = Offset.zero;

  /// Reset the canvas zoom and offset
  void reset() {
    scale = _scaleDefault;
    offset = _offsetDefault;
  }

  /// Zoom in the canvas
  void zoomIn() {
    scale += scaleAdjust;
  }

  /// Zoom out the canvas
  void zoomOut() {
    scale -= scaleAdjust;
  }

  void _update(void Function() action) {
    action();
    add(this);
  }

  Rect _getRectFromPoints(List<Offset> offsets) {
    if (offsets.length == 2) {
      return Rect.fromPoints(offsets.first, offsets.last);
    }
    final dxs = offsets.map((e) => e.dx).toList();
    final dys = offsets.map((e) => e.dy).toList();
    double left = _minFromList(dxs);
    double top = _minFromList(dys);
    double bottom = _maxFromList(dys);
    double right = _maxFromList(dxs);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _minFromList(List<double> values) {
    double value = double.infinity;
    for (final item in values) {
      value = math.min(item, value);
    }
    return value;
  }

  double _maxFromList(List<double> values) {
    double value = -double.infinity;
    for (final item in values) {
      value = math.max(item, value);
    }
    return value;
  }
}
