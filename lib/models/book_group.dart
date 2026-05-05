import 'package:json_annotation/json_annotation.dart';
import 'json_helpers.dart';

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

  factory BookGroup.fromJson(Map<String, dynamic> json) => BookGroup(
        groupId: toInt(json['groupId']),
        groupName: toStringVal(json['groupName']),
        order: toInt(json['order']),
        show: toBool(json['show']),
      );

  Map<String, dynamic> toJson() => _$BookGroupToJson(this);
}
