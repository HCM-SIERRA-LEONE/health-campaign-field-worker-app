// Singleton class for managing bednet class selection

class BednetClassSelectionSingleton {
  static final BednetClassSelectionSingleton _singleton =
      BednetClassSelectionSingleton._internal();

  factory BednetClassSelectionSingleton() {
    return _singleton;
  }

  BednetClassSelectionSingleton._internal();

  String? _selectedClass;

  void setSelectedClass({required String? selectedClass}) {
    _selectedClass = selectedClass;
  }

  String? get selectedClass => _selectedClass;

  void clear() {
    _selectedClass = null;
  }
}
