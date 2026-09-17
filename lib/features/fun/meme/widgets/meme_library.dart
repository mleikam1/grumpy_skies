import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../meme_catalog.dart';
import '../models/meme_document.dart';
import 'meme_inspector.dart';

class MemeLibrary extends StatefulWidget {
  const MemeLibrary(
      {super.key,
      required this.catalog,
      required this.drafts,
      required this.favorites,
      required this.onTemplate,
      required this.onDraft,
      required this.onFavorite,
      required this.onDelete,
      required this.onRemix,
      required this.onToday,
      required this.onSurprise,
      required this.onPhoto,
      required this.onBlank,
      required this.onImportBackup,
      required this.onCamera,
      required this.canCamera,
      this.exports = const []});
  final MemeCatalog catalog;
  final List<MemeDocument> drafts;
  final Set<String> favorites;
  final ValueChanged<MemeTemplate> onTemplate;
  final ValueChanged<MemeDocument> onDraft, onDelete, onRemix;
  final ValueChanged<String> onFavorite;
  final VoidCallback onToday,
      onSurprise,
      onPhoto,
      onBlank,
      onImportBackup,
      onCamera;
  final bool canCamera;
  final List<Map<String, dynamic>> exports;
  @override
  State<MemeLibrary> createState() => _MemeLibraryState();
}

