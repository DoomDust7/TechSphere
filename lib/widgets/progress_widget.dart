import 'package:flutter/material.dart';

Widget circularProgress() {
  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.only(top: 12.0),
    child: const CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
    ),
  );
}

Widget linearProgress() {
  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.only(top: 12.0),
    child: const LinearProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.lightGreenAccent),
    ),
  );
}
