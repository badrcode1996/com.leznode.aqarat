"use strict";
// Auto-extracted from lib/models/contract_template_model.dart — keep in sync.
const RENT_CLAUSES = [
  "لایەنی یەکەم ڕەزامەندە لەسەر بەکرێدانی موڵکی دیاریکراوی سەرەوە بە لایەنی دووەم بۆ ماوەی ({period_months}) مانگ.",
  "هەردوو لایەن ڕەزامەندن لەسەر کرێی مانگانە بە بڕی ({rent_amount}) {rent_amount_words} {currency}.",
  "ئەم گرێبەستە دەست پێدەکات لە بەرواری: {start_date} تاکو {end_date}.",
  "لایەنی دووەم بڕی ({down_payment}) {down_payment_words} دەداتە لایەنی یەکەم وەک پێشەکی {down_payment_months} مانگ و دوای پێشەکی کرێیەکە بەمشێوەیە دەدریێت: {payment_frequency} مانگ جارێک.",
  "لایەنی دووەم لەسەریەتی بڕی ({guarantee}) {guarantee_words} وەک دڵنیایی دابنێ لای {company}، کە لە دوای ڕادەستکردنەوەی موڵکەکە بە لایەنی یەکەم بێ هیچ کەم و کوڕییەک دەدرێتەوە بە لایەنی دووەم.",
  "لایەنی دووەم ئەم موڵکە بەکاردێنێت بۆ مەبەستی {purpose}، بە پێچەوانەوە بۆ هەر مەبەستێکی تر پێویستە ڕەزامەندی {company} و لایەنی یەکەم وەربگرێت.",
  "لایەنی دووەم بۆی نیە داوای کلیلی موڵکەکە بکات تا ڕێپێدانی ئاسایش وەرنەگرێت، گەر لە ماوەی {grace_period} ڕۆژ نەیتوانی ڕێپێدان لە لایەنی پەیوەندیدار وەربگرێت گرێبەستەکە ڕاستەوخۆ هەڵدەوەشێتەوە و پارەکان دەگەڕێتەوە بۆ لایەنی دووەم.",
  "لایەنی دووەم پێش ڕاخستنی (تاثیث) موڵکەکە پێویستە لەسەر ئەستۆی خۆی قوفڵی دەرگا دەرەکیەکان بگۆڕێت، بەپێچەوانەوە هەر کێشەیەک ڕووبدات خۆی بەرپرسیارە لێی.",
  "دوای تەواو بوونی ماوەی گرێبەستەکە ئەگەر لایەنی دووەم پابەند نەبوو بە چۆڵکردنی موڵکەکە یان نوێکردنەوەی ئەم گرێبەستە ئەوا پابەند دەکرێت بە دانێ بڕی ({late_fee}) {late_fee_words} {currency} بۆ هەر ڕۆژێک دواکەوتن، تاکوو گرێبەستەکە یەکلایی دەبێتەوە.",
  "خزمەتگوزاری ئاو کارەبا و هەرخزمەتگوزاریەکی تر پەیوەندی بەم موڵکە هەبێت لە ماوەی جێبەجێکردنی ئەم گرێبەستە لە ئەستۆی لایەنی دووەمە.",
  "هەر گۆڕانکاریەک لەبەشی دەرەوە و ناوەوەی ئەم موڵکە بکرێت دەبێ بەڕەزامەندی لایەنی یەکەم {company} بکرێت، وە لایەنی یەکەم تەنها لەو تێچووانە بەرپرسە کە ئەنجام دەدرێت لە چاککردنەوەی کەم و کوڕیەک یان گۆڕانکاریەکی پێویست لە موڵکەکەدا بە پێچەوانەوە هەر گۆڕانکاریەکی جوانکاری و ناپێویست بۆ موڵکەکە بکرێت دەکەوێتە ئەستۆی لایەنی دووەم.",
  "لایەنی دووەم بە هیچ شێوەیەک بۆی نیە ئەم موڵکە (هەمووی یان بەشێکی) بەکرێ بداتەوە لایەنی تر بە بێ ئاگادارکردنەوەی {company} و ڕەزامەندی لایەنی یەکەم.",
  "ئەگەر لایەنی یەکەم موڵکەکەی فرۆشت ئەوا لایەنی دووەم بۆی هەیە لە ناو موڵکەکەی بمێنێتەوە تا کۆتایی وادەی گرێبەستەکە، وە خاوەنە نوێیەکەش پابەند دەبێت بە ناوەڕۆکی ئەم گرێبەستە.",
  "ئەگەر لایەنی دووەم پێش کۆتایی هاتنی گرێبەستەکە زووتر دەرچوو لە موڵکەکە، {company} هاوکار دەبێ بۆ گێڕانەوەی (بەشێک یان هەموو) کرێی ماوەی چۆڵکردنی موڵکەکە، ئەگەر بەکرێدرایەوە لەلایەن {company}.",
  "ئەگەر موڵکەکە ڕاخراو (مؤثث) بوو ئەوا لەسەر لایەنی یەکەم پێویستە لیستی کەلوپەلەکانی ناو موڵکەکە ئامادە بکات وە لە لایەن لایەنی دووەم چێک بکرێتەوە و دواتر واژۆ بکرێت و هاوپێچ بکرێت بەم گرێبەستە.",
  "لایەنی دووەم پێویستە پارێزگاری لە کەلوپەلەکان بکات و لەکاتی دەرچوونی وەک خۆی ڕادەستی لایەنی یەکەمی بکاتەوە، بەپێچەوانەوە لایەنی دووەم بەرپرسە لە چاککردنەوە یان گۆڕینی لەسەر ئەرکی خۆی.",
  "لایەنی یەکەم دەبێت پێش بە کرێدانی موڵکەکە ئەستۆپاکی بۆ موڵکەکە بکات و پارەی کرێی ئاو و کارەبا هەر خزمەتگوزاریەکی تر بدات کە پەیوەندی بە موڵکەکە هەبێت، وە بەرپرسە لە چاککردنەوەی هەر کەم و کوڕیەک کە پەیوەندی بە ژێرخانی موڵکەکە بێت.",
  "لەکاتی هاتنی کرێیەکە پێویستە لایەنی یەکەم بە زووترین کات بێتە {company} و کرێیەکە وەربگرێت، بە پێچەوانەوە پارەکە دەخرێتە ناو حساب بانکی {company} دواتر بە چەک بۆی سەرف دەکرێت.",
  "هەریەک لە لایەنی یەکەم و دووەم پێویستە بڕی کرێی نیو مانگ بۆ هەر ساڵێک بدەن بە {company} لەجیاتی کرێی ڕێکخستنی ئەم گرێبەستە.",
  "لایەنی دووەم لەسەریەتی (مانگێک) پێش وادەی کۆتایی هاتنی گرێبەستەکە، ئاگاداری {company} بکاتەوە ئەگەر نیازی نوێکردنەوە یان چۆڵکردنی موڵکەکەی هەبوو، بە پێچەوانەوە کرێی (مانگێک) دەکەوێتە ئەستۆی لایەنی دووەم.",
  "پێش چۆڵکردنی موڵکەکە لایەنی دووەم لەسەریەتی چۆن موڵکەکەی وەرگرتووە وەک خۆی بێ کەم و کوڕی ڕادەستی لایەنی یەکەم بکاتەوە، بە پێچەوانەوە بەرپرسە لە چاکردنەوەی کەم و کوڕیەکان بە زووترین کات، وە ئەستۆپاکی بۆ موڵکەکە بکات و پارەی کرێی ئاو و کارەبا هەر خزمەتگوزاریەکی تر بدات کە پەیوەندی بە موڵکەکە هەبێت.",
  "دوای کۆتایی هاتنی وادەی گرێبەستەکە، ئەم گرێبەستە نوێ دەکرێتەوە بە نرخی ڕۆژ بە ڕەزامەندی هەردوولا بە نێوەندگیری {company} بۆ نرخ دانان و شێوازی کرێدانەکە، یان موڵکەکە چۆڵدەکرێت و ڕادەستی خاوەنەکەی دەکرێتەوە.",
  "لە کاتی نوێکردنەوەی گرێبەستەکە هەر یەکێک لە دوولایەنەکە پابەند دەبێت بە پێدانی کرێی نیو مانگ بۆ یەک ساڵ بە {company}.",
  "لەسەر لایەنی دووەم پێویستە موڵکەکە بۆ ئەو مەبەستە بەکاربهێنێت کە لەسەری ڕێکەوتوون، کە نەبێتە مایەی ئەزیەت و ئازار بۆ هاوسێیەکانی، بە پێچەوانەوە بەرپرسیار دەبێت بەرامبەر یاسا و گرێبەستەکە هەڵدەوەشێتەوە.",
  "لەکاتی چارەسەر نەبوونی کێشەی نێوان دوو لایەنەکە (ئەگەر هەبوو) {company} بەرپرس نیە و کێشەکە دەبردرێتە دادگا بۆ چارەسەرکردنی بە شاهێدی کارمەندانی بەرپرس.",
  "ئەگەر لایەنی یەکەم خۆی کڕیی وەرگرت لە کرێچی ئەوا {company} بەرپرس نیە لە هیچ جۆرە کێشەیەک.",
];

