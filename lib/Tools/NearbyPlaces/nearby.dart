// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;

// void main() => runApp(SearchPlacesApp());

// class SearchPlacesApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: SearchPlacesScreen(),
//     );
//   }
// }

// class SearchPlacesScreen extends StatefulWidget {
//   @override
//   _SearchPlacesScreenState createState() => _SearchPlacesScreenState();
// }

// class _SearchPlacesScreenState extends State<SearchPlacesScreen> {
//   Position? _currentPosition;
//   String? _searchQuery;
//   List<Place> _places = [];
//   Place? _nearestPlace;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _getCurrentLocation();
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       bool serviceEnabled;
//       LocationPermission permission;

//       // Periksa apakah layanan lokasi aktif
//       serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         throw Exception('Location services are disabled.');
//       }

//       // Periksa dan minta izin lokasi
//       permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           throw Exception('Location permissions are denied.');
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         throw Exception('Location permissions are permanently denied.');
//       }

//       // Ambil posisi pengguna
//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       setState(() {
//         _currentPosition = position;
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//       });
//     }
//   }

//   Future<void> _searchPlaces(String query) async {
//     if (_currentPosition == null) {
//       setState(() {
//         _error = 'Unable to get your current location.';
//       });
//       return;
//     }

//     final lat = _currentPosition!.latitude;
//     final lon = _currentPosition!.longitude;

//     // Definisikan bounding box di sekitar lokasi pengguna
//     final latMin = lat - 0.05;
//     final latMax = lat + 0.05;
//     final lonMin = lon - 0.05;
//     final lonMax = lon + 0.05;

//     final url =
//         "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=30&viewbox=$lonMin,$latMin,$lonMax,$latMax&bounded=1";
//     final response = await http.get(Uri.parse(url));

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body) as List<dynamic>;
//       final places = data.map((json) => Place.fromJson(json)).toList();

//       setState(() {
//         _places = places.where((place) {
//           final distance = _calculateDistance(
//             lat,
//             lon,
//             place.latitude,
//             place.longitude,
//           );
//           return distance <= 10; // Radius maksimum 10 km
//         }).toList();

//         _nearestPlace = _findNearestPlace(lat, lon, _places);
//       });
//     } else {
//       setState(() {
//         _error = 'Failed to fetch places data.';
//       });
//     }
//   }

//   Place _findNearestPlace(double lat, double lon, List<Place> places) {
//     return places.reduce((a, b) {
//       final distanceA = _calculateDistance(lat, lon, a.latitude, a.longitude);
//       final distanceB = _calculateDistance(lat, lon, b.latitude, b.longitude);
//       return distanceA < distanceB ? a : b;
//     });
//   }

//   double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
//     const R = 6371; // Radius of the Earth in km
//     final dLat = _degToRad(lat2 - lat1);
//     final dLon = _degToRad(lon2 - lon1);
//     final a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
//     final c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return R * c; // Distance in km
//   }

//   double _degToRad(double deg) => deg * (pi / 180);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Search Places (OSM)'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(16.0),
//               color: Colors.blue[100],
//               child: _currentPosition == null
//                   ? _error != null
//                       ? Text('Error: $_error')
//                       : Text('Your location: Fetching...')
//                   : Text(
//                       'Your location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}'),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               decoration: InputDecoration(
//                 labelText: 'Search places',
//                 border: OutlineInputBorder(),
//               ),
//               onSubmitted: (value) {
//                 _searchPlaces(value);
//               },
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: _places.length,
//                 itemBuilder: (context, index) {
//                   final place = _places[index];
//                   return ListTile(
//                     title: Text(place.name ?? 'Unnamed place'),
//                     subtitle: Text('${place.latitude}, ${place.longitude}'),
//                   );
//                 },
//               ),
//             ),
//             if (_nearestPlace != null)
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text(
//                   'Nearest Place: ${_nearestPlace!.name} (${_nearestPlace!.latitude}, ${_nearestPlace!.longitude})',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class Place {
//   final String? name;
//   final double latitude;
//   final double longitude;

//   Place({this.name, required this.latitude, required this.longitude});

//   factory Place.fromJson(Map<String, dynamic> json) {
//     return Place(
//       name: json['display_name'],
//       latitude: double.parse(json['lat']),
//       longitude: double.parse(json['lon']),
//     );
//   }
// }
