/// Single source of truth for the font used by every generated PDF
/// (contracts, receipts, exports).
///
/// Amiri (OFL, a traditional Naskh face) is used because it positions
/// Kurdish-specific letters — especially ێ — correctly AND subsets cleanly in
/// the `pdf` package. The app UI font SPEDA renders ێ well too but crashes the
/// TTF subsetter on full documents (e.g. the "²" in "م²"); Vazirmatn (Persian)
/// subsets cleanly but mis-positions ێ. Swap both paths here to change every
/// PDF at once.
const String pdfFontRegular = 'assets/fonts/Amiri-Regular.ttf';
const String pdfFontBold = 'assets/fonts/Amiri-Bold.ttf';
