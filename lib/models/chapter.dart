import 'package:json_annotation/json_annotation.dart';

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

  factory Chapter.fromJson(Map<String, dynamic> json) =>
      _$ChapterFromJson(json);
  Map<String, dynamic> toJson() => _$ChapterToJson(this);
}
