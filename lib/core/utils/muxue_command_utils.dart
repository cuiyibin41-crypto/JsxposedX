import 'dart:convert';

class MuxueCommandUtils {
  const MuxueCommandUtils._();

  static String generated({required MuxueCommand command}) {
    return jsonEncode(command.toJson());
  }
}

class MuxueCommand {
  final int type;
  final int id;
  final String description;

  const MuxueCommand({
    required this.id,
    required this.description,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "description": description,
    "type": type,
  };
}

class MuxueCommandType {
  const MuxueCommandType._();

  static int get post => 0;

  static int get app => 1;
}
