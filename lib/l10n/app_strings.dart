import 'app_language.dart';

/// Every user-facing string, in each interface language.
///
/// Reached through the static [current] rather than `AppStrings.of(context)`
/// for the same reason `AppColors.current` exists: a third of these strings are
/// needed from enum members, model getters and `static` helpers, none of which
/// have a BuildContext. [current] is refreshed in MaterialApp.builder before
/// any descendant builds, and changing the language rebuilds the whole app
/// below that point.
///
/// Strings that interpolate a value are METHODS, so a translation can put the
/// value where its own grammar needs it instead of being forced into Kurdish
/// word order.
///
/// Kurdish is the source language and the fallback. Screens not yet converted
/// keep their Kurdish literals and simply don't react to the picker — which is
/// exactly today's behaviour, so nothing regresses while the migration runs.
class AppStrings {
  const AppStrings({
    required this.language,
    // ---- app-level ----
    required this.appTitle,
    required this.cannotConnect,
    required this.checkInternet,
    required this.demoOver,
    required this.demoOverBody,
    required this.signOut,
    required this.webOnlyBody,
    required this.noCompanyBody,
    // ---- shell ----
    required this.quickActions,
    required this.rentContract,
    required this.saleContract,
    required this.listProperty,
    required this.customerRequest,
    required this.receiptIn,
    required this.receiptOut,
    required this.navHome,
    required this.navTenants,
    required this.navArchive,
    required this.navListings,
    // ---- dashboard ----
    required this.welcomeBack,
    required this.officeCashbox,
    required this.totalGuarantees,
    required this.commissionThisMonth,
    required this.contractsThisMonth,
    required this.overdueMoney,
    required this.totalContracts,
    required this.activeDemands,
    required this.noNewDemands,
    required this.latestProperties,
    required this.noPropertiesYet,
    required this.seeAll,
    // ---- tenants ----
    required this.tenants,
    required this.noTenants,
    // ---- settings ----
    required this.roleCompanyAdmin,
    required this.roleAgent,
    required this.roleSuperAdmin,
    required this.settings,
    required this.sectionInfo,
    required this.company,
    required this.companyPhone,
    required this.mobileNumber,
    required this.sectionAdmin,
    required this.lawyers,
    required this.lawyersSubtitle,
    required this.recalcStats,
    required this.recalcStatsSubtitle,
    required this.recalcStatsBody,
    required this.recalcStatsDone,
    required this.appearance,
    required this.aboutUs,
    required this.aboutUsSubtitle,
    required this.cancel,
    required this.refresh,
    required this.profilePhotoUpdated,
    required this.themeLight,
    required this.themeDark,
    required this.themeSystem,
    required this.languageLabel,
    // ---- notifications ----
    required this.notifications,
    required this.markAllRead,
    required this.noNotifications,
    required this.noNotificationsBody,
    required this.cannotCall,
    required this.callAction,
    required this.dateLabel,
    required this.justNow,
    required this.yesterday,
    // ---- login ----
    required this.badEmail,
    required this.userNotFound,
    required this.wrongCredentials,
    required this.tooManyAttempts,
    required this.appBrandName,
    required this.appTagline,
    required this.signIn,
    required this.email,
    required this.emailInvalid,
    required this.password,
    required this.passwordTooShort,
    // ---- enums ----
    required this.cityErbil,
    required this.citySulaymaniyah,
    required this.cityKirkuk,
    required this.cityDuhok,
    required this.planBronze,
    required this.planSilver,
    required this.planGold,
    required this.planDiamond,
    required this.receiptExternalReceive,
    required this.receiptExternalPay,
    required this.receiptRentReceive,
    required this.receiptRentPay,
    required this.currencyIqd,
    required this.currencyUsd,
    required this.dealSale,
    required this.dealBuy,
    required this.dealRent,
    required this.typeHouse,
    required this.typeVilla,
    required this.typeShop,
    required this.typeLand,
    required this.typeOffice,
    required this.typeStructure,
    required this.typeOther,
    // ---- shared verbs ----
    required this.emptyValue,
    required this.save,
    required this.add,
    required this.edit,
    required this.delete,
    required this.deleted,
    required this.requiredField,
    required this.unknown,
    // ---- listings ----
    required this.myListings,
    required this.tabOffers,
    required this.tabDemands,
    required this.filterActive,
    required this.filterArchived,
    required this.filterArchivedLong,
    required this.filterMarket,
    required this.dealDone,
    required this.dealDoneToast,
    required this.restoreToActive,
    required this.restoredToast,
    required this.roomsUnit,
    required this.bathroomsUnit,
    required this.floorsUnit,
    // ---- listing form ----
    required this.newOffer,
    required this.newDemand,
    required this.editOfferTitle,
    required this.editDemandTitle,
    required this.ownerName,
    required this.ownerMobile,
    required this.projectOrNeighborhood,
    required this.propertyTypeLabel,
    required this.areaLabel,
    required this.priceField,
    required this.monthlyRentField,
    required this.currencyField,
    required this.roomsField,
    required this.bathroomsField,
    required this.floorsField,
    required this.publishToMarket,
    required this.publishPrivacyNote,
    required this.create,
    // ---- market ----
    required this.agentLabel,
    // ---- photo gallery ----
    required this.propertyPhotos,
    required this.addPhoto,
    required this.camera,
    required this.gallery,
    required this.galleryMultiHint,
    required this.makeCover,
    required this.coverBadge,
    required this.firstIsCover,
    // ---- dialogs ----
    required this.creatingReceipt,
    // ---- archive ----
    required this.archiveTitle,
    required this.tabContracts,
    required this.tabReceipts,
    // ---- lawyers ----
    required this.newLawyer,
    required this.editLawyer,
    required this.deleteLawyer,
    required this.lawyerName,
    required this.noLawyers,
    // ---- commissions ----
    required this.commissions,
    required this.noCommissions,
    required this.seller,
    required this.buyer,
    required this.estimated,
    required this.receivedLabel,
    required this.actualAmount,
    required this.receivedAmount,
    required this.pendingLabel,
    required this.confirmAction,
    required this.confirmedLabel,
    required this.removeAction,
    required this.editShort,
    required this.saveShort,
    // ---- guarantees ----
    required this.guarantees,
    required this.noGuarantees,
    required this.atCompany,
    required this.returnedLabel,
    required this.returnAction,
    required this.returnGuaranteeTitle,
    // ---- overdue ----
    required this.overdueTenants,
    required this.noOverdue,
    // ---- about ----
    required this.appDescription,
    required this.contactSection,
    required this.phoneLabel,
    required this.emailAddress,
    required this.website,
    required this.addressLabel,
    required this.socialMedia,
    required this.whatsapp,
    required this.facebook,
    required this.instagram,
    required this.tiktok,
    required this.madeBy,
    required this.cannotOpen,
    // ---- cards ----
    required this.matchedBadge,
  });

