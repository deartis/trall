import 'package:flutter_map/flutter_map.dart';

void main() {
  // ignore: unused_local_variable
  final c = MapController();
  // We can't actually use MapController outside of a widget tree without throwing exceptions 
  // usually, but let's just see if it compiles or if we can use dart analyzer.
}
