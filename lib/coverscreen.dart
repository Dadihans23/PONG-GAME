import 'package:flutter/material.dart';




class coverScreen extends StatefulWidget {
  final bool hastarted ;

  const coverScreen({super.key , required this.hastarted});
  

  @override
  State<coverScreen> createState() => _coverScreenState();
}

class _coverScreenState extends State<coverScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: const Alignment(0, -0.2),
      child: Text(
        widget.hastarted ? "" : " T A P E Z  L'E C R A N " ,
        style: const TextStyle( color: Colors.white),
      ),
    );
  }
}