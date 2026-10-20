import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cosplay_project_model.dart';
import '../services/cosplay_project_service.dart';
import '../services/firebase_storage.dart';

class CosplayProjectProvider with ChangeNotifier {
  final CosplayProjectService _service = CosplayProjectService();
  final StorageService _storageService = StorageService();

  List<CosplayProjectModel> _projects = [];
  List<CosplayProjectModel> _filteredProjects = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'semua'; // 'semua', 'anime', 'game', 'vtuber', 'manga', 'tokusatsu', 'other'
  String? _selectedEventId;
  bool _onlyOpenSlots = false;
  StreamSubscription<List<CosplayProjectModel>>? _projectsSub;

  List<CosplayProjectModel> get projects => _projects;
  List<CosplayProjectModel> get filteredProjects => _filteredProjects;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String? get selectedEventId => _selectedEventId;
  bool get onlyOpenSlots => _onlyOpenSlots;

  static const List<Map<String, String>> categoryOptions = [
    {'id': 'semua', 'label': 'Semua Kategori'},
    {'id': 'anime', 'label': 'Anime'},
    {'id': 'game', 'label': 'Game'},
    {'id': 'vtuber', 'label': 'VTuber'},
    {'id': 'manga', 'label': 'Manga / Manhwa'},
    {'id': 'tokusatsu', 'label': 'Tokusatsu'},
    {'id': 'other', 'label': 'Lainnya'},
  ];

  CosplayProjectProvider() {
    listenToProjects();
  }

  @override
  void dispose() {
    _projectsSub?.cancel();
    super.dispose();
  }

  void listenToProjects() {
    _isLoading = true;
    notifyListeners();

    _projectsSub?.cancel();
    _projectsSub = _service.streamProjects().listen(
      (data) {
        _projects = data;
        _applyFilters();
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('[CosplayProjectProvider] Error listening to projects: $err');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void setSelectedEventId(String? eventId) {
    _selectedEventId = eventId;
    _applyFilters();
  }

  void setOnlyOpenSlots(bool val) {
    _onlyOpenSlots = val;
    _applyFilters();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'semua';
    _selectedEventId = null;
    _onlyOpenSlots = false;
    _applyFilters();
  }

  void _applyFilters() {
    List<CosplayProjectModel> result = List.from(_projects);

    // Filter Kategori Seri
    if (_selectedCategory != 'semua') {
      result = result.where((p) => p.seriesCategory.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }

    // Filter Target Event
    if (_selectedEventId != null && _selectedEventId!.isNotEmpty) {
      result = result.where((p) => p.targetEventId == _selectedEventId).toList();
    }

    // Filter Hanya Slot Terbuka
    if (_onlyOpenSlots) {
      result = result.where((p) => p.openSlotsCount > 0 && p.status != 'full' && p.status != 'cancelled').toList();
    }

    // Filter Pencarian Teks
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((p) {
        final matchTitle = p.title.toLowerCase().contains(q);
        final matchSeries = p.seriesTitle.toLowerCase().contains(q);
        final matchEvent = (p.targetEventName ?? '').toLowerCase().contains(q);
        final matchCity = p.targetCityOrVenue.toLowerCase().contains(q);

        // Pencarian juga memeriksa apakah ada nama karakter yang cocok di dalam slot
        final matchCharacter = p.slots.any((s) =>
            s.characterName.toLowerCase().contains(q) ||
            s.characterVersion.toLowerCase().contains(q) ||
            s.categoryGroup.toLowerCase().contains(q));

        return matchTitle || matchSeries || matchEvent || matchCity || matchCharacter;
      }).toList();
    }

    _filteredProjects = result;
    notifyListeners();
  }

  /// Upload gambar (banner projek atau referensi slot)
  Future<String?> uploadImage(XFile? file, {required String folder, required String namePrefix}) async {
    if (file == null) return null;
    return await _storageService.uploadImage(file, folder, namePrefix);
  }

  /// Operasi Buat Projek
  Future<String> createProject(CosplayProjectModel project) async {
    final id = await _service.createProject(project);
    return id;
  }

  /// Operasi Update Projek
  Future<void> updateProject(CosplayProjectModel project) async {
    await _service.updateProject(project);
  }

  /// Operasi Hapus Projek
  Future<void> deleteProject(String projectId) async {
    await _service.deleteProject(projectId);
  }

  /// Mengajukan diri untuk slot
  Future<String> submitApplication({
    required String projectId,
    required String projectTitle,
    required String slotId,
    required String characterName,
    required String applicantUid,
    required String applicantUsername,
    required String applicantName,
    String applicantAvatar = '',
    String applicantCity = '',
    String applicantInstagram = '',
    String applicantWhatsApp = '',
    String message = '',
    String costumePhotoUrl = '',
  }) async {
    return await _service.submitApplication(
      projectId: projectId,
      projectTitle: projectTitle,
      slotId: slotId,
      characterName: characterName,
      applicantUid: applicantUid,
      applicantUsername: applicantUsername,
      applicantName: applicantName,
      applicantAvatar: applicantAvatar,
      applicantCity: applicantCity,
      applicantInstagram: applicantInstagram,
      applicantWhatsApp: applicantWhatsApp,
      message: message,
      costumePhotoUrl: costumePhotoUrl,
    );
  }

  /// Menyetujui Pelamar
  Future<void> approveApplication({
    required String projectId,
    required ProjectApplicationModel application,
  }) async {
    await _service.approveApplication(
      projectId: projectId,
      application: application,
    );
  }

  /// Menolak Pelamar
  Future<void> rejectApplication({
    required String applicationId,
    required String projectId,
    required String slotId,
  }) async {
    await _service.rejectApplication(
      applicationId: applicationId,
      projectId: projectId,
      slotId: slotId,
    );
  }

  /// Mengisi slot secara manual
  Future<void> assignSlotManually({
    required String projectId,
    required String slotId,
    required SlotFilledUser filledUser,
  }) async {
    await _service.assignSlotManually(
      projectId: projectId,
      slotId: slotId,
      filledUser: filledUser,
    );
  }

  /// Mengosongkan slot
  Future<void> vacateSlot({
    required String projectId,
    required String slotId,
  }) async {
    await _service.vacateSlot(
      projectId: projectId,
      slotId: slotId,
    );
  }

  /// Stream project tunggal realtime
  Stream<CosplayProjectModel?> streamProject(String projectId) {
    return _service.streamProject(projectId);
  }

  /// Stream daftar aplikasi/pelamar untuk satu projek
  Stream<List<ProjectApplicationModel>> streamApplicationsForProject(String projectId) {
    return _service.streamApplicationsForProject(projectId);
  }

  /// Stream projek buatan user
  Stream<List<CosplayProjectModel>> streamProjectsByCreator(String creatorUid) {
    return _service.streamProjectsByCreator(creatorUid);
  }

  /// Stream aplikasi milik user
  Stream<List<ProjectApplicationModel>> streamMyApplications(String userUid) {
    return _service.streamMyApplications(userUid);
  }
}
