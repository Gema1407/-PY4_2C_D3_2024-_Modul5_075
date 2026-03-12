/// AccessPolicy: Gatekeeper sederhana sesuai prinsip Open-Closed (SOLID).
/// Mudah dikembangkan — tinggal tambah 'case' baru tanpa merombak UI.
class AccessPolicy {
  static bool canPerform(String role, String action) {
    switch (role) {
      case 'Ketua':
        return true; // Ketua bisa semua (Full CRUD)
      case 'Anggota':
        // Anggota hanya bisa Create, Read, atau edit miliknya sendiri
        return ['create', 'read'].contains(action);
      case 'Asisten':
        // Asisten bisa Read dan Update (tidak bisa Create/Delete)
        return ['read', 'update'].contains(action);
      default:
        return false;
    }
  }

  /// Data Ownership Check — user hanya bisa edit datanya sendiri
  static bool canEditOwn(String role, String action, bool isOwner) {
    if (role == 'Ketua') return true;
    if (isOwner && ['update', 'delete'].contains(action)) return true;
    return canPerform(role, action);
  }
}
