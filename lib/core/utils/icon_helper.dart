import 'package:flutter/material.dart';

class CategoryIconHelper {
  // Master map of string icon identifiers to IconData
  static final Map<String, IconData> availableIcons = {
    // Expense related icons
    'fastfood': Icons.fastfood_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'directions_car': Icons.directions_car_rounded,
    'two_wheeler': Icons.two_wheeler_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'home': Icons.home_rounded,
    'movie': Icons.movie_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'medical_services': Icons.medical_services_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'school': Icons.school_rounded,
    'flight': Icons.flight_rounded,
    'coffee': Icons.coffee_rounded,
    'pets': Icons.pets_rounded,
    'phone_android': Icons.phone_android_rounded,
    'wifi': Icons.wifi_rounded,
    'electric_bolt': Icons.electric_bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'local_laundry_service': Icons.local_laundry_service_rounded,
    'child_care': Icons.child_care_rounded,
    'checkroom': Icons.checkroom_rounded,
    
    // Income related icons
    'account_balance_wallet': Icons.account_balance_wallet_rounded,
    'work': Icons.work_rounded,
    'payments': Icons.payments_rounded,
    'trending_up': Icons.trending_up_rounded,
    'savings': Icons.savings_rounded,
    'storefront': Icons.storefront_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'redeem': Icons.redeem_rounded,
    'monetization_on': Icons.monetization_on_rounded,
    'attach_money': Icons.attach_money_rounded,
    'real_estate_agent': Icons.real_estate_agent_rounded,
    'pie_chart': Icons.pie_chart_rounded,

    // General / Miscellaneous icons
    'category': Icons.category_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'star': Icons.star_rounded,
    'favorite': Icons.favorite_rounded,
  };

  /// Mendapatkan IconData dari nama identifier icon
  static IconData getIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Icons.category_rounded;
    }
    return availableIcons[iconName] ?? Icons.category_rounded;
  }

  /// Daftar semua identifier icon yang tersedia untuk dipilih oleh user
  static List<String> get allIconKeys => availableIcons.keys.toList();
}
