import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/shared/widgets/active_viewport.dart';

void main() {
  testWidgets('only visible retained rows report exposure once per entry',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final exposures = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          height: 150,
          child: ListView(
            controller: controller,
            scrollCacheExtent: const ScrollCacheExtent.pixels(900),
            children: [
              ActiveViewport(
                minimumVisibleFraction: .5,
                onActiveChanged: exposures.add,
                child: const SizedBox(height: 100, child: Text('Visible joke')),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(exposures, [true]);
    await tester.pump();
    expect(exposures, [true]);
    controller.jumpTo(80);
    await tester.pumpAndSettle();
    expect(exposures, [true, false]);
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(exposures, [true, false, true]);
  });

  testWidgets('horizontal clips and large text do not count offscreen children',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var active = false;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: Center(
          child: SizedBox(
            width: 160,
            height: 100,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                const SizedBox(width: 170),
                ActiveViewport(
                  onActiveChanged: (value) => active = value,
                  child: const SizedBox(width: 42, height: 42),
                ),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(active, isFalse);
    controller.jumpTo(52);
    await tester.pumpAndSettle();
    expect(active, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('root modal covers nested navigator content until dismissal',
      (tester) async {
    final root = GlobalKey<NavigatorState>();
    final exposures = <bool>[];
    late BuildContext innerContext;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: root,
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (context) {
          innerContext = context;
          return Scaffold(
            body: ActiveViewport(
              onActiveChanged: exposures.add,
              child: const SizedBox(width: 42, height: 42),
            ),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(exposures, [true]);
    showModalBottomSheet<void>(
      context: innerContext,
      useRootNavigator: true,
      builder: (_) => const SizedBox(height: 200),
    );
    await tester.pumpAndSettle();
    expect(exposures, [true, false]);
    root.currentState!.pop();
    await tester.pumpAndSettle();
    expect(exposures, [true, false, true]);
  });

  testWidgets('IndexedStack, Offstage and TickerMode suspend retained children',
      (tester) async {
    var active = false;
    Widget content(
            {int index = 0, bool offstage = false, bool ticker = true}) =>
        MaterialApp(
          home: TickerMode(
            enabled: ticker,
            child: Offstage(
              offstage: offstage,
              child: IndexedStack(index: index, children: [
                ActiveViewport(
                  onActiveChanged: (value) => active = value,
                  child: const SizedBox(width: 42, height: 42),
                ),
                const SizedBox(width: 42, height: 42),
              ]),
            ),
          ),
        );
    await tester.pumpWidget(content());
    await tester.pumpAndSettle();
    expect(active, isTrue);
    await tester.pumpWidget(content(index: 1));
    await tester.pumpAndSettle();
    expect(active, isFalse);
    await tester.pumpWidget(content());
    await tester.pumpAndSettle();
    expect(active, isTrue);
    await tester.pumpWidget(content(offstage: true));
    await tester.pumpAndSettle();
    expect(active, isFalse);
    await tester.pumpWidget(content(ticker: false));
    await tester.pumpAndSettle();
    expect(active, isFalse);
  });
}
