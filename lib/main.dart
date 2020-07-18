import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bookSite/test.dart' as test;
import 'IqishuSite.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key key, this.title}) : super(key: key) {
    requestPermission();
  }

  Future requestPermission() async {
    // 申请权限
    if (!await Permission.storage.isGranted) {
      Map<Permission, PermissionStatus> statuses =
          await [Permission.storage].request();
      print(statuses[Permission.storage]);
    }
  }

  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var site = IqishuSite();
  List bookItems = List();
  Function searchButtonFunc; //查询按钮的函数，null时未diable状态
  Function downloadButtonFunc; //下载按钮的函数，null时未diable状态
  var searchStateInfo = '查询状态';
  var downloadStateInfo = '下载状态';
  var selectBookInfo = '';
  var searchInfoController = TextEditingController(); //用户输入的查询信息
  Isolate isolate;

  initState() {
    super.initState();
  }

  dispose() {
    isolate?.kill(priority: Isolate.immediate);
    isolate = null;
    super.dispose();
  }

  void updateBooks(List<Book> books) {
    for (int i = 0; i < books.length; i++) {
      var book = books[i];
      bookItems.add('$i ${book.name} 作者:${book.author} ${book.site.siteName}');
    }
    searchStateInfo = '查询完成，共${books.length}本书籍';
    setState(() {});
    print('updateBooks complete');
  }

  void searchButtonPressed() {
    bookItems.clear();
    selectBookInfo = '';
    downloadButtonFunc = null;
    downloadStateInfo = '下载状态';
    searchStateInfo = '查询开始,请稍候...';
    setState(() {});
    site.getBooks(searchInfoController.text, updateCallBack: updateBooks);
    print('searchButtonPressed complete');
  }

  void updateDownloadState(String info) {
    setState(() {
      downloadStateInfo = info;
    });
  }

  void downloadButtonPressed() {
    assert(selectBookInfo.isNotEmpty);
    downloadBook(updateDownloadState);
  }

  Future<void> downloadBook(Function updateCallBack) async {
    Function chapterContentCallback(
        List<String> chapterContents, int chaptersLength, Function callback) {
      // 两重闭包函数
      // 外层传入：待更新的章节内容列表chapterContents，
      //          章节数量chaptersLength， 章节下载状态更新函数callback
      // 内层传入：chapter的索引值chapterIndex
      var completedCountList = [0]; //已下载完成的章节数量，使用list便于修改
      chapterContents.clear();
      chapterContents.addAll(List.filled(chaptersLength, ''));
      Function inner(int chapterIndex) {
        void inner2(String chapterContent) {
          chapterContents[chapterIndex] = chapterContent;
          completedCountList[0]++;
          updateCallBack('完成${completedCountList[0]}/$chaptersLength个章节...');
        }

        return inner2;
      }

      return inner;
    }

    //STEP1 下载chapter的TITLE和URL
    searchButtonFunc = null;
    downloadButtonFunc = null;
    updateCallBack('下载开始,请稍候...');
    int index = int.parse(selectBookInfo.split(' ')[0]);
    site.selectedBook = site.books[index];

    var chapters = await site.getChapters(site.selectedBook);
    List<String> contents = List();
    updateCallBack('共${chapters.length}个章节,请稍候...');

    // STEP2 根据chapter的URL下载内容
    int start = DateTime.now().millisecondsSinceEpoch;
    var futures = <Future>[];
    var updateCallBack2 =
        chapterContentCallback(contents, chapters.length, updateCallBack);
    for (int i = 0; i < chapters.length; i++) {
      futures.add(site.getChapterContent(
        chapters[i],
        updateCallBack: updateCallBack2(i),
      ));
    }
    await Future.wait(futures);
    int end = DateTime.now().millisecondsSinceEpoch;
    print('下载耗时: ${end - start}');
    updateCallBack('下载完成，共${chapters.length}个章节，耗时${(end - start) / 1000}秒');

    // STEP3 保存为文件
    updateCallBack('开始写入文件');
    int start2 = DateTime.now().millisecondsSinceEpoch;
    String path = await ExtStorage.getExternalStoragePublicDirectory(
        ExtStorage.DIRECTORY_DOWNLOADS);
    var fileName =
        '${site.selectedBook.name}-${site.selectedBook.author}-${site.siteName}.txt';
    File f = File('$path/$fileName');
    IOSink isk = f.openWrite(mode: FileMode.writeOnly);
    for (int i = 0; i < chapters.length; i++) {
      isk.writeln(chapters[i].title);
      isk.writeln(contents[i]);
    }
    await await isk.close();
    ;
    int end2 = DateTime.now().millisecondsSinceEpoch;
    print('写文件耗时: ${end2 - start2}');
    updateCallBack('写文件耗时${(end2 - start2) / 1000}秒，文件名:$fileName');
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
          downloadStateInfo = '下载状态';
          downloadButtonFunc = downloadButtonPressed;
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
                        buildListData(context, bookItems[item]),
                        Divider()
                      ],
                    ),
                  );
                },
                itemCount: bookItems.length, // 数据长度
              ),
            ),
            Text(selectBookInfo.isEmpty ? '未选择小说' : '选择小说为:$selectBookInfo'),
            Row(
              children: [
                RaisedButton(
                  onPressed: downloadButtonFunc,
                  child: Text('下载'),
                ),
                Expanded(child: Text(downloadStateInfo)),
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
