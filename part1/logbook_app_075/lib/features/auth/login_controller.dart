// login_controller.dart
class LoginController {
  // Username mencerminkan role masing-masing anggota tim
  final Map<String, String> _credentials = {
    "ketua": "ketua123", // Role: Ketua    — Full CRUD
    "anggota": "anggota123", // Role: Anggota  — Create & Read (+ own data)
    "asisten": "asisten123", // Role: Asisten  — Read & Update (+ own data)
    "admin1": "123",
    "admin2": "1234",
  };

  final Map<String, String> _roles = {
    "ketua_075": "Ketua",
    "anggota_075": "Anggota",
    "asisten_075": "Asisten",
    // Akun lama
    "admin1": "Ketua",
    "admin2": "Anggota",
  };

  bool login(String username, String password) {
    return _credentials[username] == password;
  }

  String getRole(String username) {
    return _roles[username] ?? 'Anggota';
  }
}