  final AppLanguage language;

  final String appTitle;
  final String cannotConnect;
  final String checkInternet;
  final String demoOver;
  final String demoOverBody;
  final String signOut;
  final String webOnlyBody;
  final String noCompanyBody;

  final String quickActions;
  final String rentContract;
  final String saleContract;
  final String listProperty;
  final String customerRequest;
  final String receiptIn;
  final String receiptOut;
  final String navHome;
  final String navTenants;
  final String navArchive;
  final String navListings;

  final String welcomeBack;
  final String officeCashbox;
  final String totalGuarantees;
  final String commissionThisMonth;
  final String contractsThisMonth;
  final String overdueMoney;
  final String totalContracts;
  final String activeDemands;
  final String noNewDemands;
  final String latestProperties;
  final String noPropertiesYet;
  final String seeAll;

  final String tenants;
  final String noTenants;

  final String roleCompanyAdmin;
  final String roleAgent;
  final String roleSuperAdmin;
  final String settings;
  final String sectionInfo;
  final String company;
  final String companyPhone;
  final String mobileNumber;
  final String sectionAdmin;
  final String lawyers;
  final String lawyersSubtitle;
  final String recalcStats;
  final String recalcStatsSubtitle;
  final String recalcStatsBody;
  final String recalcStatsDone;
  final String appearance;
  final String aboutUs;
  final String aboutUsSubtitle;
  final String cancel;
  final String refresh;
  final String profilePhotoUpdated;
  final String themeLight;
  final String themeDark;
  final String themeSystem;
  final String languageLabel;

  final String notifications;
  final String markAllRead;
  final String noNotifications;
  final String noNotificationsBody;
  final String cannotCall;
  final String callAction;
  final String dateLabel;
  final String justNow;
  final String yesterday;

  final String badEmail;
  final String userNotFound;
  final String wrongCredentials;
  final String tooManyAttempts;
  final String appBrandName;
  final String appTagline;
  final String signIn;
  final String email;
  final String emailInvalid;
  final String password;
  final String passwordTooShort;

  final String cityErbil;
  final String citySulaymaniyah;
  final String cityKirkuk;
  final String cityDuhok;
  final String planBronze;
  final String planSilver;
  final String planGold;
  final String planDiamond;
  final String receiptExternalReceive;
  final String receiptExternalPay;
  final String receiptRentReceive;
  final String receiptRentPay;
  final String currencyIqd;
  final String currencyUsd;
  final String dealSale;
  final String dealBuy;
  final String dealRent;
  final String typeHouse;
  final String typeVilla;
  final String typeShop;
  final String typeLand;
  final String typeOffice;
  final String typeStructure;
  final String typeOther;

  /// Placeholder for a field with no value.
  final String emptyValue;

  final String save;
  final String add;
  final String edit;
  final String delete;
  final String deleted;
  final String requiredField;
  final String unknown;

  final String myListings;
  final String tabOffers;
  final String tabDemands;
  final String filterActive;
  final String filterArchived;

  /// The longer wording, used only while the market segment is absent and
  /// there is room for it.
  final String filterArchivedLong;
  final String filterMarket;
  final String dealDone;
  final String dealDoneToast;
  final String restoreToActive;
  final String restoredToast;
  final String roomsUnit;
  final String bathroomsUnit;
  final String floorsUnit;

  final String newOffer;
  final String newDemand;
  final String editOfferTitle;
  final String editDemandTitle;
  final String ownerName;
  final String ownerMobile;
  final String projectOrNeighborhood;
  final String propertyTypeLabel;
  final String areaLabel;
  final String priceField;
  final String monthlyRentField;
  final String currencyField;
  final String roomsField;
  final String bathroomsField;
  final String floorsField;
  final String publishToMarket;
  final String publishPrivacyNote;
  final String create;

  final String agentLabel;

  final String propertyPhotos;
  final String addPhoto;
  final String camera;
  final String gallery;
  final String galleryMultiHint;
  final String makeCover;
  final String coverBadge;
  final String firstIsCover;

  final String creatingReceipt;

  final String archiveTitle;
  final String tabContracts;
  final String tabReceipts;

  final String newLawyer;
  final String editLawyer;
  final String deleteLawyer;
  final String lawyerName;
  final String noLawyers;

  final String commissions;
  final String noCommissions;
  final String seller;
  final String buyer;
  final String estimated;
  final String receivedLabel;
  final String actualAmount;
  final String receivedAmount;
  final String pendingLabel;
  final String confirmAction;
  final String confirmedLabel;
  final String removeAction;
  final String editShort;
  final String saveShort;

  final String guarantees;
  final String noGuarantees;
  final String atCompany;
  final String returnedLabel;
  final String returnAction;
  final String returnGuaranteeTitle;

  final String overdueTenants;
  final String noOverdue;

  final String appDescription;
  final String contactSection;
  final String phoneLabel;
  final String emailAddress;
  final String website;
  final String addressLabel;
  final String socialMedia;
  final String whatsapp;
  final String facebook;
  final String instagram;
  final String tiktok;
  final String madeBy;
  final String cannotOpen;

  final String matchedBadge;

  // -------------------------------------------------------------------------
  // Interpolated strings. Methods, not fields, so each language controls where
  // the value lands in the sentence.
  // -------------------------------------------------------------------------

  String error(Object e) => switch (language) {
        AppLanguage.ar => 'خطأ: $e',
        AppLanguage.en => 'Error: $e',
        _ => 'هەڵە: $e',
      };

  String hoursAgo(int hours) => switch (language) {
        AppLanguage.ar => 'قبل $hours ساعة',
        AppLanguage.en => '$hours hours ago',
        _ => 'لەمەوپێش $hours کاتژمێر',
      };

  String daysAgo(int days) => switch (language) {
        AppLanguage.ar => 'قبل $days يوم',
        AppLanguage.en => '$days days ago',
        _ => 'لەمەوپێش $days ڕۆژ',
      };

  /// Rent is quoted per month; a sale price is not. The suffix goes wherever
  /// the language wants it.
  String perMonth(String amount) => switch (language) {
        AppLanguage.ar => '$amount / شهرياً',
        AppLanguage.en => '$amount / month',
        _ => '$amount / مانگانە',
      };

  String areaSqm(Object area) => switch (language) {
        AppLanguage.en => '$area m²',
        _ => '$area م²',
      };

