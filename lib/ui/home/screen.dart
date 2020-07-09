import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../src/classes/canvas_object.dart';
import '../../src/controllers/canvas.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = CanvasController();

  @override
  void initState() {
    _controller.init();
    _dummyData();
    super.initState();
  }

  void _dummyData() {
    _controller.addObject(
      CanvasObject(
        dx: 20,
        dy: 20,
        width: 100,
        height: 100,
        child: Container(color: Colors.red),
      ),
    );
    _controller.addObject(
      CanvasObject(
        dx: 80,
        dy: 60,
        width: 100,
        height: 200,
        child: Container(color: Colors.green),
      ),
    );
    _controller.addObject(
      CanvasObject(
        dx: 100,
        dy: 40,
        width: 100,
        height: 50,
        child: Container(color: Colors.blue),
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CanvasController>(
        stream: _controller.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final instance = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              actions: [
                FocusScope(
                  canRequestFocus: false,
                  child: IconButton(
                    tooltip: 'Selection',
                    icon: Icon(Icons.select_all),
                    color: instance.shiftPressed
                        ? Theme.of(context).accentColor
                        : null,
                    onPressed: _controller.shiftSelect,
                  ),
                ),
                FocusScope(
                  canRequestFocus: false,
                  child: IconButton(
                    tooltip: 'Meta Key',
                    color: instance.metaPressed
                        ? Theme.of(context).accentColor
                        : null,
                    icon: Icon(Icons.category),
                    onPressed: _controller.metaSelect,
                  ),
                ),
                FocusScope(
                  canRequestFocus: false,
                  child: IconButton(
                    tooltip: 'Zoom In',
                    icon: Icon(Icons.zoom_in),
                    onPressed: _controller.zoomIn,
                  ),
                ),
                FocusScope(
                  canRequestFocus: false,
                  child: IconButton(
                    tooltip: 'Zoom Out',
                    icon: Icon(Icons.zoom_out),
                    onPressed: _controller.zoomOut,
                  ),
                ),
                FocusScope(
                  canRequestFocus: false,
                  child: IconButton(
                    tooltip: 'Reset the Scale and Offset',
                    icon: Icon(Icons.restore),
                    onPressed: _controller.reset,
                  ),
                ),
              ],
            ),
            body: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (details) {
                if (details is PointerScrollEvent) {
                  GestureBinding.instance.pointerSignalResolver
                      .register(details, (event) {
                    if (event is PointerScrollEvent) {
                      if (_controller.shiftPressed) {
                        double zoomDelta = (-event.scrollDelta.dy / 300);
                        _controller.scale = _controller.scale + zoomDelta;
                      } else {
                        _controller.offset =
                            _controller.offset - event.scrollDelta;
                      }
                    }
                  });
                }
              },
              onPointerMove: (details) {
                _controller.updateTouch(
                  details.pointer,
                  details.localPosition,
                  details.position,
                );
              },
              onPointerDown: (details) {
                _controller.addTouch(
                  details.pointer,
                  details.localPosition,
                  details.position,
                );
              },
              onPointerUp: (details) {
                _controller.removeTouch(details.pointer);
              },
              onPointerCancel: (details) {
                _controller.removeTouch(details.pointer);
              },
              child: RawKeyboardListener(
                autofocus: true,
                focusNode: _controller.focusNode,
                onKey: (key) => _controller.rawKeyEvent(context, key),
                child: SizedBox.expand(
                  child: Stack(
                    children: [
                      for (var i = instance.objects.length - 1; i > -1; i--)
                        Positioned.fromRect(
                          rect: instance.objects[i].rect.adjusted(
                            _controller.offset,
                            _controller.scale,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                                border: Border.all(
                              color: instance.isObjectSelected(i)
                                  ? Colors.grey
                                  : Colors.transparent,
                            )),
                            child: GestureDetector(
                              onTapDown: (_) => _controller.selectObject(i),
                              child: FittedBox(
                                fit: BoxFit.fill,
                                child: SizedBox.fromSize(
                                  size: instance.objects[i].size,
                                  child: instance.objects[i].child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (instance?.marquee != null)
                        Positioned.fromRect(
                          rect: instance.marquee.rect
                              .adjusted(instance.offset, instance.scale),
                          child: Container(
                            color: Colors.blueAccent.withOpacity(0.3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}

extension RectUtils on Rect {
  Rect adjusted(Offset offset, double scale) {
    final left = (this.left + offset.dx) * scale;
    final top = (this.top + offset.dy) * scale;
    final width = this.width * scale;
    final height = this.height * scale;
    return Rect.fromLTWH(left, top, width, height);
  }
}
