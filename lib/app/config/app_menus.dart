import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';

final List<MenuItemModel> appMenus = [
  MenuItemModel(
    label: "JEventku",
    subtitle: "Media Event Jejepangan",
    route: "/jeventku",
    headerImage: "assets/images/JEventku_banner_chibi.png",
  ),
  MenuItemModel(
    label: "dKonser",
    subtitle: "Media Festival Konser",
    route: "/dkonser",
    headerImage: "assets/images/dKonser_banner_chibi.png",
  ),
];
