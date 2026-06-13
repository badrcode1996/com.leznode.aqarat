import 'package:flutter/material.dart';

import '../../models/enums.dart';

/// Lightweight view models + dummy data to populate the dashboard immediately.
/// Replace these lists with Firestore-backed providers when wiring real data.

class DemandRequest {
  const DemandRequest({
    required this.clientName,
    required this.description,
    required this.location,
    required this.budget,
  });

  final String clientName;
  final String description;
  final String location;
  final String budget;
}

class PropertyOffer {
  const PropertyOffer({
    required this.title,
    required this.location,
    required this.type,
    required this.price,
    required this.agentName,
    required this.timeAgo,
    required this.accent,
  });

  final String title;
  final String location;
  final ContractType type; // rent / sale → drives the chip
  final String price;
  final String agentName;
  final String timeAgo;
  final Color accent; // placeholder image tint
}

const dummyDemands = <DemandRequest>[
  DemandRequest(
    clientName: 'ئاکۆ محەمەد',
    description: 'بەدوای خانوویەکدا دەگەڕێت لە بەختیاری',
    location: 'بەختیاری',
    budget: 'تا \$100k',
  ),
  DemandRequest(
    clientName: 'دیار سەعید',
    description: 'شوقەی ٣ ژووری بۆ کرێ',
    location: 'ئەندازیاران',
    budget: '\$600/مانگ',
  ),
  DemandRequest(
    clientName: 'هێمن عەلی',
    description: 'زەوی بازرگانی لەسەر شەقامی سەرەکی',
    location: 'کوێستان',
    budget: 'تا \$250k',
  ),
];

const dummyOffers = <PropertyOffer>[
  PropertyOffer(
    title: 'ڤێلایەکی نوێ بە باخچەوە',
    location: 'گەڕەکی ئاشتی، هەولێر',
    type: ContractType.sale,
    price: '\$185,000',
    agentName: 'ئەحمەد',
    timeAgo: '٢ کاتژمێر لەمەوبەر',
    accent: Color(0xFF1565C0),
  ),
  PropertyOffer(
    title: 'شوقەی مۆدێرن ٢ ژوور',
    location: 'ئەندازیاران، هەولێر',
    type: ContractType.rent,
    price: '\$700 / مانگ',
    agentName: 'سۆران',
    timeAgo: '٥ کاتژمێر لەمەوبەر',
    accent: Color(0xFF2E7D32),
  ),
  PropertyOffer(
    title: 'دوکانی بازرگانی',
    location: 'بازاڕی نیشتمان',
    type: ContractType.rent,
    price: '\$1,200 / مانگ',
    agentName: 'بەدر',
    timeAgo: 'دوێنێ',
    accent: Color(0xFFEF6C00),
  ),
  PropertyOffer(
    title: 'خانووی دوو نهۆم',
    location: 'کوردستان، سلێمانی',
    type: ContractType.sale,
    price: '\$240,000',
    agentName: 'هاوکار',
    timeAgo: '٢ ڕۆژ لەمەوبەر',
    accent: Color(0xFF6A1B9A),
  ),
];
