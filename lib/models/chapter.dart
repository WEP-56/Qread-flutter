import 'package:json_annotation/json_annotation.dart';
import 'json_helpers.dart';

part 'chapter.g.dart';

@JsonSerializable()
class Chapter {
  @JsonKey(name: 'bookUrl')
  String? bookUrl;

  @JsonKey(name: 'title')
  String? title;

  @JsonKey(name: 'chapterIndex')
  int? chapterIndex;

  @JsonKey(name: 'isVolume')
  bool? isVolume;

  @JsonKey(name: 'isVip')
  bool? isVip;

  @JsonKey(name: 'resourceUrl')
  String? resourceUrl;

  @JsonKey(name: 'tag')
  String? tag;

  Chapter({
    this.bookUrl,
    this.title,
    this.chapterIndex,
    this.isVolume,
    this.isVip,
    this.resourceUrl,
    this.tag,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        bookUrl: toStringVal(json['bookUrl']),
        title: toStringVal(json['title']),
        chapterIndex: toInt(json['chapterIndex']),
        isVolume: toBool(json['isVolume']),
        isVip: toBool(json['isVip']),
        resourceUrl: toStringVal(json['resourceUrl']),
        tag: toStringVal(json['tag']),
      );

  Map<String, dynamic> toJson() => _$ChapterToJson(this);
}