// Arabic edition of the same clauses. A DRAFT translation pending review by
// the company's lawyer — the wording, not the structure, is what needs
// checking. Clause order and {token} placement mirror RENT_CLAUSES exactly, so
// the two editions stay comparable line by line.
const RENT_CLAUSES_AR = [
  "يوافق الطرف الأول على تأجير العقار الموصوف أعلاه إلى الطرف الثاني لمدة ({period_months}) شهراً.",
  "اتفق الطرفان على أن يكون بدل الإيجار الشهري مبلغ {rent_amount} {currency}.",
  "يبدأ سريان هذا العقد من تاريخ: {start_date} ولغاية {end_date}.",
  "يدفع الطرف الثاني إلى الطرف الأول مبلغ {down_payment} كمقدَّم عن ({down_payment_months}) شهراً، وبعد المقدَّم يُدفع الإيجار كل ({payment_frequency}) شهراً.",
  "على الطرف الثاني أن يودع مبلغ {guarantee} لدى {company} كتأمينات، تُعاد إليه بعد تسليم العقار إلى الطرف الأول خالياً من أي نقص أو ضرر.",
  "يستخدم الطرف الثاني هذا العقار لغرض {purpose}، وأي استخدام لغير هذا الغرض يستوجب موافقة {company} والطرف الأول.",
  "ليس للطرف الثاني المطالبة بمفاتيح العقار قبل حصوله على موافقة الأمن، وإذا لم يتمكن من الحصول على الموافقة خلال {grace_period} يوماً يُفسخ العقد تلقائياً وتُعاد المبالغ إلى الطرف الثاني.",
  "على الطرف الثاني قبل تأثيث العقار تبديل أقفال الأبواب الخارجية على نفقته الخاصة، وبخلافه يتحمل مسؤولية أي مشكلة تحدث.",
  "بعد انتهاء مدة العقد، إذا لم يلتزم الطرف الثاني بإخلاء العقار أو تجديد هذا العقد، يلتزم بدفع مبلغ {late_fee} {currency} عن كل يوم تأخير لحين حسم العقد.",
  "تقع خدمات الماء والكهرباء وأي خدمة أخرى تتعلق بهذا العقار خلال مدة تنفيذ هذا العقد على عاتق الطرف الثاني.",
  "أي تغيير في القسم الخارجي أو الداخلي من هذا العقار يجب أن يتم بموافقة الطرف الأول و{company}، ولا يتحمل الطرف الأول إلا التكاليف الناشئة عن إصلاح نقص أو تغيير ضروري في العقار، أما أي تغيير تجميلي أو غير ضروري فيقع على عاتق الطرف الثاني.",
  "لا يحق للطرف الثاني بأي شكل من الأشكال تأجير هذا العقار (كله أو جزء منه) إلى طرف آخر دون إشعار {company} وموافقة الطرف الأول.",
  "إذا باع الطرف الأول العقار، يحق للطرف الثاني البقاء في العقار حتى نهاية مدة العقد، ويلتزم المالك الجديد بمضمون هذا العقد.",
  "إذا أخلى الطرف الثاني العقار قبل انتهاء مدة العقد، تساعد {company} في إعادة (جزء أو كل) إيجار المدة المتبقية بعد إخلاء العقار، إذا أُعيد تأجيره من قبل {company}.",
  "إذا كان العقار مؤثثاً، فعلى الطرف الأول إعداد قائمة بمحتويات العقار، يدققها الطرف الثاني ثم توقَّع وتُرفق بهذا العقد.",
  "على الطرف الثاني المحافظة على المحتويات وتسليمها إلى الطرف الأول عند الإخلاء كما استلمها، وبخلافه يكون مسؤولاً عن إصلاحها أو تبديلها على نفقته.",
  "على الطرف الأول قبل تأجير العقار تسوية ذمة العقار ودفع أجور الماء والكهرباء وأي خدمة أخرى تتعلق بالعقار، ويكون مسؤولاً عن إصلاح أي نقص يتعلق ببنية العقار.",
  "عند حلول موعد الإيجار، على الطرف الأول الحضور إلى {company} في أقرب وقت لاستلام بدل الإيجار، وبخلافه يُودع المبلغ في الحساب المصرفي لـ{company} ثم يُصرف له بصك.",
  "على كل من الطرف الأول والطرف الثاني دفع بدل نصف شهر عن كل سنة إلى {company} مقابل أجور تنظيم هذا العقد.",
  "على الطرف الثاني إشعار {company} قبل (شهر) من موعد انتهاء العقد برغبته في التجديد أو إخلاء العقار، وبخلافه يتحمل الطرف الثاني بدل إيجار (شهر).",
  "قبل إخلاء العقار، على الطرف الثاني تسليمه إلى الطرف الأول كما استلمه دون نقص، وبخلافه يكون مسؤولاً عن إصلاح النواقص في أقرب وقت، وعليه تسوية ذمة العقار ودفع أجور الماء والكهرباء وأي خدمة أخرى تتعلق بالعقار.",
  "بعد انتهاء مدة العقد، يُجدَّد هذا العقد بسعر اليوم بموافقة الطرفين وبوساطة {company} في تحديد السعر وطريقة الدفع، أو يُخلى العقار ويُسلَّم إلى مالكه.",
  "عند تجديد العقد يلتزم كل من الطرفين بدفع بدل إيجار نصف شهر عن سنة واحدة إلى {company}.",
  "على الطرف الثاني استخدام العقار للغرض المتفق عليه، وبما لا يسبب أذى أو إزعاجاً لجيرانه، وبخلافه يكون مسؤولاً أمام القانون ويُفسخ العقد.",
  "في حال عدم حل الخلاف بين الطرفين (إن وُجد)، لا تتحمل {company} أي مسؤولية، ويُحال الخلاف إلى المحكمة لحسمه بشهادة الموظفين المسؤولين.",
  "إذا استلم الطرف الأول بدل الإيجار من المستأجر بنفسه، فلا تتحمل {company} أي مسؤولية عن أي مشكلة.",
];

