import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart'; // Import the package

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Connectivity Demo',
      home: ConnectivityPage(),
    );
  }
}

class ConnectivityPage extends StatefulWidget {
  @override
  _ConnectivityPageState createState() => _ConnectivityPageState();
}

class _ConnectivityPageState extends State<ConnectivityPage> {
  String _connectionStatus = 'Presiona el botón para verificar la conexión';
  TextEditingController _nameController = TextEditingController();
  String _enteredName = "";

  Future<void> checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.mobile) {
        updateStatus('Conectado a Internet a través de una red móvil');
      } else if (connectivityResult == ConnectivityResult.wifi) {
        updateStatus('Conectado a Internet a través de Wi-Fi');
      } else {
        updateStatus('No conectado a Internet');
      }
    } catch (e) {
      updateStatus('No se pudo verificar la conectividad: $e');
    }
  }

  void updateStatus(String status) {
    setState(() {
      _connectionStatus = status;
      if (_connectionStatus.contains('Conectado')) {
        showToast('Conexión restaurada');
      }
    });
  }

  Future<void> sendDataToServer(String name) async {
    try {
      final response = await http.post(
        Uri.parse('https://pruebas.septlaxcala.gob.mx/app/envio.php'), // Replace with your server URL and endpoint
        body: {
          'name': name,
        },
      );

      if (response.statusCode == 200) {
        print('Datos enviados al servidor con éxito');
        print('Respuesta del servidor: ${response.body}');
      } else {
        print('Error al enviar datos al servidor. Código de estado: ${response.statusCode}');
        print('Mensaje de error: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void attemptToSendData() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi) {
      sendDataToServer(_enteredName);
    } else {
      // Save data locally
      DatabaseHelper.instance.insert({
        DatabaseHelper.columnName: _enteredName
      });
      updateStatus('Sin conexión a Internet. Datos guardados localmente.');
    }
  }

  // Show toast message
  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Connectivity Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Nombre: $_enteredName'),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Ingrese su nombre',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _enteredName = _nameController.text;
                  _nameController.clear();
                  attemptToSendData();
                });
              },
              child: Text('Enviar'),
            ),
            SizedBox(height: 20),
            // Display locally stored data
            FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.queryAllRows(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No hay datos almacenados localmente.');
                } else {
                  // Display locally stored data
                  List<String> names = [];
                  for (var data in snapshot.data!) {
                    names.add(data[DatabaseHelper.columnName]);
                  }
                  return Column(
                    children: [
                      Text('Datos almacenados localmente:'),
                      for (var name in names) Text(name),
                    ],
                  );
                }
              },
            ),
            ElevatedButton(
              onPressed: () {
                checkConnectivity();
              },
              child: Text('Verificar Conexión'),
            ),
          ],
        ),
      ),
    );
  }
}

// Database helper class
class DatabaseHelper {
  static final _databaseName = "MyDatabase.db";
  static final _databaseVersion = 1;
  static final table = "my_table";
  static final columnId = 'id';
  static final columnName = 'name';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL
      )
    ''');
  }

  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table);
  }
}
