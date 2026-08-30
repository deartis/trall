import '../models/truck_profile.dart';

class TruckProfileService {
  TruckProfileService._();
  static final TruckProfileService instance = TruckProfileService._();

  TruckProfile _currentProfile = TruckProfilePresets.truck;

  TruckProfile get currentProfile => _currentProfile;

  void selectProfile(TruckProfile profile) {
    _currentProfile = profile;
  }
}
