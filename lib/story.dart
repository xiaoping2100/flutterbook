import 'dart:io';
import 'dart:isolate';

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
  Book selectedBook;
  List<Chapter> chapters = [];

//  String saveFileName = "";
  Isolate isolate;

  void registerSite(BaseSite site) {
    sites.add(site);
  }

  void stopIsolate() {
    isolate?.kill(priority: Isolate.immediate);
    isolate = null;
  }

  void fetchBooks(String searchInfo, Function callback) async {
    books.clear();
    selectedBook = null;

    var futures = <Future>[];
    for (var site in sites)
      futures.add(site.getBooks(searchInfo, callback: (List<Book> data) {
        books.addAll(data);
      }));
    await Future.wait(futures);
    callback(books);
  }

  void choiceBook(int index) {
    selectedBook = books[index];
  }

//
//  void fetchChapters() {
//    selectedBook.site.getChapters(selectedBook);
//  }
//
//  Future<String> fetchChapterContent(Chapter chapter) {
//    return chapter.site.getChapterContent(chapter);
//  }

  Future<void> downloadBookIsolate(String directory, Function callback) async {
    final receivePort1 = ReceivePort();
    final sendPort1 = receivePort1.sendPort;

    isolate = await Isolate.spawn(_downloadBookIsolate, sendPort1);
    receivePort1.listen((data) {
      //循环获取消息
      if (data is SendPort) {
        final sendPort2 = data;
        sendPort2.send([selectedBook, directory]); //发送site和目录信息
      } else if (data is Book) {
        selectedBook = data;
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

  static void _downloadBookIsolate(SendPort sendPort1) async {
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

    // STEP3 配置回调函数，闭包函数类型，便于传递索引值index
    var completedCountList = [0]; //计数器，统计getChapterContent的完成任务数
    List<String> contents; //保存getChapterContent的结果
    Function callback(int index) {
      void inner(String chapterContent) {
        completedCountList[0]++;
        contents[index] = chapterContent;
      }

      return inner;
    }

    // STEP4 获取章节信息
    var chapters = await site.getChapters(selectedBook);
    sendPort1.send('共${chapters.length}个章节,请稍候...');

    // STEP5 根据chapter的URL下载内容
    contents = List(chapters.length);
    int start = DateTime.now().millisecondsSinceEpoch;
    var futures = <Future>[];
    for (var i = 0; i < chapters.length; i++) {
      futures.add(site.getChapterContent(
        chapters[i],
        callback: callback(i),
      ));
    }
    Future.wait(futures);
    while (true) {
      //循环检查进度，注意不能使用阻塞的sleep函数等待
      await Future.delayed(Duration(seconds: 1), () {
        sendPort1.send('${completedCountList[0]}/${chapters.length}完成');
      });
      if (completedCountList[0] == chapters.length) break;
    }
    int end = DateTime.now().millisecondsSinceEpoch;
    print('下载耗时: ${end - start}');
    sendPort1.send('下载${chapters.length}个章节，耗时${(end - start) / 1000}秒');

    // STEP6 保存为文件
    //sendPort1.send('开始写入文件');
    int start2 = DateTime.now().millisecondsSinceEpoch;
    var fileName =
        '${selectedBook.name}-${selectedBook.author}-${site.siteName}.txt';
    File f = File('$directory/$fileName');
    IOSink isk = f.openWrite(mode: FileMode.writeOnly);
    for (int i = 0; i < chapters.length; i++) {
      isk.writeln(chapters[i].title);
      isk.writeln(contents[i]);
    }
    await await isk.close();
    int end2 = DateTime.now().millisecondsSinceEpoch;
    print('写文件耗时: ${end2 - start2}');
    sendPort1.send('写文件耗时${(end2 - start2) / 1000}秒，文件名:$fileName');

    // STEP7 回传book信息
    sendPort1.send(selectedBook);

    // STEP8 发送任务结束消息，关闭接口
    sendPort1.send(Story.FINISH_FLAG_STRING);
    receivePort2.close();
    print('_downloadBookIsolate quit');
  }
}