  String roomsCount(int n) => switch (language) {
        AppLanguage.ar => '$n غرفة',
        AppLanguage.en => '$n rooms',
        _ => '$n ژوور',
      };

  String bathroomsCount(int n) => switch (language) {
        AppLanguage.ar => '$n حمام',
        AppLanguage.en => '$n baths',
        _ => '$n حەمام',
      };

  String floorsCount(int n) => switch (language) {
        AppLanguage.ar => '$n طابق',
        AppLanguage.en => '$n floors',
        _ => '$n قات',
      };

  String deleteListingConfirm(String name) => switch (language) {
        AppLanguage.ar =>
          'هل تريد حذف "$name"؟ لا يمكن التراجع عن هذا الإجراء.',
        AppLanguage.en => 'Delete "$name"? This cannot be undone.',
        _ => 'دڵنیایت لە سڕینەوەی "$name"؟ ئەم کردارە ناگەڕێتەوە.',
      };

  String archiveEmptyFor(String deal) => switch (language) {
        AppLanguage.ar => 'أرشيف $deal فارغ',
        AppLanguage.en => 'The $deal archive is empty',
        _ => 'ئەرشیفی $deal بەتاڵە',
      };

  String noActiveListingsFor(String deal) => switch (language) {
        AppLanguage.ar => 'لا توجد إعلانات $deal نشطة',
        AppLanguage.en => 'No active $deal listings',
        _ => 'هیچ بڵاوکراوەیەکی چالاکی $deal نییە',
      };

  String marketEmptyOffers(String deal) => switch (language) {
        AppLanguage.ar => 'لا توجد عروض $deal في السوق العام',
        AppLanguage.en => 'No $deal offers in the global market',
        _ => 'هیچ خستنەڕوویەکی $deal لە بازاڕی گشتیدا نییە',
      };

  String marketEmptyDemands(String deal) => switch (language) {
        AppLanguage.ar => 'لا توجد طلبات $deal في السوق العام',
        AppLanguage.en => 'No $deal requests in the global market',
        _ => 'هیچ داواکارییەکی $deal لە بازاڕی گشتیدا نییە',
      };

  String publishVisibleIn(String city) => switch (language) {
        AppLanguage.ar => 'ستراه الشركات الأخرى في $city.',
        AppLanguage.en => 'Other companies in $city will see it.',
        _ => 'کۆمپانیاکانی تری $city دەیبینن.',
      };

  String callWithNumber(String phone) => switch (language) {
        AppLanguage.ar => 'اتصل ($phone)',
        AppLanguage.en => 'Call ($phone)',
        _ => 'پەیوەندی بکە ($phone)',
      };

  String maxPhotos(int n) => switch (language) {
        AppLanguage.ar => 'الحد الأقصى $n صور',
        AppLanguage.en => 'At most $n photos',
        _ => 'زۆرترین ژمارەی وێنە $n ـە',
      };

  String deleteLawyerConfirm(String name) => switch (language) {
        AppLanguage.ar => 'هل تريد حذف «$name»؟',
        AppLanguage.en => 'Delete "$name"?',
        _ => 'دڵنیایت لە سڕینەوەی «$name»؟',
      };

  String contractNumber(Object n) => switch (language) {
        AppLanguage.ar => 'عقد #$n',
        AppLanguage.en => 'Contract #$n',
        _ => 'گرێبەست #$n',
      };

  String estimatedAmount(String amount) => switch (language) {
        AppLanguage.ar => 'المقدّر: $amount',
        AppLanguage.en => 'Estimated: $amount',
        _ => 'خەمڵێنراو: $amount',
      };

  String guaranteeOfProperty(Object n) => switch (language) {
        AppLanguage.ar => 'تأمين العقار رقم $n',
        AppLanguage.en => 'Deposit for property $n',
        _ => 'دڵنیایی موڵکی ژمارە $n',
      };

  String returnGuaranteeConfirm(String name) => switch (language) {
        AppLanguage.ar =>
          'هل يُعاد تأمين «$name»؟ سيُنشأ وصل صرف التأمين.',
        AppLanguage.en =>
          'Return the deposit for "$name"? A payment voucher will be created.',
        _ => 'دڵنیاییەکەی «$name» بگەڕێندرێتەوە؟ '
            'پسولەی دانەوەی دڵنیایی دروست دەکرێت.',
      };

  String contractAndProperty(Object contract, Object property) =>
      switch (language) {
        AppLanguage.ar => 'عقد #$contract · عقار $property',
        AppLanguage.en => 'Contract #$contract · property $property',
        _ => 'گرێبەست #$contract · موڵک $property',
      };

  String monthNumber(int n) => switch (language) {
        AppLanguage.ar => 'الشهر $n',
        AppLanguage.en => 'Month $n',
        _ => 'مانگی $n',
      };

  String daysOverdue(int n) => switch (language) {
        AppLanguage.ar => 'متأخر $n يوم',
        AppLanguage.en => '$n days overdue',
        _ => '$n ڕۆژ دواکەوتوو',
      };

  String dateWith(String date) => switch (language) {
        AppLanguage.ar => 'التاريخ: $date',
        AppLanguage.en => 'Date: $date',
        _ => 'بەروار: $date',
      };

  String lookingFor(String type) => switch (language) {
        AppLanguage.ar => 'يبحث عن $type',
        AppLanguage.en => 'Looking for a $type',
        _ => 'بەدوای $type دەگەڕێت',
      };

  String allRightsReserved(int year) => switch (language) {
        AppLanguage.ar => '© $year — جميع الحقوق محفوظة',
        AppLanguage.en => '© $year — All rights reserved',
        _ => '© $year — هەموو مافەکان پارێزراون',
      };

