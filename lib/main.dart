import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_crud_app/create_task.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

final db = FirebaseFirestore.instance;
QuillController _controller = QuillController.basic();
String? title, desc, imgurl, date, stringImgUrl;
final TextEditingController _titleController = TextEditingController();
final TextEditingController _DescController = TextEditingController();
FirebaseStorage storage = FirebaseStorage.instance;
final FocusNode _focusNode = FocusNode();

final ImagePicker _picker = ImagePicker();
XFile? image = null;
File? selectedImage = null;
String selectedFileName = '';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    //appVersion();
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
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    var now = DateTime.now();
    var formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    String formattedDate = formatter.format(now);
    date = formattedDate;
    return Scaffold(
      bottomNavigationBar: FloatingActionButton(
        onPressed: () {
          _titleController.text = "";
          _DescController.text = "";
          setState(() {
            _controller = QuillController.basic();
            selectedImage = null;
          });
          showModalBottomSheet<dynamic>(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                return Container(
                    height: MediaQuery.of(context).size.height * 0.80,
                    child: showBottomSheet(context, false, null));
              });
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: Text('My CRUD App (' + _packageInfo.version + ')'),
        centerTitle: true,
      ),
      body: StreamBuilder(
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
                  direction: DismissDirection.horizontal,
                  resizeDuration: Duration(milliseconds: 200),
                  key: ObjectKey(snapshot.data.docs[index]),
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
                      showModalBottomSheet<dynamic>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return StatefulBuilder(builder:
                              (BuildContext context, StateSetter setState) {
                            return Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.80,
                                child: showBottomSheet(
                                    context, true, documentSnapshot));
                          });
                        },
                      );
                    },
                    trailing: Checkbox(
                      checkColor: Colors.white,
                      activeColor: Colors.red,
                      value: documentSnapshot['isDone'],
                      onChanged: (bool? value) {
                        db.collection('tasks').doc(documentSnapshot.id).update({
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
  var jsonNullData = null;
  if (isUpdate) {
    title = documentSnapshot!['title'];
    //selectedFileName = 'No image selected yet!';
    _titleController.text = documentSnapshot!['title'] ?? '';

    if (documentSnapshot['desc'] != null)
      stringImgUrl = documentSnapshot['img'];

    _controller = QuillController(
        document: Document.fromJson(documentSnapshot['desc']),
        selection: TextSelection.collapsed(offset: 0));
  }
  Reference storageRef;
  UploadTask uploadTask;
  return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
    return SizedBox(
        // height: MediaQuery.of(context).size.height * 0.80,
        child: SingleChildScrollView(
            child: Padding(
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
                        print('Image picked '),
                        setState(() {}),
                        // setState(() {
                        selectedImage = File(image!.path),
                        // selectedFileName = selectedImage.toString(),
                        storageRef = storage
                            .ref()
                            .child("image" + DateTime.now().toString()),
                        uploadTask = storageRef.putFile(selectedImage!),
                        uploadTask.then((res) async {
                          selectedFileName = await res.ref.getDownloadURL();
                          print(">>>>>>${await res.ref.getDownloadURL()}" +
                              res.ref.getDownloadURL().toString());
                        }),
                      },
                  child: Container(
                      height: 80,
                      width: 80,
                      child: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: isUpdate
                            ? documentSnapshot!['img'] != null
                                ? CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.transparent,
                                    backgroundImage:
                                        NetworkImage(documentSnapshot!['img']),
                                  )
                                : selectedImage != null
                                    ? CircleAvatar(
                                        radius: 40,
                                        backgroundImage: Image.file(
                                          selectedImage!,
                                          fit: BoxFit.cover,
                                        ).image,
                                      )
                                    : Icon(
                                        Icons.error,
                                        color: Colors.white,
                                        size: 40,
                                      )
                            : selectedImage != null
                                ? CircleAvatar(
                                    radius: 40,
                                    backgroundImage: Image.file(
                                      selectedImage!,
                                      fit: BoxFit.cover,
                                    ).image,
                                  )
                                : Icon(
                                    Icons.cloud_upload,
                                    color: Colors.white,
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
            height: 20,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Enter Description (Optional)'),
            ),
          ),
          Container(
              height: 300,
              width: MediaQuery.of(context).size.width * 0.9,
              child: Stack(
                children: [
                  SizedBox(
                    height: 20,
                  ),
                  Container(
                    height: 300,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white)),
                      child: Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: QuillEditor(
                            controller: isUpdate
                                ? QuillController(
                                    document: Document.fromJson(
                                        documentSnapshot!['desc']),
                                    selection:
                                        TextSelection.collapsed(offset: 0))
                                : _controller,
                            scrollController: ScrollController(),
                            scrollable: true,
                            focusNode: _focusNode,
                            autoFocus: false,
                            readOnly: false,
                            placeholder: 'Add your description here..',
                            expands: false,
                            padding: EdgeInsets.zero,
                          )),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 10, top: 5),
                    child: QuillToolbar.basic(
                      controller: _controller,
                      showUndo: false,
                      showRedo: false,
                      showFontSize: false,
                      showHeaderStyle: false,
                      showAlignmentButtons: false,
                      showBackgroundColorButton: false,
                      showCameraButton: false,
                      showClearFormat: false,
                      showCodeBlock: false,
                      showColorButton: false,
                      showDirection: false,
                      showDividers: false,
                      showImageButton: false,
                      showIndent: false,
                      showInlineCode: false,
                      showQuote: false,
                      showVideoButton: false,
                      showStrikeThrough: false,
                      showSmallButton: false,
                      showListNumbers: true,
                      showListCheck: false,
                    ),
                  ),
                ],
              )),
          SizedBox(
            height: 10,
          ),
          TextButton(
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all(Colors.lightBlueAccent),
              ),
              onPressed: () {
                if (isUpdate) {
                  db.collection('tasks').doc(documentSnapshot?.id).update({
                    'title': title,
                    'desc': _controller.document.toDelta().toJson(),
                    'date': date,
                    'img': selectedFileName,
                    // 'isDone': false,
                  });
                } else {
                  db.collection('tasks').add({
                    'title': title,
                    'isDone': false,
                    'desc': _controller.document.toDelta().toJson(),
                    'date': date,
                    'img': selectedFileName,
                  });
                }
                Navigator.pop(context);
              },
              child: isUpdate
                  ? Text(
                      'UPDATE',
                      style: TextStyle(color: Colors.white),
                    )
                  : Text('ADD', style: TextStyle(color: Colors.white))),
          SizedBox(
            height: 30,
          ),
          if (isUpdate)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Date:- ${isUpdate ? documentSnapshot!['date'] : 'Today'}'),
              ),
            ),
          SizedBox(
            height: 10,
          ),
          if (isUpdate)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Date:- ${stringImgUrl}'),
              ),
            ),
          SizedBox(
            height: 500,
          ),
        ],
      ),
    )));
  });
}

decode(documentSnapshot) async {
  var list = await jsonDecode(documentSnapshot);
  print("<<<" + list);
  return list;
}
