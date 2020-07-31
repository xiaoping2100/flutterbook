import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';

import 'bookSite/BaseSite.dart';
import 'bookSite/IqishuSite.dart';
import 'bookSite/ShenshuSite.dart';

Story getStory() {
  var story = Story();
  story.registerSite(IqishuSite());
  story.registerSite(ShenshuSite());
  return story;
}

class Story {
  static const FINISH_FLAG_STRING = 'finish';
  List<BaseSite> sites = [];
  List<Book> books = [];
  int selectedIndex;
  List<Chapter> chapters = [];

  Isolate isolate;

  void registerSite(BaseSite site) {
    this.sites.add(site);
  }

  void stopIsolate() {
    isolate?.kill(priority: Isolate.immediate);
    isolate = null;
  }

  void fetchBooks(String searchInfo, Function callback) async {
    this.books.clear();
    this.selectedIndex = null;

    var futures = <Future>[];
    for (var site in sites)
      futures.add(site.getBooks(searchInfo, callback: (List<Book> data) {
        books.addAll(data);
      }));
    await Future.wait(futures);
    callback(books);
  }

  Future<void> downloadBookIsolate(String directory, Function callback) async {
    final receivePort1 = ReceivePort();
    final sendPort1 = receivePort1.sendPort;

    isolate = await Isolate.spawn(_downloadBookIsolateTask, sendPort1);
    receivePort1.listen((data) {
      //循环获取消息
      if (data is SendPort) {
        final sendPort2 = data;
        sendPort2
            .send([this.books[this.selectedIndex], directory]); //发送site和目录信息
      } else if (data is Book) {
        this.books[this.selectedIndex] = data;
        callback();
      } else if (data is String) {
        if (data == Story.FINISH_FLAG_STRING) {
          //任务执行结束，退出
          receivePort1.close();
          print('downloadBookIsolate quit');
          return;
        } else {
          callback(data);
        }
      } else {
        assert(false);
      }
    },
        onError: (e) => print(e),
        onDone: () => print("downloadBookIsolate done"));
  }
}

class DataBloc {
  final int globalMaxParallel = 10;
  final List<Chapter> chapters;
  final List<int> completedCountList;

  ///定义一个Controller
  StreamController<List> _dataController = StreamController<List>();

  ///获取 StreamSink 做 add 入口
  StreamSink<List> get _dataSink => _dataController.sink;

  ///获取 Stream 用于监听
  Stream<List> get _dataStream => _dataController.stream;

  ///事件订阅对象
  StreamSubscription _dataSubscription;

  DataBloc.fromChapters(this.chapters, this.completedCountList) {
    //每个chapter的retry次数
    List<int> retryCountList = [for (var _ in this.chapters) 0];
    int nextIndex = globalMaxParallel;

    ///监听事件
    _dataSubscription = _dataStream.listen((data) {
      var ret = data[0] as bool;
      var index = data[1] as int;
      var content = data[2];

      if (ret || retryCountList[index] >= 3) {
        //下载成功 或 下载失败且重试次数大于3
        if (!ret) print("chapter $index 下载失败");
        ++this.completedCountList[0];
        this.chapters[index].content = content;
        if (nextIndex < this.chapters.length) {
          downLoadChapterByIndex(nextIndex);
          ++nextIndex;
        }
      } else {
        //下载失败且重试次数小于3次
        ++retryCountList[index];
        downLoadChapterByIndex(index);
      }
    });
  }

  void downLoadChapterByIndex(int index) {
    var chapter = this.chapters[index];
    chapter.site
        .getChapterContent(chapter)
        .then((value) => this.add([true, index, value]))
        .timeout(Duration(seconds: 30))
        .catchError((e) => this.add([false, index, "下载失败"]));
  }

  void add(List event) {
    _dataSink.add(event);
  }

  void close() {
    ///关闭
    _dataSubscription.cancel();
    _dataController.close();
  }
}

void _downloadBookIsolateTask(SendPort sendPort1) async {
  int startTime = DateTime.now().millisecondsSinceEpoch;
  num usedTimes() => (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;

// STEP1 发送sendPort给调用程序，便于传递参数
  final receivePort2 = ReceivePort();
  final sendPort2 = receivePort2.sendPort;
  sendPort1.send(sendPort2);

// STEP2 获取参数
  var message = await receivePort2.first as List;
//    await for (var message in receivePort2) {} //循环访问
  var selectedBook = message[0] as Book;
  var directory = message[1] as String;
  var site = selectedBook.site;

// STEP3 获取章节信息
  var chapters = await site.getChapters(selectedBook);
  sendPort1.send('共${chapters.length}个章节,请稍候...,已耗时:${usedTimes()}秒');

// STEP4 根据chapter的URL下载内容
  var completedCountList = [0]; //计数器，统计getChapterContent的完成任务数
  DataBloc dataBloc = DataBloc.fromChapters(chapters, completedCountList);
  var length = dataBloc.globalMaxParallel;
  if (chapters.length < dataBloc.globalMaxParallel) length = chapters.length;
  for (var i = 0; i < length; i++) dataBloc.downLoadChapterByIndex(i);
  while (true) {
    //循环检查进度，注意不能使用阻塞的sleep函数等待
    await Future.delayed(Duration(seconds: 1), () {
      sendPort1.send(
          '${completedCountList[0]}/${chapters.length}完成，已耗时:${usedTimes()}秒');
    });
    if (completedCountList[0] >= chapters.length) break;
  }
  dataBloc.close();
  sendPort1.send('下载${chapters.length}个章节，已耗时:${usedTimes()}秒');

// STEP5 保存为文件
  sendPort1.send('开始写入文件,已耗时:${usedTimes()}秒');
  selectedBook.saveFileName =
      '$directory/${selectedBook.name}-${selectedBook.author}-${site.siteName}.txt';
  File f = File(selectedBook.saveFileName);
  IOSink isk = f.openWrite(mode: FileMode.writeOnly);
  for (int i = 0; i < chapters.length; i++) {
    isk.writeln(chapters[i].title);
    isk.writeln(chapters[i].content);
  }
  await await isk.close();
  sendPort1.send('写入文件名:${selectedBook.saveFileName}，已耗时:${usedTimes()}秒');

// STEP6 回传book信息
  sendPort1.send(selectedBook);

// STEP8 发送任务结束消息，关闭接口
  sendPort1.send(Story.FINISH_FLAG_STRING);
  receivePort2.close();
  print('_downloadBookIsolate quit');
}
