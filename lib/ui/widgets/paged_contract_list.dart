import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';

/// A contract list that loads a page at a time and asks for the next one as the
/// user nears the bottom.
///
/// The screens using this used to bind to a stream of EVERY contract the
/// company owns, on every open, on every device. That is fine at fifty
/// contracts and ruinous at ten thousand — the download, the Firestore bill and
/// the phone's memory all scale with the whole book rather than with what is on
/// screen.
///
/// Loading is triggered from a scroll listener rather than by building a
/// sentinel widget at the end of the list, so it fires slightly BEFORE the user
/// reaches the bottom and the next page is usually already there.
class PagedContractList extends ConsumerStatefulWidget {
  const PagedContractList({
    super.key,
    required this.type,
    required this.itemBuilder,
    required this.empty,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    this.separator = const SizedBox(height: 10),
    this.filter,
  });

  /// Which contract type to page through, or null for both.
  final ContractType? type;

  final Widget Function(Contract contract) itemBuilder;

  /// Shown when the first page comes back with nothing.
  final Widget empty;

  final EdgeInsets padding;
  final Widget separator;

  /// Optional client-side narrowing WITHIN the loaded pages — for a search box,
  /// say. It cannot reach contracts that have not been loaded yet, so it is a
  /// refinement of what is on screen, not a substitute for a query.
  final bool Function(Contract contract)? filter;

  @override
  ConsumerState<PagedContractList> createState() => _PagedContractListState();
}

class _PagedContractListState extends ConsumerState<PagedContractList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Roughly two screens of runway, so the fetch overlaps the scroll instead
    // of interrupting it.
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) {
      ref.read(pagedContractsProvider(widget.type).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    final paged = ref.watch(pagedContractsProvider(widget.type));
    final items = widget.filter == null
        ? paged.items
        : paged.items.where(widget.filter!).toList();

    if (items.isEmpty) {
      // Still on the very first page — a spinner, not "nothing here".
      if (paged.loading) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.current.textStrong),
        );
      }
      return widget.empty;
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(pagedContractsProvider(widget.type).notifier).refresh(),
      child: ListView.separated(
        controller: _scroll,
        padding: widget.padding,
        // One extra row for the tail spinner while another page is in flight.
        itemCount: items.length + (paged.loading ? 1 : 0),
        separatorBuilder: (_, __) => widget.separator,
        itemBuilder: (_, i) {
          if (i >= items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.current.textStrong),
                ),
              ),
            );
          }
          return widget.itemBuilder(items[i]);
        },
      ),
    );
  }
}