class _MemeLibraryState extends State<MemeLibrary> {
  String _search = '', _filter = 'All', _section = 'Templates';
  @override
  Widget build(BuildContext context) {
    final templates = widget.catalog.templates
        .where((t) =>
            (t.name.toLowerCase().contains(_search.toLowerCase()) ||
                t.tags.any((s) => s.contains(_search.toLowerCase()))) &&
            (_filter == 'All' || t.tags.contains(_filter)) &&
            (_section != 'Favorites' || widget.favorites.contains(t.id)))
        .toList();
    final tags = widget.catalog.templates.expand((t) => t.tags).toSet().toList()
      ..sort();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('THE WEATHER HAS JOKES.',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Color(0xffffd76a))),
        const SizedBox(height: 8),
        const Text('Make the forecast\nyour punchline.',
            style: TextStyle(
                fontSize: 34, height: 1.08, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text(
            '15 original templates. 24 tiny troublemakers. All yours to remix.'),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
              onPressed: widget.onToday,
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('Make One for Today')),
          OutlinedButton.icon(
              onPressed: widget.onSurprise,
              icon: const Icon(Icons.shuffle),
              label: const Text('Surprise Me')),
          OutlinedButton.icon(
              onPressed: widget.onPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Upload Photo')),
          OutlinedButton.icon(
              onPressed: widget.onBlank,
              icon: const Icon(Icons.crop_square),
              label: const Text('Blank Canvas')),
          if (widget.canCamera)
            OutlinedButton.icon(
                onPressed: widget.onCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera')),
          TextButton.icon(
              onPressed: widget.onImportBackup,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import Project Backup')),
        ]),
        const SizedBox(height: 16),
        TextButton.icon(
            icon: const Icon(Icons.privacy_tip_outlined, size: 16),
            label: const Text('Local drafts • Storage & offline'),
            onPressed: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                        title: const Text('Your memes stay with you'),
                        content: const Text(kIsWeb
                            ? 'Saved in this browser. Browser storage can be cleared or evicted; keep a project backup. Offline editing needs the chosen images to be loaded first. A new browser session may need a connection to load the app and artwork.'
                            : 'Your photos and projects are saved privately on this device. Bundled templates work offline, including your first launch. Save a portable project backup to keep another copy.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Got it'))
                        ]))),
        const SizedBox(height: 24),
        Wrap(spacing: 8, children: [
          for (final section in ['Templates', 'Favorites', 'My Memes'])
            ChoiceChip(
                label: Text(section),
                selected: _section == section,
                onSelected: (_) => setState(() => _section = section))
        ]),
        const SizedBox(height: 16),
        if (_section != 'My Memes') ...[
          TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                  hintText: 'Find a template, weather, or mood',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 600
                  ? DropdownButtonFormField<String>(
                      initialValue: _filter,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Weather / topic'),
                      items: [
                        for (final tag in ['All', ...tags])
                          DropdownMenuItem(
                              value: tag, child: Text(tag.replaceAll('_', ' ')))
                      ],
                      onChanged: (tag) =>
                          setState(() => _filter = tag ?? 'All'))
                  : Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final tag in ['All', ...tags])
                        FilterChip(
                            label: Text(tag.replaceAll('_', ' ')),
                            selected: _filter == tag,
                            onSelected: (_) => setState(() => _filter = tag))
                    ])),
          const SizedBox(height: 20),
        ],
        if (_section == 'My Memes' && widget.drafts.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Text(
                  'Your weather mischief starts here.\nChoose a template or upload a photo; your editable drafts will appear here.')),
        if (_section != 'My Memes' && templates.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Text(
                  'No templates here yet. Try another filter or tap a heart to save a favorite.')),
      ])),
      if (_section != 'My Memes')
        SliverLayoutBuilder(builder: (context, c) {
          final cols = c.crossAxisExtent < 550
              ? 1
              : c.crossAxisExtent < 900
                  ? 2
                  : 3;
          return SliverGrid.builder(
              itemCount: templates.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  mainAxisExtent: c.crossAxisExtent / cols + 82),
              itemBuilder: (context, i) {
                final t = templates[i];
                return _TemplateCard(
                    template: t,
                    favorite: widget.favorites.contains(t.id),
                    onFavorite: () => widget.onFavorite(t.id),
                    onTap: () => widget.onTemplate(t));
              });
        }),
      SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.drafts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
              _section == 'My Memes'
                  ? 'Your saved projects'
                  : 'Pick up where you left off',
              style: Theme.of(context).textTheme.titleLarge),
          for (final d
              in widget.drafts.take(_section == 'My Memes' ? 10000 : 3))
            Card(
                child: ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: Text(d.name),
                    subtitle: Text(
                        '${d.layout.label} • ${d.updatedAt.toLocal().toString().split('.').first}'),
                    onTap: () => widget.onDraft(d),
                    trailing: PopupMenuButton<String>(
                        onSelected: (v) => v == 'delete'
                            ? widget.onDelete(d)
                            : widget.onRemix(d),
                        itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'remix',
                                  child: Text('Duplicate / Remix')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete draft'))
                            ]))),
        ],
        if (_section == 'My Memes' && widget.exports.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Recent exports'),
          for (final e in widget.exports.take(10))
            ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text('${e['fileName']}'),
                subtitle:
                    Text('${e['width']} × ${e['height']} • ${e['createdAt']}')),
        ],
        const SizedBox(height: 40),
      ])),
    ]);
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard(
      {required this.template,
      required this.favorite,
      required this.onTap,
      required this.onFavorite});
  final MemeTemplate template;
  final bool favorite;
  final VoidCallback onTap, onFavorite;
  @override
  Widget build(BuildContext context) => Material(
      color: memeCream,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Column(children: [
            Expanded(
                child: Semantics(
                    label:
                        '${template.name}. ${template.defaultCaption.top} ${template.defaultCaption.bottom}',
                    button: true,
                    child: LayoutBuilder(
                        builder: (context, c) =>
                            Stack(fit: StackFit.expand, children: [
                              Image.asset(template.thumbnailPath,
                                  fit: BoxFit.contain, cacheWidth: 480),
                              for (final zone in template.safeTextZones)
                                Positioned(
                                    left: zone.x * c.maxWidth,
                                    top: zone.y * c.maxHeight,
                                    width: zone.width * c.maxWidth,
                                    height: zone.height * c.maxHeight,
                                    child: Center(
                                        child: Text(
                                            zone.role == 'top'
                                                ? template.defaultCaption.top
                                                : template
                                                    .defaultCaption.bottom,
                                            textAlign: TextAlign.center,
                                            textScaler: TextScaler.noScaling,
                                            style: TextStyle(
                                                fontFamily: 'MemeSans',
                                                fontSize: c.maxWidth * .049,
                                                fontWeight: FontWeight.w900,
                                                height: 1.05,
                                                color: memeInk)))),
                            ])))),
            Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(template.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, color: memeInk)),
                        const Text('CURATED • TAP TO REMIX',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff527081),
                                letterSpacing: 1))
                      ])),
                  IconButton(
                      onPressed: onFavorite,
                      tooltip:
                          favorite ? 'Remove favorite' : 'Favorite template',
                      icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                          color: const Color(0xffad3f61)))
                ])),
          ])));
}