const SALE_CLAUSES_AR = [
  "أُبرم هذا العقد لغرض بيع العقار المشار إليه أعلاه، والعائدة ملكيته إلى الطرف الأول، إلى الطرف الثاني بمبلغ {total_price} {currency}، وقد أبدى الطرفان موافقتهما التامة على ذلك.",
  "تستلم {company} مبلغ {down_payment} {currency} كعربون نيابة عن الطرف الأول.",
  "يُدفع المبلغ المتبقي وفق الآتي: {payment_method}",
  "على الطرف الأول تسليم هذا العقار إلى الطرف الثاني بتاريخ {delivery_date} بعد استيفائه المستحقات المالية.",
  "إذا لم يسلّم الطرف الأول العقار إلى الطرف الثاني في التاريخ المحدد، يلتزم بدفع مبلغ {late_fee} {currency} عن كل يوم تأخير.",
  "إذا نكل أي من الطرفين عن هذا العقد لأي سبب، يلتزم بدفع مبلغ {withdrawal} {currency} إلى الطرف الآخر دون حاجة إلى إنذار رسمي.",
  "رسوم البيع والتسجيل والإفراز والدمج والتصحيح وضريبة العقار تقع على الطرف الأول وفق القانون إذا كان العقار مسجلاً في الطابو، وإن لم يكن مسجلاً يلتزم الطرف الأول بدفع بدل تسجيله بإسمه.",
  "رسوم الكشف وتسجيل العقار تقع على الطرف الثاني وفق القانون إذا كان العقار مسجلاً في الطابو، وإن لم يكن مسجلاً يلتزم الطرف الثاني بدفع بدل التسجيل.",
  "على الطرف الأول تخويل المحامي {lawyer} بوكالة خاصة بهذا العقار لدى دائرة الكاتب العدل لغرض متابعة المعاملات وتسجيله بإسم الطرف الثاني لدى مديرية التسجيل العقاري.",
  "على الطرف الأول دفع ما نسبته ١٪ من سعر العقار الموصوف أعلاه إلى {company} مقابل بيع هذا العقار.",
  "على الطرف الثاني دفع ما نسبته ١٪ من سعر العقار الموصوف أعلاه إلى {company} مقابل شراء هذا العقار.",
];

