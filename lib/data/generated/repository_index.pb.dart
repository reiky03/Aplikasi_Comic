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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'repository_index.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'repository_index.pbenum.dart';

enum Index_Extensions { extensionList, extensionListUrl, notSet }

class Index extends $pb.GeneratedMessage {
  factory Index({
    $core.String? name,
    $core.String? badgeLabel,
    $core.String? signingKey,
    Contact? contact,
    ExtensionList? extensionList,
    $core.String? extensionListUrl,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (badgeLabel != null) result.badgeLabel = badgeLabel;
    if (signingKey != null) result.signingKey = signingKey;
    if (contact != null) result.contact = contact;
    if (extensionList != null) result.extensionList = extensionList;
    if (extensionListUrl != null) result.extensionListUrl = extensionListUrl;
    return result;
  }

  Index._();

  factory Index.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Index.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Index_Extensions> _Index_ExtensionsByTag = {
    101: Index_Extensions.extensionList,
    102: Index_Extensions.extensionListUrl,
    0: Index_Extensions.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Index',
      createEmptyInstance: create)
    ..oo(0, [101, 102])
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'badgeLabel', protoName: 'badgeLabel')
    ..aOS(3, _omitFieldNames ? '' : 'signingKey', protoName: 'signingKey')
    ..aOM<Contact>(4, _omitFieldNames ? '' : 'contact',
        subBuilder: Contact.create)
    ..aOM<ExtensionList>(101, _omitFieldNames ? '' : 'extensionList',
        protoName: 'extensionList', subBuilder: ExtensionList.create)
    ..aOS(102, _omitFieldNames ? '' : 'extensionListUrl',
        protoName: 'extensionListUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Index clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Index copyWith(void Function(Index) updates) =>
      super.copyWith((message) => updates(message as Index)) as Index;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Index create() => Index._();
  @$core.override
  Index createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Index getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Index>(create);
  static Index? _defaultInstance;

  @$pb.TagNumber(101)
  @$pb.TagNumber(102)
  Index_Extensions whichExtensions() =>
      _Index_ExtensionsByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(101)
  @$pb.TagNumber(102)
  void clearExtensions() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get badgeLabel => $_getSZ(1);
  @$pb.TagNumber(2)
  set badgeLabel($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBadgeLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearBadgeLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get signingKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set signingKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSigningKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearSigningKey() => $_clearField(3);

  @$pb.TagNumber(4)
  Contact get contact => $_getN(3);
  @$pb.TagNumber(4)
  set contact(Contact value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasContact() => $_has(3);
  @$pb.TagNumber(4)
  void clearContact() => $_clearField(4);
  @$pb.TagNumber(4)
  Contact ensureContact() => $_ensure(3);

  @$pb.TagNumber(101)
  ExtensionList get extensionList => $_getN(4);
  @$pb.TagNumber(101)
  set extensionList(ExtensionList value) => $_setField(101, value);
  @$pb.TagNumber(101)
  $core.bool hasExtensionList() => $_has(4);
  @$pb.TagNumber(101)
  void clearExtensionList() => $_clearField(101);
  @$pb.TagNumber(101)
  ExtensionList ensureExtensionList() => $_ensure(4);

  @$pb.TagNumber(102)
  $core.String get extensionListUrl => $_getSZ(5);
  @$pb.TagNumber(102)
  set extensionListUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(102)
  $core.bool hasExtensionListUrl() => $_has(5);
  @$pb.TagNumber(102)
  void clearExtensionListUrl() => $_clearField(102);
}

class Contact extends $pb.GeneratedMessage {
  factory Contact({
    $core.String? website,
    $core.String? discord,
  }) {
    final result = create();
    if (website != null) result.website = website;
    if (discord != null) result.discord = discord;
    return result;
  }

  Contact._();

  factory Contact.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Contact.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Contact',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'website')
    ..aOS(2, _omitFieldNames ? '' : 'discord')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Contact clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Contact copyWith(void Function(Contact) updates) =>
      super.copyWith((message) => updates(message as Contact)) as Contact;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Contact create() => Contact._();
  @$core.override
  Contact createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Contact getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Contact>(create);
  static Contact? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get website => $_getSZ(0);
  @$pb.TagNumber(1)
  set website($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWebsite() => $_has(0);
  @$pb.TagNumber(1)
  void clearWebsite() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get discord => $_getSZ(1);
  @$pb.TagNumber(2)
  set discord($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDiscord() => $_has(1);
  @$pb.TagNumber(2)
  void clearDiscord() => $_clearField(2);
}

class ExtensionList extends $pb.GeneratedMessage {
  factory ExtensionList({
    $core.Iterable<Extension>? extensions,
  }) {
    final result = create();
    if (extensions != null) result.extensions.addAll(extensions);
    return result;
  }

  ExtensionList._();

  factory ExtensionList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExtensionList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExtensionList',
      createEmptyInstance: create)
    ..pPM<Extension>(1, _omitFieldNames ? '' : 'extensions',
        subBuilder: Extension.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtensionList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtensionList copyWith(void Function(ExtensionList) updates) =>
      super.copyWith((message) => updates(message as ExtensionList))
          as ExtensionList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExtensionList create() => ExtensionList._();
  @$core.override
  ExtensionList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExtensionList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExtensionList>(create);
  static ExtensionList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Extension> get extensions => $_getList(0);
}

class Extension extends $pb.GeneratedMessage {
  factory Extension({
    $core.String? name,
    $core.String? packageName,
    Resources? resources,
    $core.String? extensionLib,
    $fixnum.Int64? versionCode,
    $core.String? versionName,
    ContentWarning? contentWarning,
    $core.Iterable<Source>? sources,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (packageName != null) result.packageName = packageName;
    if (resources != null) result.resources = resources;
    if (extensionLib != null) result.extensionLib = extensionLib;
    if (versionCode != null) result.versionCode = versionCode;
    if (versionName != null) result.versionName = versionName;
    if (contentWarning != null) result.contentWarning = contentWarning;
    if (sources != null) result.sources.addAll(sources);
    return result;
  }

  Extension._();

  factory Extension.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Extension.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Extension',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'packageName', protoName: 'packageName')
    ..aOM<Resources>(3, _omitFieldNames ? '' : 'resources',
        subBuilder: Resources.create)
    ..aOS(4, _omitFieldNames ? '' : 'extensionLib', protoName: 'extensionLib')
    ..aInt64(5, _omitFieldNames ? '' : 'versionCode', protoName: 'versionCode')
    ..aOS(6, _omitFieldNames ? '' : 'versionName', protoName: 'versionName')
    ..aE<ContentWarning>(7, _omitFieldNames ? '' : 'contentWarning',
        protoName: 'contentWarning', enumValues: ContentWarning.values)
    ..pPM<Source>(8, _omitFieldNames ? '' : 'sources',
        subBuilder: Source.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Extension clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Extension copyWith(void Function(Extension) updates) =>
      super.copyWith((message) => updates(message as Extension)) as Extension;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Extension create() => Extension._();
  @$core.override
  Extension createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Extension getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Extension>(create);
  static Extension? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get packageName => $_getSZ(1);
  @$pb.TagNumber(2)
  set packageName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPackageName() => $_has(1);
  @$pb.TagNumber(2)
  void clearPackageName() => $_clearField(2);

  @$pb.TagNumber(3)
  Resources get resources => $_getN(2);
  @$pb.TagNumber(3)
  set resources(Resources value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasResources() => $_has(2);
  @$pb.TagNumber(3)
  void clearResources() => $_clearField(3);
  @$pb.TagNumber(3)
  Resources ensureResources() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get extensionLib => $_getSZ(3);
  @$pb.TagNumber(4)
  set extensionLib($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExtensionLib() => $_has(3);
  @$pb.TagNumber(4)
  void clearExtensionLib() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get versionCode => $_getI64(4);
  @$pb.TagNumber(5)
  set versionCode($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVersionCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearVersionCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get versionName => $_getSZ(5);
  @$pb.TagNumber(6)
  set versionName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVersionName() => $_has(5);
  @$pb.TagNumber(6)
  void clearVersionName() => $_clearField(6);

  @$pb.TagNumber(7)
  ContentWarning get contentWarning => $_getN(6);
  @$pb.TagNumber(7)
  set contentWarning(ContentWarning value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasContentWarning() => $_has(6);
  @$pb.TagNumber(7)
  void clearContentWarning() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<Source> get sources => $_getList(7);
}

class Resources extends $pb.GeneratedMessage {
  factory Resources({
    $core.String? apkUrl,
    $core.String? iconUrl,
    $core.String? jarUrl,
  }) {
    final result = create();
    if (apkUrl != null) result.apkUrl = apkUrl;
    if (iconUrl != null) result.iconUrl = iconUrl;
    if (jarUrl != null) result.jarUrl = jarUrl;
    return result;
  }

  Resources._();

  factory Resources.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Resources.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Resources',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'apkUrl', protoName: 'apkUrl')
    ..aOS(2, _omitFieldNames ? '' : 'iconUrl', protoName: 'iconUrl')
    ..aOS(501, _omitFieldNames ? '' : 'jarUrl', protoName: 'jarUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Resources clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Resources copyWith(void Function(Resources) updates) =>
      super.copyWith((message) => updates(message as Resources)) as Resources;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Resources create() => Resources._();
  @$core.override
  Resources createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Resources getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Resources>(create);
  static Resources? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get apkUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set apkUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApkUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearApkUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get iconUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set iconUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconUrl() => $_clearField(2);

  @$pb.TagNumber(501)
  $core.String get jarUrl => $_getSZ(2);
  @$pb.TagNumber(501)
  set jarUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(501)
  $core.bool hasJarUrl() => $_has(2);
  @$pb.TagNumber(501)
  void clearJarUrl() => $_clearField(501);
}

class Source extends $pb.GeneratedMessage {
  factory Source({
    $fixnum.Int64? id,
    $core.String? name,
    $core.String? language,
    $core.String? homeUrl,
    $core.Iterable<$core.String>? mirrorUrls,
    $core.String? message,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (language != null) result.language = language;
    if (homeUrl != null) result.homeUrl = homeUrl;
    if (mirrorUrls != null) result.mirrorUrls.addAll(mirrorUrls);
    if (message != null) result.message = message;
    return result;
  }

  Source._();

  factory Source.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Source.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Source',
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'language')
    ..aOS(4, _omitFieldNames ? '' : 'homeUrl', protoName: 'homeUrl')
    ..pPS(5, _omitFieldNames ? '' : 'mirrorUrls', protoName: 'mirrorUrls')
    ..aOS(7, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Source clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Source copyWith(void Function(Source) updates) =>
      super.copyWith((message) => updates(message as Source)) as Source;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Source create() => Source._();
  @$core.override
  Source createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Source getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Source>(create);
  static Source? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get language => $_getSZ(2);
  @$pb.TagNumber(3)
  set language($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLanguage() => $_has(2);
  @$pb.TagNumber(3)
  void clearLanguage() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get homeUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set homeUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHomeUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearHomeUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get mirrorUrls => $_getList(4);

  @$pb.TagNumber(7)
  $core.String get message => $_getSZ(5);
  @$pb.TagNumber(7)
  set message($core.String value) => $_setString(5, value);
  @$pb.TagNumber(7)
  $core.bool hasMessage() => $_has(5);
  @$pb.TagNumber(7)
  void clearMessage() => $_clearField(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
