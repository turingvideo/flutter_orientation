import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orientation/orientation.dart';

const supportedOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OrientationPlugin.setPreferredOrientations(supportedOrientations);
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final layout = DuoLayoutController();
  DeviceOrientation requested = DeviceOrientation.portraitUp;

  @override
  void initState() {
    super.initState();
    layout.start();
    OrientationPlugin.setDuoInnerOrientation(DeviceOrientation.portraitUp);
  }

  Future<void> request(DeviceOrientation orientation) async {
    await OrientationPlugin.setPreferredOrientations(supportedOrientations);
    await OrientationPlugin.forceOrientation(orientation);
    if (mounted) setState(() => requested = orientation);
  }

  @override
  void dispose() {
    layout.dispose();
    OrientationPlugin.setDuoInnerOrientation(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Orientation Example')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Requested: ${requested.name}'),
        Text('Window: ${size.width.toInt()} x ${size.height.toInt()} '
            '${MediaQuery.orientationOf(context).name}'),
        ValueListenableBuilder<DuoLayout>(
          valueListenable: layout,
          builder: (_, value, __) => Text('Hinge: ${value.hingeStatus.name}'),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton(
            onPressed: () => request(DeviceOrientation.landscapeRight),
            child: const Text('Landscape Right'),
          ),
          ElevatedButton(
            onPressed: () => request(DeviceOrientation.portraitUp),
            child: const Text('Portrait'),
          ),
        ]),
      ]),
    );
  }
}
