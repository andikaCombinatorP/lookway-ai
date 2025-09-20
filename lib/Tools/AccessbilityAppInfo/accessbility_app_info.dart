// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:linkara_02/Constant/color.dart';


// class AccessibilityPage extends StatefulWidget {
//   const AccessibilityPage({super.key});

//   @override
//   State<AccessibilityPage> createState() => _AccessibilityPageState();
// }

// class _AccessibilityPageState extends State<AccessibilityPage> {
//   final List<Map<String, String>> links = [
//     {
//       'title': 'Android Accessibility Apps',
//       'url': 'https://translate.google.com/translate?hl=id&sl=auto&tl=id&u=https://www.razmobility.com/android-accessibility-applications/'
//     },
//     {
//       'title': 'iOS Accessibility Apps',
//       'url': 'https://translate.google.com/translate?hl=id&sl=auto&tl=id&u=https://www.razmobility.com/ios-accessibility-applications/'
//     },
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Accessibility Apps Info',style: TextStyle(color: Colors.white),),
//         backgroundColor: AppColors.primaryColor,
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Padding(
//             padding: EdgeInsets.all(16.0),
//             child: Text(
//               "Temukan aplikasi aksesibilitas terbaik untuk pengguna Android dan iOS. "
//               "Kami menyediakan tautan ke sumber daya resmi yang dapat membantu meningkatkan pengalaman Anda.",
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
//             ),
//           ),
//           Expanded(
//             child: ListView.builder(
//               itemCount: links.length,
//               itemBuilder: (context, index) {
//                 return Card(
//                   margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   child: ListTile(
//                     title: Text(
//                       links[index]['title']!,
//                       style: const TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     trailing: const Icon(Icons.arrow_forward),
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => AccessibilityWebView(
//                             url: links[index]['url']!,
//                             title: links[index]['title']!,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class AccessibilityWebView extends StatelessWidget {
//   final String url;
//   final String title;

//   const AccessibilityWebView({
//     super.key,
//     required this.url,
//     required this.title,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(title),
//         backgroundColor: Colors.blue,
//       ),
//       body: InAppWebView(
//         initialUrlRequest: URLRequest(url: WebUri(url)),
//         initialOptions: InAppWebViewGroupOptions(
//           crossPlatform: InAppWebViewOptions(
//             javaScriptEnabled: true, // Mengaktifkan JavaScript
//           ),
//         ),
//       ),
//     );
//   }
// }
