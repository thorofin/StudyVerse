import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'viewmodels/group_view_model.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GroupViewModel()),
      ],
      child: const StudyVerseApp(),
    ),
  );
}

class StudyVerseApp extends StatelessWidget {
  const StudyVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyVerse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/':             (_) => const SplashScreen(),
        '/auth':         (_) => const AuthScreen(),
        '/home':         (_) => const HomeScreen(),
        '/group-detail': (_) => const GroupDetailScreen(),
        '/chat':         (_) => const ChatScreen(),
      },
    );
  }
}