  /// Every translatable value, for the catalogue tests.
  ///
  /// Dart has no practical reflection, so this list is maintained by hand — and
  /// that is the point: a new string that isn't added here also isn't checked,
  /// so the test in test/strings_test.dart asserts the COUNT as well. Adding a
  /// field without listing it fails the build.
  List<String> get values => [
        appTitle, cannotConnect, checkInternet, demoOver, demoOverBody,
        signOut, webOnlyBody, noCompanyBody,
        quickActions, rentContract, saleContract, listProperty,
        customerRequest, receiptIn, receiptOut, navHome, navTenants,
        navArchive, navListings,
        welcomeBack, officeCashbox, totalGuarantees, commissionThisMonth,
        contractsThisMonth, overdueMoney, totalContracts, activeDemands,
        noNewDemands, latestProperties, noPropertiesYet, seeAll,
        tenants, noTenants,
        roleCompanyAdmin, roleAgent, roleSuperAdmin, settings, sectionInfo,
        company, companyPhone, mobileNumber, sectionAdmin, lawyers,
        lawyersSubtitle, recalcStats, recalcStatsSubtitle, recalcStatsBody,
        recalcStatsDone, appearance, aboutUs, aboutUsSubtitle, cancel,
        refresh, profilePhotoUpdated, themeLight, themeDark, themeSystem,
        languageLabel,
        notifications, markAllRead, noNotifications, noNotificationsBody,
        cannotCall, callAction, dateLabel, justNow, yesterday,
        badEmail, userNotFound, wrongCredentials, tooManyAttempts,
        appBrandName, appTagline, signIn, email, emailInvalid, password,
        passwordTooShort,
        cityErbil, citySulaymaniyah, cityKirkuk, cityDuhok,
        planBronze, planSilver, planGold, planDiamond,
        receiptExternalReceive, receiptExternalPay, receiptRentReceive,
        receiptRentPay, currencyIqd, currencyUsd,
        dealSale, dealBuy, dealRent,
        typeHouse, typeVilla, typeShop, typeLand, typeOffice, typeStructure,
        typeOther,
        emptyValue,
        save, add, edit, delete, deleted, requiredField, unknown,
        myListings, tabOffers, tabDemands, filterActive, filterArchived,
        filterArchivedLong, filterMarket, dealDone, dealDoneToast,
        restoreToActive, restoredToast, roomsUnit, bathroomsUnit, floorsUnit,
        newOffer, newDemand, editOfferTitle, editDemandTitle, ownerName,
        ownerMobile, projectOrNeighborhood, propertyTypeLabel, areaLabel,
        priceField, monthlyRentField, currencyField, roomsField,
        bathroomsField, floorsField, publishToMarket, publishPrivacyNote,
        create,
        agentLabel,
        propertyPhotos, addPhoto, camera, gallery, galleryMultiHint,
        makeCover, coverBadge, firstIsCover,
        creatingReceipt,
        archiveTitle, tabContracts, tabReceipts,
        newLawyer, editLawyer, deleteLawyer, lawyerName, noLawyers,
        commissions, noCommissions, seller, buyer, estimated, receivedLabel,
        actualAmount, receivedAmount, pendingLabel, confirmAction,
        confirmedLabel, removeAction, editShort, saveShort,
        guarantees, noGuarantees, atCompany, returnedLabel, returnAction,
        returnGuaranteeTitle,
        overdueTenants, noOverdue,
        appDescription, contactSection, phoneLabel, emailAddress, website,
        addressLabel, socialMedia, whatsapp, facebook, instagram, tiktok,
        madeBy, cannotOpen,
        matchedBadge,
      ];

  /// The signed-in language. Refreshed by MaterialApp.builder — see the class
  /// doc for why this is a static rather than an InheritedWidget lookup.
  static AppStrings current = ku;

  static AppStrings of(AppLanguage language) => switch (language) {
        AppLanguage.ku => ku,
        AppLanguage.ar => ar,
        AppLanguage.en => en,
      };

