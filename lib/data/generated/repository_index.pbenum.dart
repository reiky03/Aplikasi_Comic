// This is a generated file - do not edit.
//
// Generated from repository_index.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ContentWarning extends $pb.ProtobufEnum {
  static const ContentWarning CONTENT_WARNING_UNSPECIFIED =
      ContentWarning._(0, _omitEnumNames ? '' : 'CONTENT_WARNING_UNSPECIFIED');
  static const ContentWarning CONTENT_WARNING_SAFE =
      ContentWarning._(1, _omitEnumNames ? '' : 'CONTENT_WARNING_SAFE');
  static const ContentWarning CONTENT_WARNING_MIXED =
      ContentWarning._(2, _omitEnumNames ? '' : 'CONTENT_WARNING_MIXED');
  static const ContentWarning CONTENT_WARNING_NSFW =
      ContentWarning._(3, _omitEnumNames ? '' : 'CONTENT_WARNING_NSFW');

  static const $core.List<ContentWarning> values = <ContentWarning>[
    CONTENT_WARNING_UNSPECIFIED,
    CONTENT_WARNING_SAFE,
    CONTENT_WARNING_MIXED,
    CONTENT_WARNING_NSFW,
  ];

  static final $core.List<ContentWarning?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ContentWarning? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ContentWarning._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
