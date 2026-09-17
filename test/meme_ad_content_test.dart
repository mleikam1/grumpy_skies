import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/fun/meme/meme_catalog.dart';
import 'package:grumpy_skies/features/fun/meme/meme_completion.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_library.dart';
import 'package:grumpy_skies/features/roasts/widgets/roast_history_list.dart';
import 'package:grumpy_skies/models/daymaker_models.dart' show Roast;
import 'package:grumpy_skies/monetization/ad_placement.dart';
import 'package:grumpy_skies/monetization/widgets/ad_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemeCatalog catalog;
  setUpAll(() async => catalog = await MemeCatalog.load());

  test('saved revision identity ignores save clocks but includes real changes',
      () {
    final document = MemeDocument.blank(name: 'Private caption');
    final revision = memeCompletionRevision(document);
    expect(revision, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(
        memeCompletionRevision(document.copyWith(
            createdAt: DateTime.utc(2020), updatedAt: DateTime.utc(2027))),
        revision);
    expect(memeCompletionRevision(document.copyWith(name: 'Changed project')),
        isNot(revision));
  });

  Future<void> showLibrary(WidgetTester tester,
      {int count = 15,
      double width = 1000,
      ValueChanged<MemeTemplate>? select}) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MemeLibrary(
      catalog: MemeCatalog(
          templates: catalog.templates.take(count).toList(),
          stickers: catalog.stickers,
          personaCaptions: catalog.personaCaptions),
      drafts: const [],
      favorites: const {},
      onTemplate: select ?? (_) {},
      onDraft: (_) {},
      onFavorite: (_) {},
      onDelete: (_) {},
      onRemix: (_) {},
      onToday: () {},
      onSurprise: () {},
      onPhoto: () {},
      onBlank: () {},
      onImportBackup: () {},
      onCamera: () {},
      canCamera: false,
    ))));
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 768.0, 1280.0]) {
    testWidgets('publisher slot follows six in a completed row at $width',
        (tester) async {
      await showLibrary(tester, count: 8, width: width);
      final grids =
          tester.widgetList<SliverGrid>(find.byType(SliverGrid)).toList();
      expect(grids.first.delegate.estimatedChildCount, 6);
      final columns = (grids.first.gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount;
      expect(6 % columns, 0);
      await tester.scrollUntilVisible(find.byType(AdSection), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      final ad = tester.widget<AdSection>(find.byType(AdSection));
      expect(ad.placement, AdPlacement.memeLibraryMrec);
      expect(ad.contentCount, 8);
      expect(
          find.ancestor(
              of: find.byType(AdSection),
              matching: find.byType(SliverToBoxAdapter)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'filtered minimum and private library modes detach publisher slot',
      (tester) async {
    await showLibrary(tester, count: 6);
    final originalSlot = tester.element(find.byType(AdSection));
    final search = find.byType(TextField);
    await tester.enterText(search, 'Storm Boss');
    await tester.pumpAndSettle();
    expect(find.byType(AdSection), findsNothing);
    expect(originalSlot.mounted, isFalse);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byType(AdSection), findsOneWidget);
    final refreshedSlot = tester.element(find.byType(AdSection));
    await tester.tap(find.text('My Memes'));
    await tester.pumpAndSettle();
    expect(find.byType(AdSection), findsNothing);
    expect(refreshedSlot.mounted, isFalse);
    expect(find.textContaining('Your weather mischief starts here.'),
        findsOneWidget);
  });

  testWidgets('five actual publisher templates cannot create a slot',
      (tester) async {
    await showLibrary(tester, count: 5);
    expect(find.byType(AdSection), findsNothing);
  });

  Future<void> showRoasts(WidgetTester tester, int count,
      {bool actual = true, bool emptyText = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RoastHistoryList(
                    containsActualContent: actual,
                    roasts: List.generate(
                        count,
                        (i) => Roast(
                            id: 'real-$i',
                            personaId: 'karen',
                            weatherSnapshotId: 'weather-$i',
                            text: emptyText
                                ? ''
                                : 'Actual weather commentary number $i.',
                            category: 'weather',
                            createdAt: DateTime.utc(2026, 9, 17),
                            xpReward: 0)),
                    personas: const [],
                    onShareRoast: (_) {})))));
    await tester.pumpAndSettle();
  }

  testWidgets('roast minimum counts real complete text cards only',
      (tester) async {
    await showRoasts(tester, 3);
    expect(find.byType(AdSection), findsNothing);
    await showRoasts(tester, 4);
    final ad = tester.widget<AdSection>(find.byType(AdSection));
    expect(ad.placement, AdPlacement.roastsHistoryMrec);
    expect(ad.contentCount, 4);
    expect(
        tester.getTopLeft(find.byType(AdSection)).dy,
        greaterThan(tester
            .getTopLeft(find.text('Actual weather commentary number 3.'))
            .dy));
    await showRoasts(tester, 8, actual: false);
    expect(find.byType(AdSection), findsNothing);
    await showRoasts(tester, 8, emptyText: true);
    expect(find.byType(AdSection), findsNothing);
  });
}
