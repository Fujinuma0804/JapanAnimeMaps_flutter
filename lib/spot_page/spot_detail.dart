// import 'package:flutter/material.dart';
// import 'package:parts/Dataprovider/model/spot_model.dart';
// import 'package:parts/spot_page/spot.dart';

// class SpotDetailScreen extends StatelessWidget {
//   final Spot spot;

//   const SpotDetailScreen({Key? key, required this.spot}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           spot.title,
//           style: const TextStyle(
//             color: Colors.black,
//           ),
//         ),
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 画像の読み込みにエラーが発生した場合のフォールバック処理
//           Image.asset(
//             spot.imagePath,
//             width: double.infinity,
//             height: 200,
//             fit: BoxFit.cover,
//             errorBuilder: (context, error, stackTrace) {
//               return Container(
//                 width: double.infinity,
//                 height: 200,
//                 color: Colors.grey,
//                 child: const Center(
//                   child: Text('Image not found'),
//                 ),
//               );
//             },
//           ),
//           const SizedBox(height: 16),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Text(
//               spot.title,
//               style: const TextStyle(
//                 fontSize: 20,
//               ),
//               textAlign: TextAlign.left,
//             ),
//           ),
//           const SizedBox(height: 20.0),
//           Center(
//             child: Column(
//               children: [
//                 if (spot.text != null)
//                   Text(
//                     spot.text!,
//                     style: const TextStyle(
//                       fontSize: 15.0,
//                     ),
//                   ),
//                 const SizedBox(height: 35.0),
//                 TextButton(
//                   onPressed: () {},
//                   child: const Text(
//                     '地図で場所を確認する',
//                     style: TextStyle(
//                       color: Color(0xFF00008b),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
