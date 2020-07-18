abstract class BaseSite {
  String siteName;
  List<Book> books =[];
  int selectedBookIndex = -1;
  List<Chapter> chapters=[];
  List<String> chapterContents =[];

  Future<List<Book>> getBooks(String searchInfo, {Function callback});

  Future<List<Chapter>> getChapters(Book book, {Function callback});

  Future<String> getChapterContent(Chapter chapter, {Function callback});  
}

class Book {
  BaseSite site;
  String name, author, url;

  Book(this.site, this.name, this.author, this.url);
}

class Chapter {
  BaseSite site;
  String title, url;

  Chapter(this.site, this.title, this.url);
}
