import '../models/guest.dart';
import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web_indexed.dart';

class GuestService {
  const GuestService();

  Future<int> insertGuest(Guest guest) {
    return nativeDb.insertGuest(guest);
  }

  Future<List<Guest>> getAllGuests() {
    return nativeDb.getAllGuests();
  }

  Future<Guest?> getGuestById(int id) {
    return nativeDb.getGuestById(id);
  }

  Future<Guest?> getGuestByName(String name) {
    return nativeDb.getGuestByName(name);
  }

  Future<int> updateGuest(Guest guest) {
    return nativeDb.updateGuest(guest);
  }

  Future<int> deleteGuest(int id) {
    return nativeDb.deleteGuest(id);
  }
}
