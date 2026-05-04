import 'package:json_annotation/json_annotation.dart';

part 'book_group.g.dart';

@JsonSerializable()
class BookGroup {
  @JsonKey(name: 'groupId')
  int? groupId;

  @JsonKey(name: 'groupName')
  String? groupName;

  @JsonKey(name: 'order')
  int? order;

  @JsonKey(name: 'show')
  bool? show;

  BookGroup({
    this.groupId,
    this.groupName,
    this.order,
    this.show,
  });

  factory BookGroup.fromJson(Map<String, dynamic> json) =>
      _$BookGroupFromJson(json);
  Map<String, dynamic> toJson() => _$BookGroupToJson(this);
}
