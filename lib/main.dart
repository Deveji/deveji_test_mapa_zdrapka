import 'package:flutter/material.dart';
import 'widgets/map_widget.dart';

void main() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'An error occurred',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(details.exception.toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // This will trigger a hot reload
                  // which will recreate the widget tree
                  debugPrint('Retrying...');
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poland Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const SafeArea(
        child: Scaffold(
          body: MapWidget(),
        ),
      ),
    );
  }
}