// English edition of the same clauses. Like the Arabic set, this is a DRAFT
// translation: it says what the Kurdish says, but the wording has not been
// through a lawyer. A company issuing English contracts should have its own
// counsel read these once and edit them in the template.
const RENT_CLAUSES_EN = [
  "The first party agrees to let the property described above to the second party for a term of ({period_months}) months.",
  "Both parties agree a monthly rent of ({rent_amount}) {rent_amount_words} {currency}.",
  "This contract runs from {start_date} until {end_date}.",
  "The second party pays ({down_payment}) {down_payment_words} to the first party in advance for {down_payment_months} months; thereafter the rent is paid every {payment_frequency} months.",
  "The second party shall lodge ({guarantee}) {guarantee_words} with {company} as a deposit, returnable to the second party once the property has been handed back to the first party in good order.",
  "The second party shall use the property for {purpose}. Any other use requires the consent of {company} and of the first party.",
  "The second party may not ask for the keys before security clearance has been granted. If clearance cannot be obtained from the authority concerned within {grace_period} days, this contract is dissolved forthwith and the monies are returned to the second party.",
  "Before furnishing the property, the second party shall change the locks on the external doors at their own cost; failing that, they are answerable for anything that follows.",
  "If, at the end of the term, the second party neither vacates the property nor renews this contract, they shall pay ({late_fee}) {late_fee_words} {currency} for each day of delay until the matter is settled.",
  "Water, electricity and any other service connected to the property are the second party's charge for the duration of this contract.",
  "Any alteration to the property, inside or out, requires the consent of the first party and of {company}. The first party bears only the cost of repairing a defect or of a change the property requires; any decorative or unnecessary change is at the second party's cost.",
  "The second party may not sublet the property, in whole or in part, without notice to {company} and the consent of the first party.",
  "If the first party sells the property, the second party may remain until the end of the term, and the new owner is bound by this contract.",
  "If the second party leaves before the term ends, {company} will assist in recovering part or all of the rent for the unoccupied period, should the property be let again through {company}.",
  "If the property is furnished, the first party shall draw up an inventory of its contents, to be checked by the second party, signed, and attached to this contract.",
  "The second party shall keep the contents in good order and return them as received on leaving; failing that, the second party bears the cost of repair or replacement.",
  "Before letting the property, the first party shall clear it of any liability and settle the water, electricity and other service accounts attaching to it, and is answerable for repairing any defect in the fabric of the property.",
  "When the rent falls due, the first party shall attend {company} promptly to collect it; failing that, the sum is paid into {company}'s bank account and released to them by cheque.",
  "The first party and the second party shall each pay {company} half a month's rent for each year, as the fee for arranging this contract.",
  "The second party shall give {company} one month's notice before the end of the term of an intention to renew or to vacate; failing that, one month's rent falls to the second party.",
  "Before vacating, the second party shall return the property to the first party as received and in good order; failing that, they are answerable for putting right any defect without delay, and shall clear the property of liability and settle the water, electricity and other service accounts attaching to it.",
  "At the end of the term this contract may be renewed at the rate of the day, by agreement of both parties and with {company} mediating on the rent and the manner of payment; otherwise the property is vacated and returned to its owner.",
  "On renewal, each of the two parties shall pay {company} half a month's rent for the year.",
  "The second party shall use the property for the purpose agreed, and in a manner that causes no harm or nuisance to the neighbours; failing that, they answer before the law and this contract is dissolved.",
  "Should a dispute between the two parties not be settled, {company} bears no responsibility, and the matter goes to court to be decided on the testimony of the responsible staff.",
  "If the first party collects the rent from the tenant directly, {company} bears no responsibility for any difficulty arising.",
];

