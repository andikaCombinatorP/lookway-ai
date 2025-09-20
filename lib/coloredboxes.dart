import 'package:flutter/material.dart';
import 'package:lookway/Constant/color.dart';

class ColoredBoxes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 30,
          width: 50, // Menambahkan lebar agar kotak terlihat
          decoration: BoxDecorationStyle.getDecoration(AppColors.primaryColor),
        ),
        Container(
          height: 30,
          width: 50, // Menambahkan lebar agar kotak terlihat
          decoration: BoxDecorationStyle.getDecoration(Color(0xFF535FC6)),
        ),
        Container(
          height: 30,
          width: 50, // Menambahkan lebar agar kotak terlihat
          decoration: BoxDecorationStyle.getDecoration(Colors.yellow),
        ),
        Container(
          height: 30,
          width: 50, // Menambahkan lebar agar kotak terlihat
          decoration: BoxDecorationStyle.getDecoration(Colors.teal),
        ),
      ],
    );
  }
}

class BoxDecorationStyle {
  static BoxDecoration getDecoration(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(0),
      boxShadow: [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 2,
          spreadRadius: 1,
        ),
      ],
    );
  }
}
