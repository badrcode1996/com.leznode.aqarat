import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../theme/app_colors.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _inputFill => AppColors.current.inputFill;

/// فرۆشتن / کرێ — the split applied to both Offers and Demands, in "My
/// Listings" and in the Global Market alike. On the Demands side the sale pill
/// reads کڕین, since a demand is someone looking to buy.
///
/// Deliberately slimmer than a [SegmentedButton]: both screens already stack a
/// segmented control underneath this one, and two identical-weight controls
/// would read as one confused group.
class DealFilterBar extends StatelessWidget {
  const DealFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.kind,
  });

  final DealKind selected;
  final ValueChanged<DealKind> onChanged;

  /// Which side of the app this bar sits on — decides the wording.
  final ListingKind kind;

  static const _icons = {
    DealKind.sale: Icons.sell_outlined,
    DealKind.rent: Icons.vpn_key_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _inputFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (final d in DealKind.values)
              Expanded(child: _pill(d, d == selected)),
          ],
        ),
      );

  Widget _pill(DealKind deal, bool active) => GestureDetector(
        onTap: () => onChanged(deal),
        // The gaps between pills must react to a tap too, otherwise the target
        // is visibly narrower than the pill it sits in.
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _primaryDarkBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icons[deal],
                  size: 17,
                  color: active ? Colors.white : AppColors.current.textMuted),
              const SizedBox(width: 6),
              Text(
                deal.labelFor(kind),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: active ? Colors.white : AppColors.current.textBody,
                ),
              ),
            ],
          ),
        ),
      );
}

/// The small "فرۆشتن" / "کرێ" tag shown on a listing card ("کڕین" / "کرێ" on a
/// demand card), so a card still says which side it belongs to once it is out
/// of its filtered list.
class DealBadge extends StatelessWidget {
  const DealBadge({super.key, required this.deal, required this.kind});

  final DealKind deal;
  final ListingKind kind;

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    final rent = deal == DealKind.rent;
    // Rent borrows the amber accent already used for demands; sale keeps the
    // brand blue, so the two never read as the same tag at a glance.
    final color = rent ? AppColors.current.warning : AppColors.current.textStrong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rent ? Icons.vpn_key_outlined : Icons.sell_outlined,
              size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            deal.labelFor(kind),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
