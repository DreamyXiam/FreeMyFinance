import 'package:flutter/material.dart';

class CategorySwipeTile extends StatefulWidget {
  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CategorySwipeTile({
    super.key,
    required this.name,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CategorySwipeTile> createState() => _CategorySwipeTileState();
}

class _CategorySwipeTileState extends State<CategorySwipeTile> {
  static const editThreshold = 42.0;
  static const deleteThreshold = 128.0;
  double offset = 0;
  bool dragging = false;

  void finish() {
    final action = offset <= -deleteThreshold
        ? widget.onDelete
        : offset <= -editThreshold
        ? widget.onEdit
        : null;
    setState(() {
      dragging = false;
      offset = 0;
    });
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final deleting = offset <= -deleteThreshold;
    final editing = offset <= -editThreshold;
    final color = deleting
        ? const Color(0xFFE14B4B)
        : editing
        ? const Color(0xFF159F73)
        : const Color(0xFFE7F5EF);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => dragging = true),
          onHorizontalDragUpdate: (details) => setState(() {
            offset = (offset + details.delta.dx).clamp(-170.0, 0.0);
          }),
          onHorizontalDragEnd: (_) => finish(),
          onHorizontalDragCancel: finish,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  key: Key('swipe-reveal-${widget.name}'),
                  duration: dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  decoration: BoxDecoration(color: color),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        deleting ? Icons.delete_outline : Icons.arrow_back,
                        color: editing ? Colors.white : const Color(0xFF159F73),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        deleting ? '删除' : '编辑',
                        style: TextStyle(
                          color: editing
                              ? Colors.white
                              : const Color(0xFF159F73),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(offset, 0, 0),
                decoration: const BoxDecoration(color: Colors.white),
                child: ListTile(
                  title: Text(widget.name),
                  trailing: IconButton(
                    tooltip: '重命名分类',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onEdit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
