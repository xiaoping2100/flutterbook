import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

import 'BaseSite.dart';

class IqishuSite extends BaseSite {
  final String siteName = '奇书网';
  final String siteUrl = 'http://www.iqishu.la';
  final String encoding = 'utf-8';
  final String searchUrl = 'http://www.iqishu.la/search.html?searchkey=';

  Future<List<Book>> getBooks(String searchInfo, {Function callback}) async {
    books.clear();
    try {
      var url = Uri.encodeFull(searchUrl + searchInfo); //等价于python的parse.quote
      var r = await http.get(url);
      var doc = parse(utf8.decode(r.bodyBytes)); //utf8转码为字符串
      var trTags = doc.querySelectorAll("tr");
      if (trTags.length <= 1) {
        if (callback != null) callback(books);
        return books;
      }

      for (int i = 1; i < trTags.length; i++) {
        //第一个tr为表头，跳过
        var tdTags = trTags[i].querySelectorAll('td');
        var bookName = tdTags[1]
            .querySelector('a')
            .text
            .trim();
        var bookUrl =
            siteUrl + tdTags[1]
                .querySelector('a')
                .attributes["href"].trim();
        var bookAuthor = tdTags[2].text.trim();
//          rights[i].querySelectorAll(".info>span")[1].text.trim(),
//          rights[i].querySelector(".last>a").attributes["href"].trim(), //href 属性值，最后一章的Url
//          rights[i].querySelector(".last>a").text.trim(), //元素值，获取标题
        books.add(Book(this, bookName, bookAuthor, bookUrl));
      }
    } catch (e) {
      print(e);
    }
    if (callback != null) callback(books);
    return books;
  }

  Future<List<Chapter>> getChapters(Book book, {Function callback}) async {
    chapters.clear();
    try {
      var r1 = await http.get(book.url);
      var doc1 = parse(r1.body);
      var realUrl = siteUrl +
          doc1
              .querySelector('div.detail_right')
              .querySelector('a')
              .attributes["href"]
              .trim();
      var r2 = await http.get(realUrl);
      var doc2 = parse(utf8.decode(r2.bodyBytes));
      var items = doc2
          .querySelectorAll('div#info>div.pc_list')[1]
          .querySelectorAll('ul>li');
      items.forEach((item) {
        chapters.add(Chapter(this, item
            .querySelector('a')
            .text,
            realUrl + item
                .querySelector('a')
                .attributes['href']));
      });
    } catch (e) {
      print('getChapters:$e');
    }
    if (callback != null) {
      callback(chapters);
    }
    return chapters;
  }

  Future<String> getChapterContent(Chapter chapter, {Function callback}) async {
    var r = await http.get(chapter.url);
    var doc = parse(utf8.decode(r.bodyBytes));
    var item = doc.querySelector('div#content1');
    item.querySelectorAll('p.sitetext').forEach((subItem) {
      subItem.remove();
    });
    String content = item.text.trim();
    chapter.content = content;
    if (callback != null) callback(content);
    return content;
  }
}
