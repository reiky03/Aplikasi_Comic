// This is a generated file - do not edit.
//
// Generated from repository_index.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use contentWarningDescriptor instead')
const ContentWarning$json = {
  '1': 'ContentWarning',
  '2': [
    {'1': 'CONTENT_WARNING_UNSPECIFIED', '2': 0},
    {'1': 'CONTENT_WARNING_SAFE', '2': 1},
    {'1': 'CONTENT_WARNING_MIXED', '2': 2},
    {'1': 'CONTENT_WARNING_NSFW', '2': 3},
  ],
};

/// Descriptor for `ContentWarning`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List contentWarningDescriptor = $convert.base64Decode(
    'Cg5Db250ZW50V2FybmluZxIfChtDT05URU5UX1dBUk5JTkdfVU5TUEVDSUZJRUQQABIYChRDT0'
    '5URU5UX1dBUk5JTkdfU0FGRRABEhkKFUNPTlRFTlRfV0FSTklOR19NSVhFRBACEhgKFENPTlRF'
    'TlRfV0FSTklOR19OU0ZXEAM=');

@$core.Deprecated('Use indexDescriptor instead')
const Index$json = {
  '1': 'Index',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'badgeLabel', '3': 2, '4': 1, '5': 9, '10': 'badgeLabel'},
    {'1': 'signingKey', '3': 3, '4': 1, '5': 9, '10': 'signingKey'},
    {'1': 'contact', '3': 4, '4': 1, '5': 11, '6': '.Contact', '10': 'contact'},
    {
      '1': 'extensionList',
      '3': 101,
      '4': 1,
      '5': 11,
      '6': '.ExtensionList',
      '9': 0,
      '10': 'extensionList'
    },
    {
      '1': 'extensionListUrl',
      '3': 102,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'extensionListUrl'
    },
  ],
  '8': [
    {'1': 'extensions'},
  ],
};

/// Descriptor for `Index`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List indexDescriptor = $convert.base64Decode(
    'CgVJbmRleBISCgRuYW1lGAEgASgJUgRuYW1lEh4KCmJhZGdlTGFiZWwYAiABKAlSCmJhZGdlTG'
    'FiZWwSHgoKc2lnbmluZ0tleRgDIAEoCVIKc2lnbmluZ0tleRIiCgdjb250YWN0GAQgASgLMggu'
    'Q29udGFjdFIHY29udGFjdBI2Cg1leHRlbnNpb25MaXN0GGUgASgLMg4uRXh0ZW5zaW9uTGlzdE'
    'gAUg1leHRlbnNpb25MaXN0EiwKEGV4dGVuc2lvbkxpc3RVcmwYZiABKAlIAFIQZXh0ZW5zaW9u'
    'TGlzdFVybEIMCgpleHRlbnNpb25z');

@$core.Deprecated('Use contactDescriptor instead')
const Contact$json = {
  '1': 'Contact',
  '2': [
    {'1': 'website', '3': 1, '4': 1, '5': 9, '10': 'website'},
    {
      '1': 'discord',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'discord',
      '17': true
    },
  ],
  '8': [
    {'1': '_discord'},
  ],
};

/// Descriptor for `Contact`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contactDescriptor = $convert.base64Decode(
    'CgdDb250YWN0EhgKB3dlYnNpdGUYASABKAlSB3dlYnNpdGUSHQoHZGlzY29yZBgCIAEoCUgAUg'
    'dkaXNjb3JkiAEBQgoKCF9kaXNjb3Jk');

@$core.Deprecated('Use extensionListDescriptor instead')
const ExtensionList$json = {
  '1': 'ExtensionList',
  '2': [
    {
      '1': 'extensions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.Extension',
      '10': 'extensions'
    },
  ],
};

/// Descriptor for `ExtensionList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List extensionListDescriptor = $convert.base64Decode(
    'Cg1FeHRlbnNpb25MaXN0EioKCmV4dGVuc2lvbnMYASADKAsyCi5FeHRlbnNpb25SCmV4dGVuc2'
    'lvbnM=');