const SALE_CLAUSES_EN = [
  "This contract is made for the sale of the property described above, owned by the first party, to the second party at a price of ({total_price}) {total_price_words} {currency}, to which both parties have given their full consent.",
  "{company} receives ({down_payment}) {down_payment_words} {currency} as a deposit on behalf of the first party.",
  "The balance is paid as follows: {payment_method}",
  "The first party shall hand the property to the second party on {delivery_date}, once the sums due have been received.",
  "If the first party does not hand the property to the second party on the date set, they shall pay ({late_fee}) {late_fee_words} {currency} for each day of delay.",
  "If either party withdraws from this contract for any reason, they shall pay ({withdrawal}) {withdrawal_words} {currency} to the other party, without need of formal notice.",
  "The fees for sale, transfer, partition, merger, correction and property tax fall to the first party under the law where the property is registered; where it is not registered, the first party shall pay the cost of registering it in their own name.",
  "The fees for survey and registration fall to the second party under the law where the property is registered; where it is not registered, the second party shall pay the cost of registration.",
  "The first party shall grant the lawyer {lawyer} a special power of attorney for this property before the notary public, for the purpose of pursuing the formalities and registering it in the name of the second party at the land registry.",
  "The first party shall pay {company} 1% of the price of the property described above, for the sale of this property.",
  "The second party shall pay {company} 1% of the price of the property described above, for the purchase of this property.",
];

