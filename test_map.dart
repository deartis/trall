import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final c = MapController();
  // We can't actually use MapController outside of a widget tree without throwing exceptions 
  // usually, but let's just see if it compiles or if we can use dart analyzer.
}