  // -------------------------------------------------------------------------
  static const ku = AppStrings(
    language: AppLanguage.ku,
    appTitle: 'گرێبەست',
    cannotConnect: 'ئەپەکە نەیتوانی پەیوەندی بکات',
    checkInternet: 'تکایە ئینتەرنێتەکەت بپشکنە و ئەپەکە دووبارە بکەرەوە.',
    demoOver: 'ماوەی دیمۆ تەواو بوو',
    demoOverBody: 'ماوەی ٧ ڕۆژی تاقیکردنەوەی ئەم هەژمارە کۆتایی هات.\n'
        'بۆ بەردەوامبوون پەیوەندی بە لەزنۆدەوە بکە.',
    signOut: 'دەرچوون',
    webOnlyBody: 'ئەم هەژمارە تەنها لە وێب کاردەکات.\n'
        'تکایە لە ڕێگەی aqarat.leznode.com بچۆ ژوورەوە.',
    noCompanyBody: 'ئەم هەژمارە بە هیچ کۆمپانیایەکەوە پەیوەست نییە.\n'
        'تکایە پەیوەندی بە بەڕێوەبەرەوە بکە.',
    quickActions: 'کردارە خێراکان',
    rentContract: 'گرێبەستی کرێ',
    saleContract: 'گرێبەستی فرۆشتن',
    listProperty: 'خستنەڕووی موڵک',
    customerRequest: 'داواکاری موشتەری',
    receiptIn: 'پسولەی پارە وەرگرتن',
    receiptOut: 'پسولەی پارەدان',
    navHome: 'سەرەکی',
    navTenants: 'کرێچیەکان',
    navArchive: 'ئەرشیف',
    navListings: 'داواکاری و خستنەڕوو',
    welcomeBack: 'بەخێربێیتەوە 👋',
    officeCashbox: 'قاسەی نووسینگە',
    totalGuarantees: 'کۆی دڵنیایی',
    commissionThisMonth: 'عمولەی ئەم مانگە',
    contractsThisMonth: 'گرێبەستەکانی ئەم مانگە',
    overdueMoney: 'پارەی دواکەوتوو',
    totalContracts: 'کۆی گرێبەستەکان',
    activeDemands: 'داواکارییە چالاکەکان',
    noNewDemands: 'هیچ داواکارییەکی نوێ نییە',
    latestProperties: 'نوێترین موڵکەکان',
    noPropertiesYet: 'هێشتا هیچ موڵکێک داخڵ نەکراوە',
    seeAll: 'هەمووی',
    tenants: 'کرێچیەکان',
    noTenants: 'هیچ کرێچییەک نییە',
    roleCompanyAdmin: 'بەڕێوەبەری کۆمپانیا',
    roleAgent: 'کارمەند',
    roleSuperAdmin: 'بەڕێوەبەری گشتی',
    settings: 'ڕێکخستن',
    sectionInfo: 'زانیارییەکان',
    company: 'کۆمپانیا',
    companyPhone: 'تەلەفۆنی کۆمپانیا',
    mobileNumber: 'ژمارەی مۆبایل',
    sectionAdmin: 'بەڕێوەبردن',
    lawyers: 'پارێزەران',
    lawyersSubtitle: 'زیادکردن و دەستکاری لیستی پارێزەران',
    recalcStats: 'نوێکردنەوەی قاسە و ئامار',
    recalcStatsSubtitle: 'دووبارە حیسابکردنیان لە گرێبەستەکانەوە',
    recalcStatsBody: 'قاسە و ئامارەکان لە نوێوە لە گرێبەستەکانەوە حیساب '
        'دەکرێنەوە. ئەمە هیچ گرێبەست یان پسولەیەک ناگۆڕێت.',
    recalcStatsDone: 'قاسە و ئامار نوێکرانەوە',
    appearance: 'ڕووکار',
    aboutUs: 'دەربارەی ئێمە',
    aboutUsSubtitle: 'پەیوەندی و زانیاری ئەپەکە',
    cancel: 'پاشگەزبوونەوە',
    refresh: 'نوێکردنەوە',
    profilePhotoUpdated: 'وێنەی پرۆفایل نوێ کرایەوە',
    themeLight: 'ڕووناک',
    themeDark: 'تاریک',
    themeSystem: 'وەک سیستەم',
    languageLabel: 'زمان',
    notifications: 'ئاگادارکردنەوەکان',
    markAllRead: 'هەمووی خوێندراوە',
    noNotifications: 'هیچ ئاگادارکردنەوەیەک نییە',
    noNotificationsBody: 'کاتێک کرێیەک دوادەکەوێت یان گرێبەستێک لە کۆتاییدا '
        'دەبێت، لێرە دەردەکەوێت.',
    cannotCall: 'ناتوانرێت پەیوەندی بکرێت',
    callAction: 'پەیوەندی',
    dateLabel: 'بەروار: ',
    justNow: 'ئێستا',
    yesterday: 'دوێنێ',
    badEmail: 'ئیمەیڵ هەڵەیە',
    userNotFound: 'بەکارهێنەر نەدۆزرایەوە',
    wrongCredentials: 'ئیمەیڵ یان وشەی نهێنی هەڵەیە',
    tooManyAttempts: 'هەوڵی زۆر — کەمێک چاوەڕێ بکە',
    appBrandName: 'خانووبەرە',
    appTagline: 'سیستەمی بەڕێوەبردنی ئەقارات',
    signIn: 'چوونەژوورەوە',
    email: 'ئیمەیڵ',
    emailInvalid: 'ئیمەیڵێکی دروست بنووسە',
    password: 'وشەی نهێنی',
    passwordTooShort: 'لانیکەم ٦ پیت یان ژمارە',
    cityErbil: 'هەولێر',
    citySulaymaniyah: 'سلێمانی',
    cityKirkuk: 'کەرکوک',
    cityDuhok: 'دهۆک',
    planBronze: 'بڕۆنز',
    planSilver: 'سیلڤەر',
    planGold: 'گۆڵد',
    planDiamond: 'دایمۆند',
    receiptExternalReceive: 'پسولەی پارە وەرگرتن',
    receiptExternalPay: 'پسولەی پارەدان',
    receiptRentReceive: 'پسولەی وەرگرتنی کرێ',
    receiptRentPay: 'پسولەی دانەوەی کرێ',
    currencyIqd: 'دیناری عێراقی',
    currencyUsd: 'دۆلاری ئەمریکی',
    dealSale: 'فرۆشتن',
    dealBuy: 'کڕین',
    dealRent: 'کرێ',
    typeHouse: 'خانوو',
    typeVilla: 'ڤێڵا',
    typeShop: 'دوکان',
    typeLand: 'زەوی',
    typeOffice: 'ئۆفیس',
    typeStructure: 'هەیکەل',
    typeOther: 'هیتر',
    emptyValue: '—',
    save: 'پاشەکەوتکردن',
    add: 'زیادکردن',
    edit: 'دەستکاری',
    delete: 'سڕینەوە',
    deleted: 'سڕایەوە',
    requiredField: 'پێویستە',
    unknown: 'نەزانراو',
    myListings: 'بڵاوکراوەکانم',
    tabOffers: 'خستنەڕووەکان',
    tabDemands: 'داواکارییەکان',
    filterActive: 'چالاک',
    filterArchived: 'ئەرشیف',
    filterArchivedLong: 'ئەرشیف (تەواوبوو)',
    filterMarket: 'بازاڕی گشتی',
    dealDone: 'مامەڵەکە تەواوبوو',
    dealDoneToast: 'مامەڵەکە تەواوبوو (چووە ئەرشیف)',
    restoreToActive: 'گەڕاندنەوە بۆ لیستی چالاک',
    restoredToast: 'گەڕێندرایەوە بۆ لیستی چالاک',
    roomsUnit: 'ژوور',
    bathroomsUnit: 'حەمام',
    floorsUnit: 'قات',
    newOffer: 'خستنەڕووی نوێ',
    newDemand: 'داواکاری نوێ',
    editOfferTitle: 'دەستکاری خستنەڕوو',
    editDemandTitle: 'دەستکاری داواکاری',
    ownerName: 'ناوی خاوەن',
    ownerMobile: 'مۆبایلی خاوەن',
    projectOrNeighborhood: 'پڕۆژە / گەڕەک',
    propertyTypeLabel: 'جۆری موڵک',
    areaLabel: 'ڕووبەر (م²)',
    priceField: 'نرخ',
    monthlyRentField: 'کرێی مانگانە',
    currencyField: 'دراو',
    roomsField: 'ژوور',
    bathroomsField: 'حەمام',
    floorsField: 'قات',
    publishToMarket: 'بڵاوکردنەوە لە بازاڕی گشتی',
    publishPrivacyNote: 'ناو و مۆبایلی خاوەن نانێردرێت — تەنها ژمارەی خۆت.',
    create: 'دروستکردن',
    agentLabel: 'نوێنەر / بریکار',
    propertyPhotos: 'وێنەکانی موڵک',
    addPhoto: 'زیادکردن',
    camera: 'کامێرا',
    gallery: 'گەلەری',
    galleryMultiHint: 'دەتوانیت چەند وێنەیەک هەڵبژێریت',
    makeCover: 'بیکە بە وێنەی سەرەکی',
    coverBadge: 'سەرەکی',
    firstIsCover: 'یەکەم وێنە دەبێتە وێنەی سەرەکی',
    creatingReceipt: 'چاوەڕوانبە، پسولە دروست دەبێت...',
    archiveTitle: 'ئەرشیف',
    tabContracts: 'گرێبەستەکان',
    tabReceipts: 'پسولەکان',
    newLawyer: 'پارێزەری نوێ',
    editLawyer: 'دەستکاری پارێزەر',
    deleteLawyer: 'سڕینەوەی پارێزەر',
    lawyerName: 'ناوی پارێزەر',
    noLawyers: 'هیچ پارێزەرێک زیاد نەکراوە',
    commissions: 'عمولەکان',
    noCommissions: 'هیچ عمولەیەک نییە',
    seller: 'فرۆشیار',
    buyer: 'کڕیار',
    estimated: 'خەمڵێنراو',
    receivedLabel: 'وەرگیراو',
    actualAmount: 'بڕی ڕاستەقینە',
    receivedAmount: 'بڕی وەرگیراو',
    pendingLabel: 'چاوەڕوان',
    confirmAction: 'کۆنفێرم',
    confirmedLabel: 'کۆنفێرمکراو',
    removeAction: 'لابردن',
    editShort: 'ئیدیت',
    saveShort: 'پاشەکەوت',
    guarantees: 'دڵنیاییەکان',
    noGuarantees: 'هیچ دڵنیاییەک نییە',
    atCompany: 'لای کۆمپانیا',
    returnedLabel: 'گەڕێندراوە',
    returnAction: 'گەڕاندنەوە',
    returnGuaranteeTitle: 'گەڕاندنەوەی دڵنیایی',
    overdueTenants: 'کرێچییە دواکەوتووەکان',
    noOverdue: 'هیچ کرێیەکی دواکەوتوو نییە',
    appDescription: 'سیستەمی بەڕێوەبردنی موڵک و گرێبەست',
    contactSection: 'پەیوەندی',
    phoneLabel: 'تەلەفۆن',
    emailAddress: 'ئیمەیل',
    website: 'ماڵپەڕ',
    addressLabel: 'ناونیشان',
    socialMedia: 'سۆشیال میدیا',
    whatsapp: 'واتساپ',
    facebook: 'فەیسبووک',
    instagram: 'ئینستاگرام',
    tiktok: 'تیکتۆک',
    madeBy: 'دروستکراوە لەلایەن',
    cannotOpen: 'نەتوانرا بکرێتەوە',
    matchedBadge: 'گونجاوە',
  );

