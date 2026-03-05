import 'package:act08/database_helper.dart';
import 'package:act08/models/card.dart';
import 'package:act08/models/folder.dart';
import 'package:act08/repository/card_repository.dart';
import 'package:act08/repository/folder_repository.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Card Organizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7A7A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F3EE),
        fontFamily: 'Georgia',
        useMaterial3: true,
      ),
      home: const FoldersScreen(),
    );
  }
}

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final FolderRepository _folderRepository = FolderRepository();
  final CardRepository _cardRepository = CardRepository();
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;
  List<_FolderSummary> _folders = <_FolderSummary>[];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final folders = await _folderRepository.getAllFolders();
      final counts = await Future.wait(
        folders.map((folder) {
          return _cardRepository.getCardCountByFolder(folder.id!);
        }),
      );

      final summaries = <_FolderSummary>[];
      for (int i = 0; i < folders.length; i++) {
        summaries.add(_FolderSummary(folder: folders[i], cardCount: counts[i]));
      }

      setState(() {
        _folders = summaries;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load folders.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncFromDeckApi() async {
    setState(() {
      _isSyncing = true;
      _error = null;
    });

    try {
      await _databaseHelper.syncCardsFromApi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cards refreshed from Deck of Cards API.'),
        ),
      );
      await _loadFolders();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Sync failed. Check your internet connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _openFolder(Folder folder) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CardsScreen(folder: folder)),
    );
    await _loadFolders();
  }

  Future<void> _confirmDeleteFolder(_FolderSummary summary) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Folder?'),
          content: Text(
            'Deleting ${summary.folder.folderName} will also delete '
            '${summary.cardCount} related card(s) because cascade deletion is enabled.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Delete Folder'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _folderRepository.deleteFolder(summary.folder.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${summary.folder.folderName} deleted.')),
    );
    await _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1000
        ? 4
        : width >= 700
        ? 3
        : 2;
    final childAspectRatio = width < 380
        ? 0.88
        : width < 480
        ? 0.98
        : 1.12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suit Folders'),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _syncFromDeckApi,
            tooltip: 'Sync from API',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6EFE6), Color(0xFFE7F1EF)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _folders.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final summary = _folders[index];
                  final accent = _suitColor(summary.folder.folderName);

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openFolder(summary.folder),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: accent.withValues(
                                    alpha: 0.14,
                                  ),
                                  child: Text(
                                    _suitIcon(summary.folder.folderName),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Delete folder',
                                  onPressed: () =>
                                      _confirmDeleteFolder(summary),
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              summary.folder.folderName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${summary.cardCount} cards',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Open folder',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward,
                                  color: accent,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key, required this.folder});

  final Folder folder;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final CardRepository _cardRepository = CardRepository();

  bool _isLoading = true;
  List<PlayingCard> _cards = <PlayingCard>[];

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    final cards = await _cardRepository.getCardsByFolderId(widget.folder.id!);
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
  }

  Future<void> _openAddEdit({PlayingCard? card}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AddEditCardScreen(initialFolderId: widget.folder.id!, card: card),
      ),
    );

    if (changed == true) {
      await _loadCards();
    }
  }

  Future<void> _deleteCard(PlayingCard card) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Card?'),
          content: Text(
            'This will permanently remove ${card.cardName} of ${card.suit}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await _cardRepository.deleteCard(card.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${card.cardName} deleted.')));
    await _loadCards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.folder.folderName} Cards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6EFE6), Color(0xFFE7F1EF)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _cards.isEmpty
            ? const Center(child: Text('No cards in this folder yet.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _CardImage(imageUrl: card.imageUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.cardName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  card.suit,
                                  style: TextStyle(
                                    color: _suitColor(card.suit),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit card',
                            onPressed: () => _openAddEdit(card: card),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete card',
                            onPressed: () => _deleteCard(card),
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemCount: _cards.length,
              ),
      ),
    );
  }
}

class AddEditCardScreen extends StatefulWidget {
  const AddEditCardScreen({
    super.key,
    required this.initialFolderId,
    this.card,
  });

  final int initialFolderId;
  final PlayingCard? card;

  @override
  State<AddEditCardScreen> createState() => _AddEditCardScreenState();
}

class _AddEditCardScreenState extends State<AddEditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  final FolderRepository _folderRepository = FolderRepository();
  final CardRepository _cardRepository = CardRepository();

  static const List<String> _suits = <String>[
    'Hearts',
    'Diamonds',
    'Clubs',
    'Spades',
  ];

  List<Folder> _folders = <Folder>[];
  String _selectedSuit = 'Hearts';
  int? _selectedFolderId;
  bool _isSaving = false;

  bool get _isEdit => widget.card != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.card?.cardName ?? '';
    _imageController.text = widget.card?.imageUrl ?? '';
    _selectedSuit = widget.card?.suit ?? 'Hearts';
    _selectedFolderId = widget.card?.folderId ?? widget.initialFolderId;
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await _folderRepository.getAllFolders();
    if (!mounted) return;

    final selectedStillExists = folders.any((f) => f.id == _selectedFolderId);
    setState(() {
      _folders = folders;
      if (!selectedStillExists && folders.isNotEmpty) {
        _selectedFolderId = folders.first.id;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFolderId == null) return;

    setState(() {
      _isSaving = true;
    });

    final card = PlayingCard(
      id: widget.card?.id,
      cardName: _nameController.text.trim(),
      suit: _selectedSuit,
      imageUrl: _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
      folderId: _selectedFolderId!,
    );

    if (_isEdit) {
      await _cardRepository.updateCard(card);
    } else {
      await _cardRepository.insertCard(card);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Card' : 'Add Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Card name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Card name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedSuit,
                decoration: const InputDecoration(
                  labelText: 'Suit',
                  border: OutlineInputBorder(),
                ),
                items: _suits
                    .map(
                      (suit) => DropdownMenuItem<String>(
                        value: suit,
                        child: Text(suit),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedSuit = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _selectedFolderId,
                decoration: const InputDecoration(
                  labelText: 'Folder assignment',
                  border: OutlineInputBorder(),
                ),
                items: _folders
                    .map(
                      (folder) => DropdownMenuItem<int>(
                        value: folder.id,
                        child: Text(folder.folderName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFolderId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a folder.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 62,
        height: 86,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 62,
      height: 86,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7DC),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.style_outlined),
    );
  }
}

class _FolderSummary {
  const _FolderSummary({required this.folder, required this.cardCount});

  final Folder folder;
  final int cardCount;
}

String _suitIcon(String suit) {
  switch (suit.toLowerCase()) {
    case 'hearts':
      return '♥';
    case 'diamonds':
      return '♦';
    case 'clubs':
      return '♣';
    case 'spades':
      return '♠';
    default:
      return '?';
  }
}

Color _suitColor(String suit) {
  switch (suit.toLowerCase()) {
    case 'hearts':
    case 'diamonds':
      return const Color(0xFFB31B1B);
    case 'clubs':
    case 'spades':
      return const Color(0xFF1F2937);
    default:
      return const Color(0xFF334155);
  }
}
