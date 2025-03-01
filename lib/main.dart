import 'package:flutter/material.dart';
import 'widgets/map_widget.dart';
import 'services/service_locator.dart';
import 'services/error_handling_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize all services
    await ServiceLocator().initialize();
    final services = ServiceLocator();
    
    // Configure error handling
    services.errorHandling.onHighSeverityError = () {
      // Handle critical errors, possibly restart the app
      services.logging.error('Critical error occurred, consider app restart');
    };

    // Initialize map data
    services.logging.info('Initializing map data...');
    
    // Precache the low-quality image (fast loading)
    await services.imageCache.precacheAssetImage('assets/images/poland.jpg');
    services.logging.info('Low-quality map image precached');
    
    // Configure global error widget
    ErrorWidget.builder = (FlutterErrorDetails details) {
      services.errorHandling.handleError(
        'Flutter error occurred',
        severity: ErrorSeverity.high,
        error: details.exception,
        stackTrace: details.stack,
      );

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
                    services.logging.info('Attempting error recovery...');
                    // This will trigger a hot reload
                    services.mapState.reset();
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
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize app: $e');
    debugPrint(stackTrace.toString());
    rethrow;
  }
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
