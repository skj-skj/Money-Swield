import 'package:material_ui/material_ui.dart';

/// A list that reads its next page as it nears its end: Home, the Photos
/// screen and Upcoming payments. The list scrolls with [pagingScroll];
/// [loadMore] is called once fewer than [loadMoreLead] pixels are left
/// below it.
mixin ScrollPaging<T extends StatefulWidget> on State<T> {
  final pagingScroll = ScrollController();

  /// How close to the end the next page is asked for.
  double get loadMoreLead;

  /// Asks for the next page; called again while it loads, so it must
  /// ignore a call it can't serve.
  void loadMore();

  @override
  void initState() {
    super.initState();
    pagingScroll.addListener(maybeLoadMore);
  }

  @override
  void dispose() {
    pagingScroll.dispose();
    super.dispose();
  }

  void maybeLoadMore() {
    if (pagingScroll.hasClients &&
        pagingScroll.position.extentAfter < loadMoreLead) {
      loadMore();
    }
  }

  /// After this frame: a short first page may not fill the screen, and
  /// then no scroll would ever ask for the next one.
  void loadMoreAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeLoadMore();
      });
}
