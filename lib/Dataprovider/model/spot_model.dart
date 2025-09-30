// spot_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Spot extends Equatable {
  final String imagePath;
  final String title;
  final String text;

  const Spot({
    required this.imagePath,
    required this.title,
    required this.text,
  });

  factory Spot.fromDocument(DocumentSnapshot doc) {
    return Spot(
      imagePath: doc['imagePath'] ?? '',
      title: doc['title'] ?? '',
      text: doc['text'] ?? '',
    );
  }

  Map<String, dynamic> toDocument() {
    return {
      'imagePath': imagePath,
      'title': title,
      'text': text,
    };
  }

  @override
  List<Object> get props => [imagePath, title, text];
}
