// Generated protocol buffer code for KV service

import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;

class GetRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'GetRequest',
      package: const $pb.PackageName(
          const $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'proto'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'key')
    ..hasRequiredFields = false;

  GetRequest._() : super();
  factory GetRequest({$core.String? key}) {
    final result = create();
    if (key != null) result.key = key;
    return result;
  }

  factory GetRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory GetRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  @$core.Deprecated('Using this can add significant overhead to your binary.')
  static GetRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetRequest>(create);
  static GetRequest? _defaultInstance;

  static GetRequest create() => GetRequest._();
  GetRequest clone() => GetRequest()..mergeFromMessage(this);

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRequest createEmptyInstance() => create();

  @$core.override
  GetRequest createEmptyInstance() => create();

  @$core.pragma('dart2js:noInline')
  static $pb.PbList<GetRequest> createRepeated() => $pb.PbList<GetRequest>();

  @$core.pragma('dart2js:noInline')
  GetRequest copyWith(void Function(GetRequest) updates) =>
      super.copyWith((message) => updates(message as GetRequest)) as GetRequest;

  $core.String get key => $_getSZ(0);
  set key($core.String v) {
    $_setString(0, v);
  }

  $core.bool hasKey() => $_has(0);
  void clearKey() => clearField(1);
}

class GetResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'GetResponse',
      package: const $pb.PackageName(
          const $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'proto'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'value',
        $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  GetResponse._() : super();
  factory GetResponse({$core.List<$core.int>? value}) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  factory GetResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static GetResponse? _defaultInstance;
  static GetResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetResponse>(create);

  static GetResponse create() => GetResponse._();
  GetResponse clone() => GetResponse()..mergeFromMessage(this);

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  static GetResponse createEmptyInstance() => create();

  @$core.override
  GetResponse createEmptyInstance() => create();

  $core.List<$core.int> get value => $_getN(0);
  set value($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  $core.bool hasValue() => $_has(0);
  void clearValue() => clearField(1);
}

class PutRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'PutRequest',
      package: const $pb.PackageName(
          const $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'proto'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'key')
    ..a<$core.List<$core.int>>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'value',
        $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  PutRequest._() : super();
  factory PutRequest({$core.String? key, $core.List<$core.int>? value}) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  factory PutRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static PutRequest? _defaultInstance;
  static PutRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PutRequest>(create);

  static PutRequest create() => PutRequest._();
  PutRequest clone() => PutRequest()..mergeFromMessage(this);

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  static PutRequest createEmptyInstance() => create();

  @$core.override
  PutRequest createEmptyInstance() => create();

  $core.String get key => $_getSZ(0);
  set key($core.String v) {
    $_setString(0, v);
  }

  $core.bool hasKey() => $_has(0);
  void clearKey() => clearField(1);

  $core.List<$core.int> get value => $_getN(1);
  set value($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  $core.bool hasValue() => $_has(1);
  void clearValue() => clearField(2);
}

class Empty extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'Empty',
      package: const $pb.PackageName(
          const $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'proto'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  Empty._() : super();
  factory Empty() => create();

  factory Empty.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static Empty? _defaultInstance;
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);

  static Empty create() => Empty._();
  Empty clone() => Empty()..mergeFromMessage(this);

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  static Empty createEmptyInstance() => create();

  @$core.override
  Empty createEmptyInstance() => create();
}
