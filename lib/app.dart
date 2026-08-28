import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/app_controller.dart';
import 'ui/app_theme.dart';
import 'ui/brand_assets.dart';
import 'ui/pages.dart';

class SaydianApp extends StatefulWidget {
  const SaydianApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<SaydianApp> createState() => _SaydianAppState();
}

class _SaydianAppState extends State<SaydianApp> with WidgetsBindingObserver {
  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.restoreWearableConnection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saydian赛电',
      debugShowCheckedModeBanner: false,
      theme: buildSaydianTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final alert = controller.activeHealthWarningAlert;
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (alert != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: MediaQuery.paddingOf(context).top + 10,
                  child: Material(
                    key: const Key('global-health-warning'),
                    elevation: 10,
                    color: const Color(0xFFFFF1EE),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: SaydianColors.danger,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  alert.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: SaydianColors.danger,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(alert.message),
                                const SizedBox(height: 3),
                                const Text(
                                  '请休息后复测；如有明显不适，请及时咨询医务人员。',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: '关闭健康预警',
                            child: IconButton(
                              key: const Key('dismiss-health-warning'),
                              onPressed: controller.dismissHealthWarningAlert,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.isBooting) {
            return const _BootPage();
          }
          if (!controller.isAuthenticated && !controller.isPreviewMode) {
            return LoginPage(controller: controller);
          }
          return AppShell(controller: controller);
        },
      ),
    );
  }
}

class _BootPage extends StatelessWidget {
  const _BootPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: saydianSoftGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BootLogo(),
              SizedBox(height: 26),
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(height: 14),
              Text('正在为你准备…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootLogo extends StatelessWidget {
  const _BootLogo();

  @override
  Widget build(BuildContext context) {
    return const SaydianBrandLockup(width: 185);
  }
}