/**
 * Headings a template may still carry from before a rename. A stored title
 * always wins over the default, so a company that had ever saved its template
 * kept the old wording forever — these are treated as unset instead. Mirrored
 * in `lib/models/contract_template_model.dart` (legacyTitles), which the app's
 * own preview reads — both must list the same strings. Drop an entry once
 * every template has been re-saved.
 */
const LEGACY_TITLES = ["گرێبەستی کڕین و فرۆشتن", "عقد بيع وشراء"];

const DEFAULTS = {
  rent_title: "گرێبەستی کرێ",
  sale_title: "گرێبەستی فرۆشتن",
  rent_title_ar: "عقد إيجار",
  sale_title_ar: "عقد بيع",
  rent_title_en: "Tenancy Agreement",
  sale_title_en: "Sale Agreement",
  rent_clauses_ar: RENT_CLAUSES_AR,
  sale_clauses_ar: SALE_CLAUSES_AR,
  rent_clauses_en: RENT_CLAUSES_EN,
  sale_clauses_en: SALE_CLAUSES_EN,
  primary_color: "0F2C59",
  clause_font_size: 16,
  rent_clauses: RENT_CLAUSES,
  sale_clauses: [
  "ئەم گرێبەستە ڕێکخرا بە مەبەستی فرؤشتنی موڵکی ئاماژە بۆکراوی سەرەوە کە خاوەنداریەکەی دەگەرێتەوە بۆ لایەنی یەکەم بە لایەنی دووەم بە نرخی ({total_price}) {total_price_words} {currency} بۆ ئەم مەبەستەش هەردوو لا ڕەزامەندی تەواوی خۆیان دەربڕی..",
  "{company} بڕی ({down_payment}) {down_payment_words} {currency} وەردەگرێت وەکو پێشەکی لە جیاتی لایەنی یەکەم.",
  "بڕی پارەی ماوە بەم شێوەی خوارەوە دەدرێت: {payment_method}",
  "لەسەر لایەنی یەکەم پێویستە ئەم موڵکە ڕادەستی لایەنی دووەم بکات لە ڕێکەوتی {delivery_date} دوای گەیشتنی بە شایستە داراییەکان.",
  "ئەگەر لایەنی یەکەم لە بەرواری دیاریکراودا ئەم موڵکەی ڕادەستی لایەنی دووەم نەکرد ئەوا دەبێت پابەند بێت بە پێدانی بڕی ({late_fee}) {late_fee_words} {currency} بۆ هەر ڕۆژ دواکەوتن.",
  "ئەگەر هاتوو هەر لایەنێک بە هەر هۆیەک پاشەگەزبێتەوە لەم گرێبەستە دەبێت پابەندبێت بە پێدانی بڕی ({withdrawal}) {withdrawal_words} {currency} بۆ لایەنەکەی تر بەبێ ئاگادار کردنەوەی لایەنی فەرمی.",
  "ڕسووماتی فرۆشتن و گواستنەوە و جیاکردنەوە و یەخستن و ڕاستکردنەوە و باجی خانووبەرە لەسەر لایەنی یەکەمە بیدات بەپێی یاسا ئەگەر تاپۆ بوو، وە ئەگەر تاپۆ نەبوو لایەنی یەکەم پابەندە بە پێدانی بڕی پارەی بەناوکردنی خۆی.",
  "ڕسووماتی کەشف و تۆماری عەقار دەکەوێتە سەر لایەنی دووەم بەگوێرەی یاسا ئەگەر تاپۆ بوو، وە ئەگەر تاپۆ نەبوو لایەنی دووەم پابەندە بە بڕی پارەی بەناوکردن.",
  "لەسەر لایەنی یەکەم پێویستە دەسەڵات بدات بە پارێزەر {lawyer} بە بریکارنامەی تایبەت بەم موڵکە لە فەرمانگەی دادنووس بە مەبەستی ڕایکردنی مامەڵەکان و بەناوکردنی لە بەڕیوبەرایەتی تۆماری خانووبەرە بۆ لایەنی دووەم.",
  "لەسەر لایەنی یەکەم پێویستە بڕی ٪١ لە نرخی ئەم موڵکەی سەرەوە بدات بە {company} لە بەرامبەر فرۆشتنی ئەم موڵکە.",
  "لەسەر لایەنی دووەم پێویستە بڕی ٪١ لە نرخی ئەم موڵکەی سەرەوە بدات بە {company} لە بەرامبەر کڕینی ئەم موڵکە."
],
};
module.exports = { DEFAULTS, LEGACY_TITLES };