  // -------------------------------------------------------------------------
  static const ar = AppStrings(
    language: AppLanguage.ar,
    appTitle: 'العقود',
    cannotConnect: 'تعذّر الاتصال بالتطبيق',
    checkInternet: 'يرجى التحقق من الإنترنت وإعادة فتح التطبيق.',
    demoOver: 'انتهت الفترة التجريبية',
    demoOverBody: 'انتهت فترة التجربة البالغة ٧ أيام لهذا الحساب.\n'
        'للاستمرار يرجى التواصل مع Leznode.',
    signOut: 'تسجيل الخروج',
    webOnlyBody: 'هذا الحساب يعمل على الويب فقط.\n'
        'يرجى تسجيل الدخول عبر aqarat.leznode.com.',
    noCompanyBody: 'هذا الحساب غير مرتبط بأي شركة.\n'
        'يرجى التواصل مع المسؤول.',
    quickActions: 'إجراءات سريعة',
    rentContract: 'عقد إيجار',
    saleContract: 'عقد بيع',
    listProperty: 'عرض عقار',
    customerRequest: 'طلب زبون',
    receiptIn: 'وصل قبض',
    receiptOut: 'وصل صرف',
    navHome: 'الرئيسية',
    navTenants: 'المستأجرون',
    navArchive: 'الأرشيف',
    navListings: 'العروض والطلبات',
    welcomeBack: 'أهلاً بعودتك 👋',
    officeCashbox: 'صندوق المكتب',
    totalGuarantees: 'مجموع التأمينات',
    commissionThisMonth: 'عمولة هذا الشهر',
    contractsThisMonth: 'عقود هذا الشهر',
    overdueMoney: 'المبالغ المتأخرة',
    totalContracts: 'مجموع العقود',
    activeDemands: 'الطلبات النشطة',
    noNewDemands: 'لا توجد طلبات جديدة',
    latestProperties: 'أحدث العقارات',
    noPropertiesYet: 'لم يُضف أي عقار بعد',
    seeAll: 'الكل',
    tenants: 'المستأجرون',
    noTenants: 'لا يوجد مستأجرون',
    roleCompanyAdmin: 'مدير الشركة',
    roleAgent: 'موظف',
    roleSuperAdmin: 'المدير العام',
    settings: 'الإعدادات',
    sectionInfo: 'المعلومات',
    company: 'الشركة',
    companyPhone: 'هاتف الشركة',
    mobileNumber: 'رقم الموبايل',
    sectionAdmin: 'الإدارة',
    lawyers: 'المحامون',
    lawyersSubtitle: 'إضافة وتعديل قائمة المحامين',
    recalcStats: 'تحديث الصندوق والإحصاءات',
    recalcStatsSubtitle: 'إعادة احتسابها من العقود',
    recalcStatsBody: 'ستُحتسب الصندوق والإحصاءات من جديد اعتماداً على العقود. '
        'لن يتغيّر أي عقد أو وصل.',
    recalcStatsDone: 'تم تحديث الصندوق والإحصاءات',
    appearance: 'المظهر',
    aboutUs: 'من نحن',
    aboutUsSubtitle: 'التواصل ومعلومات التطبيق',
    cancel: 'إلغاء',
    refresh: 'تحديث',
    profilePhotoUpdated: 'تم تحديث الصورة الشخصية',
    themeLight: 'فاتح',
    themeDark: 'داكن',
    themeSystem: 'حسب النظام',
    languageLabel: 'اللغة',
    notifications: 'الإشعارات',
    markAllRead: 'تعليم الكل كمقروء',
    noNotifications: 'لا توجد إشعارات',
    noNotificationsBody: 'عند تأخّر إيجار أو قرب انتهاء عقد، سيظهر هنا.',
    cannotCall: 'تعذّر إجراء الاتصال',
    callAction: 'اتصال',
    dateLabel: 'التاريخ: ',
    justNow: 'الآن',
    yesterday: 'أمس',
    badEmail: 'البريد الإلكتروني غير صحيح',
    userNotFound: 'المستخدم غير موجود',
    wrongCredentials: 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
    tooManyAttempts: 'محاولات كثيرة — انتظر قليلاً',
    appBrandName: 'العقارات',
    appTagline: 'نظام إدارة العقارات',
    signIn: 'تسجيل الدخول',
    email: 'البريد الإلكتروني',
    emailInvalid: 'أدخل بريداً إلكترونياً صحيحاً',
    password: 'كلمة المرور',
    passwordTooShort: '٦ أحرف أو أرقام على الأقل',
    cityErbil: 'أربيل',
    citySulaymaniyah: 'السليمانية',
    cityKirkuk: 'كركوك',
    cityDuhok: 'دهوك',
    planBronze: 'برونز',
    planSilver: 'فضي',
    planGold: 'ذهبي',
    planDiamond: 'ماسي',
    receiptExternalReceive: 'وصل قبض',
    receiptExternalPay: 'وصل صرف',
    receiptRentReceive: 'وصل قبض الإيجار',
    receiptRentPay: 'وصل صرف الإيجار',
    currencyIqd: 'الدينار العراقي',
    currencyUsd: 'الدولار الأمريكي',
    dealSale: 'بيع',
    dealBuy: 'شراء',
    dealRent: 'إيجار',
    typeHouse: 'دار',
    typeVilla: 'فيلا',
    typeShop: 'محل',
    typeLand: 'أرض',
    typeOffice: 'مكتب',
    typeStructure: 'هيكل',
    typeOther: 'أخرى',
    emptyValue: '—',
    save: 'حفظ',
    add: 'إضافة',
    edit: 'تعديل',
    delete: 'حذف',
    deleted: 'تم الحذف',
    requiredField: 'مطلوب',
    unknown: 'غير معروف',
    myListings: 'إعلاناتي',
    tabOffers: 'العروض',
    tabDemands: 'الطلبات',
    filterActive: 'نشط',
    filterArchived: 'الأرشيف',
    filterArchivedLong: 'الأرشيف (منجز)',
    filterMarket: 'السوق العام',
    dealDone: 'تمّت الصفقة',
    dealDoneToast: 'تمّت الصفقة (نُقلت إلى الأرشيف)',
    restoreToActive: 'إعادة إلى القائمة النشطة',
    restoredToast: 'أُعيدت إلى القائمة النشطة',
    roomsUnit: 'غرفة',
    bathroomsUnit: 'حمام',
    floorsUnit: 'طابق',
    newOffer: 'عرض جديد',
    newDemand: 'طلب جديد',
    editOfferTitle: 'تعديل العرض',
    editDemandTitle: 'تعديل الطلب',
    ownerName: 'اسم المالك',
    ownerMobile: 'موبايل المالك',
    projectOrNeighborhood: 'المشروع / الحي',
    propertyTypeLabel: 'نوع العقار',
    areaLabel: 'المساحة (م²)',
    priceField: 'السعر',
    monthlyRentField: 'الإيجار الشهري',
    currencyField: 'العملة',
    roomsField: 'غرف',
    bathroomsField: 'حمامات',
    floorsField: 'طوابق',
    publishToMarket: 'النشر في السوق العام',
    publishPrivacyNote: 'لا يُرسل اسم المالك ولا رقمه — رقمك أنت فقط.',
    create: 'إنشاء',
    agentLabel: 'الوكيل / الوسيط',
    propertyPhotos: 'صور العقار',
    addPhoto: 'إضافة',
    camera: 'الكاميرا',
    gallery: 'المعرض',
    galleryMultiHint: 'يمكنك اختيار عدة صور',
    makeCover: 'اجعلها الصورة الرئيسية',
    coverBadge: 'رئيسية',
    firstIsCover: 'الصورة الأولى هي الرئيسية',
    creatingReceipt: 'انتظر، يجري إنشاء الوصل...',
    archiveTitle: 'الأرشيف',
    tabContracts: 'العقود',
    tabReceipts: 'الوصولات',
    newLawyer: 'محامٍ جديد',
    editLawyer: 'تعديل المحامي',
    deleteLawyer: 'حذف المحامي',
    lawyerName: 'اسم المحامي',
    noLawyers: 'لم يُضف أي محامٍ',
    commissions: 'العمولات',
    noCommissions: 'لا توجد عمولات',
    seller: 'البائع',
    buyer: 'المشتري',
    estimated: 'المقدّر',
    receivedLabel: 'المستلم',
    actualAmount: 'المبلغ الفعلي',
    receivedAmount: 'المبلغ المستلم',
    pendingLabel: 'قيد الانتظار',
    confirmAction: 'تأكيد',
    confirmedLabel: 'مؤكَّد',
    removeAction: 'إزالة',
    editShort: 'تعديل',
    saveShort: 'حفظ',
    guarantees: 'التأمينات',
    noGuarantees: 'لا توجد تأمينات',
    atCompany: 'لدى الشركة',
    returnedLabel: 'أُعيد',
    returnAction: 'إعادة',
    returnGuaranteeTitle: 'إعادة التأمين',
    overdueTenants: 'المستأجرون المتأخرون',
    noOverdue: 'لا يوجد إيجار متأخر',
    appDescription: 'نظام إدارة العقارات والعقود',
    contactSection: 'التواصل',
    phoneLabel: 'الهاتف',
    emailAddress: 'البريد الإلكتروني',
    website: 'الموقع',
    addressLabel: 'العنوان',
    socialMedia: 'وسائل التواصل',
    whatsapp: 'واتساب',
    facebook: 'فيسبوك',
    instagram: 'إنستغرام',
    tiktok: 'تيك توك',
    madeBy: 'تطوير',
    cannotOpen: 'تعذّر الفتح',
    matchedBadge: 'مطابق',
  );

