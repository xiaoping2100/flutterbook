import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

import 'story.dart';
import 'bookSite/BaseSite.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Book',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Book'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key key, this.title}) : super(key: key) {
    requestPermission();
  }

  Future requestPermission() async {
    // 申请存储权限
    if (!await Permission.storage.isGranted) {
      Map<Permission, PermissionStatus> statuses =
          await [Permission.storage].request();
      print(statuses[Permission.storage]);
    }
  }

  createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> booksInfo = List();
  Function searchButtonFunc; //查询按钮的函数，null时未disable状态
  Function downloadButtonFunc; //下载按钮的函数，null时未disable状态
  var searchStateInfo = '查询状态';
  var downloadStateInfo = '下载状态';
  var selectBookInfo = '';
  var searchInfoController = TextEditingController(); //用户输入的查询信息
  Story story = getStory();

  initState() {
    super.initState();
  }

  dispose() {
    story.stopIsolate();
    super.dispose();
  }

  void updateBooks(List<Book> books) {
    for (int i = 0; i < books.length; i++) {
      var book = books[i];
      booksInfo.add('$i ${book.name} 作者:${book.author} ${book.site.siteName}');
    }
    searchStateInfo = '查询完成，共${books.length}本书籍';
    setState(() {});
  }

  void searchButtonPressed() {
    booksInfo.clear();
    selectBookInfo = '';
    downloadButtonFunc = null;
    downloadStateInfo = '下载状态';
    searchStateInfo = '查询开始,请稍候...';
    setState(() {});
    story.fetchBooks(searchInfoController.text, updateBooks);
  }

  void updateDownloadState(String info) {
    setState(() {
      downloadStateInfo = info;
    });
  }

  void downloadAsyncButtonPressed() async {
    assert(selectBookInfo.isNotEmpty);
    String directory = await ExtStorage.getExternalStoragePublicDirectory(
        ExtStorage.DIRECTORY_DOWNLOADS);
    story.downloadBookIsolate(directory, updateDownloadState);
  }

  Widget buildListData(BuildContext context, String titleItem) {
    return ListTile(
      title: Text(
        titleItem,
        style: TextStyle(fontSize: 12),
      ),
      // 创建点击事件
      onTap: () {
        setState(() {
          selectBookInfo = titleItem;
          story.choiceBook(int.parse(selectBookInfo.split(' ')[0]));
          downloadStateInfo = '下载状态';
          downloadButtonFunc = downloadAsyncButtonPressed;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            Row(
              children: [
                Text('请输入：'),
                Expanded(
                  child: TextField(
                    controller: searchInfoController,
                    decoration: InputDecoration(hintText: '书名或用户名'),
                    onChanged: (text) {
                      searchButtonFunc =
                          text.isEmpty ? null : searchButtonPressed;
                      searchStateInfo = '查询状态';
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                RaisedButton(
                  onPressed: searchButtonFunc,
                  child: Text('查询'),
                ),
                Text(searchStateInfo),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemBuilder: (context, item) {
                  return Container(
                    child: Column(
                      children: <Widget>[
                        buildListData(context, booksInfo[item]),
                        Divider()
                      ],
                    ),
                  );
                },
                itemCount: booksInfo.length, // 数据长度
              ),
            ),
            Row(children: [
              Expanded(
                  child: Text(selectBookInfo.isEmpty
                      ? '未选择小说'
                      : '选择小说为:$selectBookInfo')),
              RaisedButton(
                onPressed: downloadButtonFunc,
                child: Text('下载'),
              )
            ]),
            Row(
              children: [
                Expanded(child: Text(downloadStateInfo)),
                RaisedButton(
                  onPressed: (story.selectedBook)?.saveFileName == null
                      ? null
                      : () {
                          var file = story.selectedBook.saveFileName;
//                    var file = '/storage/emulated/0/Download/秀色田园-某某宝-奇书网.txt';
                          OpenFile.open(file);
                        },
                  child: Text('打开'),
                ),
              ],
            ),
          ],
        ),
      ),
//      floatingActionButton: FloatingActionButton(
//        onPressed: createPath,
//        tooltip: 'Increment',
//        child: Icon(Icons.storage),
//      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
