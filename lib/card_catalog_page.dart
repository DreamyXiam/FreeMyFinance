import 'package:flutter/material.dart';

import 'be_ui.dart';
import 'card_catalog.dart';

class CardCatalogPage extends StatefulWidget {
  const CardCatalogPage({super.key});
  @override
  State<CardCatalogPage> createState() => _CardCatalogPageState();
}

class _CardCatalogPageState extends State<CardCatalogPage> {
  late final Future<CardCatalog> _catalog = CardCatalog.load();
  final filters = <CardField, String>{};
  String query = '';
  Future<void> _choose(CardCatalog catalog, CardField field) async {
    final options = catalog.options(field, filters);
    var search = '';
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final shown = options
              .where(
                (v) => ('$v ${cardFieldDisplay(field, v)}')
                    .toLowerCase()
                    .contains(search.trim().toLowerCase()),
              )
              .toList();
          final inset = MediaQuery.viewInsetsOf(ctx).bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: SizedBox(
                height: (MediaQuery.sizeOf(ctx).height - inset) * .68,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择${field.label}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              labelText: '搜索${field.label}',
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (v) => setSheet(() => search = v),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: const Text('全部'),
                      onTap: () => Navigator.pop(ctx, ''),
                    ),
                    Expanded(
                      child: shown.isEmpty
                          ? const Center(child: Text('没有匹配选项'))
                          : ListView.builder(
                              itemCount: shown.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text(cardFieldDisplay(field, shown[i])),
                                trailing: filters[field] == shown[i]
                                    ? const Icon(Icons.check, color: beBlue)
                                    : null,
                                onTap: () => Navigator.pop(ctx, shown[i]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (choice != null && mounted) {
      setState(() {
        if (choice.isEmpty) {
          filters.remove(field);
        } else {
          filters[field] = choice;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('选择卡面'),
      actions: [
        TextButton(
          onPressed: () => setState(() => filters.clear()),
          child: const Text('重置筛选'),
        ),
      ],
    ),
    body: FutureBuilder<CardCatalog>(
      future: _catalog,
      builder: (context, s) {
        if (s.hasError) return const Center(child: Text('卡面目录读取失败'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final catalog = s.data!;
        final cards = catalog.filter(filters, query: query);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '搜索卡名称或发行方',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: CardField.values
                          .map(
                            (f) => ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width - 40,
                              ),
                              child: ActionChip(
                                label: Text(
                                  filters[f] == null
                                      ? f.label
                                      : '${f.label}：${cardFieldDisplay(f, filters[f]!)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                avatar: Icon(
                                  filters[f] == null ? Icons.tune : Icons.check,
                                  size: 15,
                                ),
                                onPressed: () => _choose(catalog, f),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${cards.length} 张卡面 · 图片来源 AirCards',
                      style: const TextStyle(color: beMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            if (cards.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('没有匹配的卡面，请调整筛选条件。')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverLayoutBuilder(
                  builder: (context, c) {
                    final columns = c.crossAxisExtent >= 650 ? 3 : 2;
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final a = cards[i];
                        return _CardTile(
                          card: a,
                          onTap: () => Navigator.pop(context, a),
                        );
                      }, childCount: cards.length),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent:
                            (c.crossAxisExtent - (columns - 1) * 10) /
                                columns /
                                1.586 +
                            78 *
                                MediaQuery.textScalerOf(context)
                                    .scale(1)
                                    .clamp(1.0, 1.6),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _CardTile extends StatelessWidget {
  final CardArtwork card;
  final VoidCallback onTap;
  const _CardTile({required this.card, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: beBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.586,
              child: Image.network(
                card.previewUrl,
                fit: BoxFit.cover,
                cacheWidth: 400,
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : const ColoredBox(
                        color: beSurface,
                        child: Center(
                          child: Icon(Icons.credit_card, color: beMuted),
                        ),
                      ),
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: beSurface,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, color: beMuted),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: beInk,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${card.issuer} · ${card.country}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: beMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
