import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';

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
  bool _showUploadButton = false;

  @override
  void initState() {
    super.initState();
    checkLocalDataOnStart();
  }

  Future<void> checkLocalDataOnStart() async {
    List<Map<String, dynamic>> localData = await DatabaseHelper.instance.queryAllRows();
    if (localData.isNotEmpty) {
      showToast('Hay datos almacenados localmente.');
      setState(() {
        _showUploadButton = true;
      });
    }
  }

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
        showToast('Conectado a internet');
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
      showToast('No hay conexión a Internet. Datos guardados localmente.');
      DatabaseHelper.instance.insert({
        DatabaseHelper.columnName: _enteredName
      });
      updateStatus('Sin conexión a Internet. Datos guardados localmente.');
      setState(() {
        _showUploadButton = true;
      });
    }
  }

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
  Future<void> uploadLocalData() async {
    List<Map<String, dynamic>> localData = await DatabaseHelper.instance.queryAllRows();
    for (var data in localData) {
      String name = data[DatabaseHelper.columnName];
      await sendDataToServer(name);
    }
    await DatabaseHelper.instance.deleteAllRows();
    setState(() {
      _showUploadButton = false;
    });
    showToast('Datos subidos al servidor con éxito.');
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
            if (_showUploadButton)
              ElevatedButton(
                onPressed: () {
                  uploadLocalData();
                },
                child: Text('Subir al Servidor'),
              ),
          ],
        ),
      ),
    );
  }
}

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

  Future<void> deleteAllRows() async {
    Database db = await instance.database;
    await db.delete(table);
  }
}
