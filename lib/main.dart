import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_crud_app/create_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

final db = FirebaseFirestore.instance;
String? title, desc, imgurl, date;
final TextEditingController _titleController = TextEditingController();
final TextEditingController _DescController = TextEditingController();
FirebaseStorage storage = FirebaseStorage.instance;

final ImagePicker _picker = ImagePicker();
XFile? image = null;
File? selectedImage = null;
String selectedFileName = 'No image selected yet!';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My CRUD App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: MyHomePage(),
      //
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late bool valueIsDone = false;
  @override
  Widget build(BuildContext context) {
    var now = DateTime.now();
    var formatter = DateFormat('yyyy-MM-dd');
    String formattedDate = formatter.format(now);
    //print(formattedDate);
    date = formattedDate;
    return Scaffold(
      bottomNavigationBar: FloatingActionButton(
        onPressed: () {
          // When the User clicks on the button, display a BottomSheet
          _titleController.text = "";
          _DescController.text = "";
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return showBottomSheet(context, false, null);
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('My CRUD App'),
        centerTitle: true,
      ),
      body: StreamBuilder(
        // Reading Items form our Database Using the StreamBuilder widget
        stream: db
            .collection(
              'tasks',
            )
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return ListView.builder(
            itemCount: snapshot.data?.docs.length,
            itemBuilder: (context, int index) {
              DocumentSnapshot documentSnapshot = snapshot.data.docs[index];
              return Dismissible(
                  direction: DismissDirection.startToEnd,
                  resizeDuration: Duration(milliseconds: 200),
                  key: ObjectKey(snapshot.data.docs[index]),
                  //key: ObjectKey(snapshot.documents.elementAt(index)),
                  onDismissed: (direction) {
                    _deleteMessage(index, documentSnapshot.id);
                  },
                  child: ListTile(
                    title: Text(
                      documentSnapshot['title'],
                      style: TextStyle(
                          decoration: documentSnapshot['isDone']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none),
                    ),
                    onTap: () {
                      // Here We Will Add The Update Feature and passed the value 'true' to the is update
                      // feature.
                      showModalBottomSheet(
                        context: context,
                        builder: (BuildContext context) {
                          return showBottomSheet(
                              context, true, documentSnapshot);
                        },
                      );
                    },
                    trailing: Checkbox(
                      checkColor: Colors.white,
                      activeColor: Colors.red,
                      value: documentSnapshot['isDone'],
                      onChanged: (bool? value) {
                        db.collection('tasks').doc(documentSnapshot.id).update({
                          // 'title': value,
                          'isDone': !documentSnapshot['isDone'],
                        });
                        setState(() {
                          valueIsDone = value ?? true;
                        });
                      },
                    ),
                  ));
            },
          );
        },
      ),
    );
  }

  _deleteMessage(index, var documentSnapshotid) {
    setState(() {
      db.collection('tasks').doc(documentSnapshotid).delete();
    });
  }
}

showBottomSheet(
    BuildContext context, bool isUpdate, DocumentSnapshot? documentSnapshot) {
  // Added the isUpdate argument to check if our item has been updated

  if (isUpdate) {
    _titleController.text = documentSnapshot!['title'] ?? '';
    _DescController.text = documentSnapshot['desc'] == null
        ? ''
        : documentSnapshot['desc'] + "\n\n\n Date:-" + documentSnapshot['date'];
  }
  Reference storageRef;
  UploadTask uploadTask;
  return Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      children: [
        SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: InkWell(
                onTap: () async => {
                      print('Picking an image'),
                      image = (await ImagePicker()
                          .pickImage(source: ImageSource.gallery)),

                      print('Image picked $selectedImage'),
                      // setState(() {
                      selectedImage = File(image!.path),
                      selectedFileName = selectedImage.toString(),

                      storageRef = storage
                          .ref()
                          .child("image" + DateTime.now().toString()),
                      uploadTask = storageRef.putFile(selectedImage!),
                      uploadTask.then((res) {
                        res.ref.getDownloadURL();
                        print(">>>>>>" + res.ref.getDownloadURL().toString());
                      }),
                    },
                child: Container(
                    height: 80,
                    width: 80,
                    child: CircleAvatar(
                      child: Icon(
                        Icons.cloud_upload,
                        size: 40,
                      ),
                    )))),
        SizedBox(
          height: 10,
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: TextField(
            controller: _titleController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: isUpdate ? 'Update Task' : 'Add Task',
              hintText: 'Enter Title',
            ),
            onChanged: (String _val) {
              title = _val;
            },
          ),
        ),
        SizedBox(
          height: 10,
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: TextField(
            controller: _DescController,
            maxLines: 5,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                // Used a ternary operator to check if isUpdate is true then display
                // Update Todo.
                labelText: 'Description',
                hintText: 'Enter Description (Optional)',
                hintMaxLines: 5),
            onChanged: (String _val) {
              desc = _val;
            },
          ),
        ),
        TextButton(
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.all(Colors.lightBlueAccent),
            ),
            onPressed: () {
              // Check to see if isUpdate is true then update the value else add the value
              if (isUpdate) {
                db.collection('tasks').doc(documentSnapshot?.id).update({
                  'title': title,
                  'desc': desc,
                  'date': date,
                  'img': selectedImage,
                  // 'isDone': false,
                });
              } else {
                db.collection('tasks').add({
                  'title': title,
                  'isDone': false,
                  'desc': desc,
                  'date': date,
                  'img': selectedFileName,
                });
              }
              Navigator.pop(context);
            },
            child: isUpdate
                ? const Text(
                    'UPDATE',
                    style: TextStyle(color: Colors.white),
                  )
                : const Text('ADD', style: TextStyle(color: Colors.white))),
      ],
    ),
  );
}
