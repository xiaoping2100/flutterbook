import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

import 'BaseSite.dart';

class ShenshuSite extends BaseSite {
  final String siteName = '神书网';
  final String siteUrl = 'http://www.shenshu.info';
  final String encoding = 'utf-8';
  final String searchUrl = 'http://www.shenshu.info/search/';

  Future<List<Book>> getBooks(String searchInfo, {Function callback}) async {
    books.clear();
    try {
      var r = await http.post(searchUrl,
          body: {'searchkey': searchInfo}); //中文不需要Uri.encodeFull(searchInfo)
      var doc = parse(utf8.decode(r.bodyBytes)); //utf8转码为字符串
//      print(doc.body.outerHtml);
      var trTags = doc.querySelectorAll("tr");
      if (trTags.length <= 1) {
        if (callback != null) callback(books);
        return books;
      }

      for (int i = 1; i < trTags.length; i++) {
        //第一个tr为表头，跳过
        var tdTags = trTags[i].querySelectorAll('td');
        var bookName = tdTags[0].querySelector('a').text.trim();
        var bookUrl =
            siteUrl + tdTags[0].querySelector('a').attributes["href"].trim();
        var bookAuthor = tdTags[2].querySelector('span').text.trim();
        books.add(Book(this, bookName, bookAuthor, bookUrl));
      }
    } catch (e) {
      print(e);
    }
    if (callback != null) {
      callback(books);
    }
    return books;
  }

  Future<List<Chapter>> getChapters(Book book, {Function callback}) async {
    chapters.clear();
    try {
      var r = await http.get(book.url);
      var doc = parse(utf8.decode(r.bodyBytes)); //utf8转码为字符串
      var items = doc.querySelector('#chapterlist').querySelectorAll('li');
      items.forEach((item) {
        chapters.add(Chapter(this, item.querySelector('a').text,
            siteUrl + item.querySelector('a').attributes['href']));
      });
    } catch (e) {
      print(e);
    }
    if (callback != null) {
      callback(chapters);
    }
    return chapters;
  }

  Future<String> getChapterContent(Chapter chapter, {Function callback}) async {
    String content = '';
    try {
      var r = await http.get(chapter.url);
      var doc = parse(utf8.decode(r.bodyBytes));
      var item = doc.querySelector('#book_text');
      content = item.text.trim();
    } catch (e) {
      print(e);
    }
    if (callback != null) {
      callback(content);
    }
    return content;
  }
}
