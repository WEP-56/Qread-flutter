class Bookmark {
  final String? id;
  final String? bookUrl;
  final String? chapterName;
  final int? chapterIndex;
  final double? chapterPos;
  final String? createTime;

  const Bookmark({
    this.id,
    this.bookUrl,
    this.chapterName,
    this.chapterIndex,
    this.chapterPos,
    this.createTime,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id']?.toString(),
      bookUrl: json['boolurl']?.toString() ?? json['bookUrl']?.toString(),
      chapterName: json['cname']?.toString(),
      chapterIndex: json['cindex'] is int ? json['cindex'] : int.tryParse(json['cindex']?.toString() ?? ''),
      chapterPos: json['cpos'] is double ? json['cpos'] : double.tryParse(json['cpos']?.toString() ?? ''),
      createTime: json['createtime']?.toString(),
    );
  }
}
