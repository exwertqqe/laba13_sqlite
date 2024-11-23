import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NotesHomePage(),
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  _NotesHomePageState createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  late Database _database; // Змінна для роботи з SQLite
  final TextEditingController _noteController = TextEditingController(); // Контролер для поля вводу нотаток
  final _formKey = GlobalKey<FormState>(); // Ключ форми для валідації
  List<Map<String, dynamic>> _notes = []; // Список нотаток

  @override
  void initState() {
    super.initState();
    _initializeDatabase(); // Підгрузка бд при запуску
  }

  Future<void> _initializeDatabase() async {
    // Відкриття БД
    _database = await openDatabase(
      join(await getDatabasesPath(), 'notes.db'), // Шлях до БД
      onCreate: (db, version) {
        // запит для створення таблиці якщо її немає
        return db.execute(
          '''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            date_created TEXT NOT NULL
          )
          ''',
        );
      },
      version: 1,
    );
    _loadNotes(); // Завантаження нотаток після створення БД
  }

  Future<void> _loadNotes() async {
    final List<Map<String, dynamic>> notes = await _database.query(
      'notes',
      orderBy: 'id DESC', // LIFO: останній зверху
    );
    setState(() {
      _notes = notes; // Оновлення стану з отриманими нотатками
    });
  }
// додавання нотатки
  Future<void> _addNote() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Отримуємо поточну дату
      final now = DateTime.now();
      // Форматуємо її як "день/місяць/рік"
      final formattedDate = "${now.day.toString().padLeft(2, '0')}/"
          "${now.month.toString().padLeft(2, '0')}/"
          "${now.year}";

      // Додаємо запис у базу
      await _database.insert(
        'notes',
        {
          'content': _noteController.text,
          'date_created': formattedDate, // Зберігаємо у форматі "день/місяць/рік"
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Очищуємо поле введення і оновлюємо список нотаток
      _noteController.clear();
      _loadNotes();
    }
  }

  // Видалення нотатки за її ідентифікатором
  Future<void> _deleteNote(int id) async {
    await _database.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadNotes();
  }

  @override
  void dispose() {
    _database.close();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your note here',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Note cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addNote,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _notes.isEmpty
                  ? const Center(child: Text('No notes available'))
                  : ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  return Card(
                    child: ListTile(
                      title: Text(note['content']),
                      subtitle: Text(note['date_created']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteNote(note['id']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