@$core.Deprecated('Use extensionDescriptor instead')
const Extension$json = {
  '1': 'Extension',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'packageName', '3': 2, '4': 1, '5': 9, '10': 'packageName'},
    {
      '1': 'resources',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.Resources',
      '10': 'resources'
    },
    {'1': 'extensionLib', '3': 4, '4': 1, '5': 9, '10': 'extensionLib'},
    {'1': 'versionCode', '3': 5, '4': 1, '5': 3, '10': 'versionCode'},
    {'1': 'versionName', '3': 6, '4': 1, '5': 9, '10': 'versionName'},
    {
      '1': 'contentWarning',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.ContentWarning',
      '10': 'contentWarning'
    },
    {'1': 'sources', '3': 8, '4': 3, '5': 11, '6': '.Source', '10': 'sources'},
  ],
};

/// Descriptor for `Extension`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List extensionDescriptor = $convert.base64Decode(
    'CglFeHRlbnNpb24SEgoEbmFtZRgBIAEoCVIEbmFtZRIgCgtwYWNrYWdlTmFtZRgCIAEoCVILcG'
    'Fja2FnZU5hbWUSKAoJcmVzb3VyY2VzGAMgASgLMgouUmVzb3VyY2VzUglyZXNvdXJjZXMSIgoM'
    'ZXh0ZW5zaW9uTGliGAQgASgJUgxleHRlbnNpb25MaWISIAoLdmVyc2lvbkNvZGUYBSABKANSC3'
    'ZlcnNpb25Db2RlEiAKC3ZlcnNpb25OYW1lGAYgASgJUgt2ZXJzaW9uTmFtZRI3Cg5jb250ZW50'
    'V2FybmluZxgHIAEoDjIPLkNvbnRlbnRXYXJuaW5nUg5jb250ZW50V2FybmluZxIhCgdzb3VyY2'
    'VzGAggAygLMgcuU291cmNlUgdzb3VyY2Vz');

@$core.Deprecated('Use resourcesDescriptor instead')
const Resources$json = {
  '1': 'Resources',
  '2': [
    {'1': 'apkUrl', '3': 1, '4': 1, '5': 9, '10': 'apkUrl'},
    {'1': 'iconUrl', '3': 2, '4': 1, '5': 9, '10': 'iconUrl'},
    {'1': 'jarUrl', '3': 501, '4': 1, '5': 9, '10': 'jarUrl'},
  ],
};

/// Descriptor for `Resources`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resourcesDescriptor = $convert.base64Decode(
    'CglSZXNvdXJjZXMSFgoGYXBrVXJsGAEgASgJUgZhcGtVcmwSGAoHaWNvblVybBgCIAEoCVIHaW'
    'NvblVybBIXCgZqYXJVcmwY9QMgASgJUgZqYXJVcmw=');

@$core.Deprecated('Use sourceDescriptor instead')
const Source$json = {
  '1': 'Source',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'language', '3': 3, '4': 1, '5': 9, '10': 'language'},
    {'1': 'homeUrl', '3': 4, '4': 1, '5': 9, '10': 'homeUrl'},
    {'1': 'mirrorUrls', '3': 5, '4': 3, '5': 9, '10': 'mirrorUrls'},
    {
      '1': 'message',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'message',
      '17': true
    },
  ],
  '8': [
    {'1': '_message'},
  ],
};

/// Descriptor for `Source`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sourceDescriptor = $convert.base64Decode(
    'CgZTb3VyY2USDgoCaWQYASABKANSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSGgoIbGFuZ3VhZ2'
    'UYAyABKAlSCGxhbmd1YWdlEhgKB2hvbWVVcmwYBCABKAlSB2hvbWVVcmwSHgoKbWlycm9yVXJs'
    'cxgFIAMoCVIKbWlycm9yVXJscxIdCgdtZXNzYWdlGAcgASgJSABSB21lc3NhZ2WIAQFCCgoIX2'
    '1lc3NhZ2U=');