  // -------------------------------------------------------------------------
  static const en = AppStrings(
    language: AppLanguage.en,
    appTitle: 'Contracts',
    cannotConnect: 'The app could not connect',
    checkInternet: 'Please check your internet and reopen the app.',
    demoOver: 'Trial period ended',
    demoOverBody: "This account's 7-day trial has ended.\n"
        'Contact Leznode to continue.',
    signOut: 'Sign out',
    webOnlyBody: 'This account works on the web only.\n'
        'Please sign in at aqarat.leznode.com.',
    noCompanyBody: 'This account is not linked to any company.\n'
        'Please contact your administrator.',
    quickActions: 'Quick actions',
    rentContract: 'Rent contract',
    saleContract: 'Sale contract',
    listProperty: 'List a property',
    customerRequest: 'Customer request',
    receiptIn: 'Receipt voucher',
    receiptOut: 'Payment voucher',
    navHome: 'Home',
    navTenants: 'Tenants',
    navArchive: 'Archive',
    navListings: 'Listings',
    welcomeBack: 'Welcome back 👋',
    officeCashbox: 'Office cashbox',
    totalGuarantees: 'Total deposits',
    commissionThisMonth: "This month's commission",
    contractsThisMonth: "This month's contracts",
    overdueMoney: 'Overdue amount',
    totalContracts: 'Total contracts',
    activeDemands: 'Active requests',
    noNewDemands: 'No new requests',
    latestProperties: 'Latest properties',
    noPropertiesYet: 'No properties added yet',
    seeAll: 'See all',
    tenants: 'Tenants',
    noTenants: 'No tenants yet',
    roleCompanyAdmin: 'Company admin',
    roleAgent: 'Agent',
    roleSuperAdmin: 'Super admin',
    settings: 'Settings',
    sectionInfo: 'Information',
    company: 'Company',
    companyPhone: 'Company phone',
    mobileNumber: 'Mobile number',
    sectionAdmin: 'Administration',
    lawyers: 'Lawyers',
    lawyersSubtitle: 'Add and edit the lawyer directory',
    recalcStats: 'Refresh cashbox and stats',
    recalcStatsSubtitle: 'Recalculate them from the contracts',
    recalcStatsBody: 'The cashbox and statistics will be recalculated from the '
        'contracts. No contract or receipt is changed.',
    recalcStatsDone: 'Cashbox and stats refreshed',
    appearance: 'Appearance',
    aboutUs: 'About us',
    aboutUsSubtitle: 'Contact and app information',
    cancel: 'Cancel',
    refresh: 'Refresh',
    profilePhotoUpdated: 'Profile photo updated',
    themeLight: 'Light',
    themeDark: 'Dark',
    themeSystem: 'System',
    languageLabel: 'Language',
    notifications: 'Notifications',
    markAllRead: 'Mark all read',
    noNotifications: 'No notifications',
    noNotificationsBody:
        'When rent falls overdue or a contract nears its end, it shows here.',
    cannotCall: 'Could not place the call',
    callAction: 'Call',
    dateLabel: 'Date: ',
    justNow: 'Just now',
    yesterday: 'Yesterday',
    badEmail: 'Invalid email',
    userNotFound: 'User not found',
    wrongCredentials: 'Wrong email or password',
    tooManyAttempts: 'Too many attempts — wait a moment',
    appBrandName: 'Aqarat',
    appTagline: 'Real estate management system',
    signIn: 'Sign in',
    email: 'Email',
    emailInvalid: 'Enter a valid email',
    password: 'Password',
    passwordTooShort: 'At least 6 letters or digits',
    cityErbil: 'Erbil',
    citySulaymaniyah: 'Sulaymaniyah',
    cityKirkuk: 'Kirkuk',
    cityDuhok: 'Duhok',
    planBronze: 'Bronze',
    planSilver: 'Silver',
    planGold: 'Gold',
    planDiamond: 'Diamond',
    receiptExternalReceive: 'Receipt voucher',
    receiptExternalPay: 'Payment voucher',
    receiptRentReceive: 'Rent receipt',
    receiptRentPay: 'Rent payment',
    currencyIqd: 'Iraqi dinar',
    currencyUsd: 'US dollar',
    dealSale: 'For sale',
    dealBuy: 'Buying',
    dealRent: 'For rent',
    typeHouse: 'House',
    typeVilla: 'Villa',
    typeShop: 'Shop',
    typeLand: 'Land',
    typeOffice: 'Office',
    typeStructure: 'Structure',
    typeOther: 'Other',
    emptyValue: '—',
    save: 'Save',
    add: 'Add',
    edit: 'Edit',
    delete: 'Delete',
    deleted: 'Deleted',
    requiredField: 'Required',
    unknown: 'Unknown',
    myListings: 'My listings',
    tabOffers: 'Offers',
    tabDemands: 'Requests',
    filterActive: 'Active',
    filterArchived: 'Archive',
    filterArchivedLong: 'Archive (completed)',
    filterMarket: 'Global market',
    dealDone: 'Deal completed',
    dealDoneToast: 'Deal completed (moved to the archive)',
    restoreToActive: 'Restore to the active list',
    restoredToast: 'Restored to the active list',
    roomsUnit: 'rooms',
    bathroomsUnit: 'baths',
    floorsUnit: 'floors',
    newOffer: 'New offer',
    newDemand: 'New request',
    editOfferTitle: 'Edit offer',
    editDemandTitle: 'Edit request',
    ownerName: 'Owner name',
    ownerMobile: 'Owner mobile',
    projectOrNeighborhood: 'Project / neighbourhood',
    propertyTypeLabel: 'Property type',
    areaLabel: 'Area (m²)',
    priceField: 'Price',
    monthlyRentField: 'Monthly rent',
    currencyField: 'Currency',
    roomsField: 'Rooms',
    bathroomsField: 'Baths',
    floorsField: 'Floors',
    publishToMarket: 'Publish to the global market',
    publishPrivacyNote:
        "The owner's name and mobile are not shared — only your own number.",
    create: 'Create',
    agentLabel: 'Agent / broker',
    propertyPhotos: 'Property photos',
    addPhoto: 'Add',
    camera: 'Camera',
    gallery: 'Gallery',
    galleryMultiHint: 'You can pick several photos',
    makeCover: 'Make it the cover photo',
    coverBadge: 'Cover',
    firstIsCover: 'The first photo becomes the cover',
    creatingReceipt: 'Please wait, the receipt is being created…',
    archiveTitle: 'Archive',
    tabContracts: 'Contracts',
    tabReceipts: 'Receipts',
    newLawyer: 'New lawyer',
    editLawyer: 'Edit lawyer',
    deleteLawyer: 'Delete lawyer',
    lawyerName: 'Lawyer name',
    noLawyers: 'No lawyers added yet',
    commissions: 'Commissions',
    noCommissions: 'No commissions',
    seller: 'Seller',
    buyer: 'Buyer',
    estimated: 'Estimated',
    receivedLabel: 'Received',
    actualAmount: 'Actual amount',
    receivedAmount: 'Amount received',
    pendingLabel: 'Pending',
    confirmAction: 'Confirm',
    confirmedLabel: 'Confirmed',
    removeAction: 'Remove',
    editShort: 'Edit',
    saveShort: 'Save',
    guarantees: 'Deposits',
    noGuarantees: 'No deposits',
    atCompany: 'Held by the company',
    returnedLabel: 'Returned',
    returnAction: 'Return',
    returnGuaranteeTitle: 'Return the deposit',
    overdueTenants: 'Tenants in arrears',
    noOverdue: 'No overdue rent',
    appDescription: 'Property and contract management system',
    contactSection: 'Contact',
    phoneLabel: 'Phone',
    emailAddress: 'Email',
    website: 'Website',
    addressLabel: 'Address',
    socialMedia: 'Social media',
    whatsapp: 'WhatsApp',
    facebook: 'Facebook',
    instagram: 'Instagram',
    tiktok: 'TikTok',
    madeBy: 'Built by',
    cannotOpen: 'Could not open',
    matchedBadge: 'Matched',
  );
}

/// Short alias so a call site reads `S.settings` instead of
/// `AppStrings.current.settings`.
AppStrings get S => AppStrings.current;
