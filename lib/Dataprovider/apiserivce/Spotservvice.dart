// spot_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parts/Dataprovider/model/spot_model.dart';

class SpotService {
  final spotsRef =
      FirebaseFirestore.instance.collection('spots').withConverter<Spot>(
            fromFirestore: (snapshot, _) => Spot.fromDocument(snapshot),
            toFirestore: (spot, _) => spot.toDocument(),
          );

  Future<QuerySnapshot<Spot>> fetchFirstSpots({int limit = 50}) {
    return spotsRef.limit(limit).get();
  }

  Future<QuerySnapshot<Spot>> fetchNextSpots({
    required DocumentSnapshot<Spot> lastDoc,
    int limit = 50,
  }) {
    return spotsRef.startAfterDocument(lastDoc).limit(limit).get();
  }
}
