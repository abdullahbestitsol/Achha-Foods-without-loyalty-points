import 'package:flutter/material.dart';
import 'package:achhafoods/screens/Consts/fontStyle.dart';

class CustomTextStyle {
  final double fontSize;
  final Color color;

  CustomTextStyle({
    required this.fontSize,
    required this.color,
  });

  TextStyle toTextStyle() { // Use the Flutter TextStyle
    return TextStyle(
      fontSize: fontSize,
      fontFamily: AppFonts.mainFont,
      color: color,
    );
  }
}
