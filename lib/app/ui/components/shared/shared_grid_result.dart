import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'list_page_config.dart';

class SharedGridResult<T> extends StatelessWidget {
  final bool isLoading;
  final List<T> data;
  final ListPageConfig config;
  final VoidCallback onClearFilter;
  // Builder pattern: Biarkan parent menentukan cara menggambar kartunya
  final Widget Function(BuildContext context, T item) itemBuilder;

  const SharedGridResult({
    super.key,
    required this.isLoading,
    required this.data,
    required this.config,
    required this.onClearFilter,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- EMPTY STATE ---
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            Text(config.emptyTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(config.emptySubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onClearFilter,
              child: const Text('Hapus Semua Filter'),
            )
          ],
        ),
      );
    }

    // --- GRID RESULT ---
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return MasonryGridView.count(
      crossAxisCount: isDesktop ? (MediaQuery.of(context).size.width < 1200 ? 1 : 2) : 1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
      itemCount: data.length,
      itemBuilder: (context, index) => itemBuilder(context, data[index]),
    );
  }
}