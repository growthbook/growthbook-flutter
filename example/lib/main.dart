import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  List<String> tabNames = <String>[
    'All',
    'Travel',
    'Lifestyle',
    'Fitness',
    'Education',
    'Elections',
    'Original',
    'World',
    'Travel'
  ];
  late List<Tab> tabs;

  /// Initialization of controllers.
  late TabController _tabController;
  final userAttr = {"id": (!kIsWeb && Platform.isIOS) ? "foo" : "foo_bar"};
  GrowthBookSDK? gb;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabNames.length, vsync: this);
    tabs = <Tab>[...tabNames.map((e) => Tab(text: e)).toList()];
    initializeSDK();
  }

  void initializeSDK() async {
    gb = await GBSDKBuilderApp(
      apiKey: kReleaseMode ? '<PROD_KEY>' : '<DEV_KEY>',
      apiHost: 'https://example.growthbook.io/',
      attributes: userAttr,
      growthBookTrackingCallBack: (trackData) {},
      gbFeatures: {
        'some-feature': GBFeature(defaultValue: true),
      },
    ).initialize();
    setState(() {});
  }

  Widget _getRightWidget() {
    if (gb?.feature('some-feature').on ?? false) {
      return TabBar(
        isScrollable: true,
        tabs: tabs,
        controller: _tabController,
        indicator: CircleTabIndicator(
          color: Theme.of(context).colorScheme.primary,
          radius: 4,
        ),
      );
    } else {
      return TabBar(
        isScrollable: true,
        tabs: tabs,
        controller: _tabController,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GrowthBook SDK'),
      ),
      body: Column(
        children: [
          _getRightWidget(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (var i = 0; i < tabNames.length; i++)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tabNames[i]),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//// To create dot shaped indicator.
class CircleTabIndicator extends Decoration {
  final BoxPainter _painter;

  CircleTabIndicator({required Color color, required double radius})
      : _painter = _CirclePainter(color, radius);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _painter;
}

class _CirclePainter extends BoxPainter {
  final Paint _paint;
  final double radius;

  _CirclePainter(Color color, this.radius)
      : _paint = Paint()
          ..color = color
          ..isAntiAlias = false;
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final Offset circleOffset =
        offset + Offset(cfg.size!.width / 2, cfg.size!.height - radius);
    canvas.drawCircle(circleOffset, radius, _paint);
  }
}
