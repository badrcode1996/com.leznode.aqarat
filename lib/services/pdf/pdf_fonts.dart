/// Single source of truth for the font used by every generated PDF
/// (contracts, receipts, exports).
///
/// Rabar — a Kurdish font — is used because it positions Kurdish-specific
/// letters (especially ێ) correctly AND subsets cleanly in the `pdf` package.
/// It ships as a single weight, so bold text reuses the same file (headings
/// stand out by size/colour instead). Earlier alternatives: SPEDA renders ێ
/// well but crashes the TTF subsetter on full documents (the "²" in "م²");
/// Vazirmatn (Persian) subsets cleanly but mis-positions ێ. Swap both paths
/// here to change every PDF at once.
const String pdfFontRegular = 'assets/fonts/Rabar.ttf';
const String pdfFontBold = 'assets/fonts/Rabar.ttf';
