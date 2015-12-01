library triton_note.service.aws.dynamodb;

import 'dart:async';
import 'dart:convert';
import 'dart:js';
import 'dart:math';

import 'package:logging/logging.dart';

import 'package:triton_note/service/aws/cognito.dart';
import 'package:triton_note/settings.dart';
import 'package:triton_note/util/pager.dart';

final _logger = new Logger('DynamoDB');

String _stringify(JsObject obj) => context['JSON'].callMethod('stringify', [obj]);

typedef T _RecordReader<T>(Map map);
typedef Map _RecordWriter<T>(T obj);

abstract class DBRecord<T> {
  String get id;

  Map toMap();

  bool isNeedUpdate(T other);
  void update(T other);

  T clone();
}

class DynamoDB {
  static const CONTENT = "CONTENT";
  static const COGNITO_ID = "COGNITO_ID";

  static final client = new JsObject(context["AWS"]["DynamoDB"], []);

  static String createRandomKey() {
    final random = new Random(new DateTime.now().toUtc().millisecondsSinceEpoch);
    final list = new List.generate(32, (i) => random.nextInt(35).toRadixString(36));
    return list.join();
  }
}

class _CognitoIdHook<T extends DBRecord> implements ChangingHook {
  final DynamoDB_Table<T> table;
  List<T> _cache;

  String oldId;

  _CognitoIdHook(this.table);

  Future onStartChanging(String id) async {
    _logger.finest(() => "[DBTable(${table.fullName})] Starting changing cognito id: ${id}");
    if (id != null) {
      oldId = id;
      _cache = await table.query(null, {DynamoDB.COGNITO_ID: id});
      await Future.wait(_cache.map((obj) => table.delete(obj.id)));
    }
  }

  Future _finish(String id) async {
    _logger.finest(() => "[DBTable(${table.fullName})] Finishing changing cognito id: ${id}");
    if (_cache != null) {
      await Future.wait(_cache.map((obj) => table.put(obj, id)));
    }
  }

  Future onFinishChanging(String id) => _finish(id);
  Future onFailedChanging() => _finish(oldId);
}

class DynamoDB_Table<T extends DBRecord> {
  final String tableName;
  final String ID_COLUMN;
  final _RecordReader<T> reader;
  final _RecordWriter<T> writer;
  Future<String> get fullName async => "${(await Settings).appName}.${tableName}";

  DynamoDB_Table(this.tableName, this.ID_COLUMN, this.reader, this.writer) {
    CognitoIdentity.addChaningHook(() => new _CognitoIdHook(this));
  }

  Future<JsObject> _invoke(String methodName, Map param) async {
    param['TableName'] = await fullName;
    _logger.finest(() => "Invoking '${methodName}': ${param}");
    final result = new Completer();
    DynamoDB.client.callMethod(methodName, [
      new JsObject.jsify(param),
      (error, data) {
        if (error != null) {
          _logger.warning("Failed to ${methodName}: ${error}");
          result.completeError(error);
        } else {
          _logger.finest("Result(${methodName}): ${_stringify(data)}");
          result.complete(data);
        }
      }
    ]);
    return result.future;
  }

  Future<Map<String, Map<String, String>>> _makeKey(String id, [String currentCognitoId = null]) async {
    final key = {
      DynamoDB.COGNITO_ID: {'S': currentCognitoId ?? await cognitoId}
    };
    if (id != null && ID_COLUMN != null) key[ID_COLUMN] = {'S': id};
    return key;
  }

  Future<T> get(String id) async {
    final data = await _invoke('getItem', {'Key': await _makeKey(id)});
    final item = data['Item'];
    if (item == null) return null;

    final map = _ContentDecoder.fromDynamoMap(item);
    return reader(map);
  }

  Future<Null> put(T obj, [String currentCognitoId = null]) async {
    final item = _ContentEncoder.toDynamoMap(writer(obj))..addAll(await _makeKey(obj.id, currentCognitoId));
    await _invoke('putItem', {'Item': item});
  }

  Future<Null> update(T obj) async {
    final map = _ContentEncoder.toDynamoMap(writer(obj)..remove(DynamoDB.COGNITO_ID)..remove(ID_COLUMN));
    final attrs = {};
    map.forEach((key, valueMap) {
      attrs[key] = {'Action': 'PUT', 'Value': valueMap};
    });
    await _invoke('updateItem', {'Key': await _makeKey(obj.id), 'AttributeUpdates': attrs});
  }

  Future<Null> delete(String id) async {
    await _invoke('deleteItem', {'Key': await _makeKey(id)});
  }

  Future<List<T>> scan(String expression, Map<String, String> names, Map<String, dynamic> values,
      [int pageSize = 0, LastEvaluatedKey lastEvaluatedKey = null]) async {
    final params = {};
    if (expression != null && expression.isNotEmpty) params['FilterExpression'] = expression;
    if (names != null && names.isNotEmpty) params['ExpressionAttributeNames'] = names;
    if (values != null && values.isNotEmpty) params['ExpressionAttributeValues'] = _ContentEncoder.toDynamoMap(values);
    if (0 < pageSize) params['Limit'] = pageSize;
    if (lastEvaluatedKey != null) lastEvaluatedKey.putToParam(params);

    final data = await _invoke('scan', params);

    if (lastEvaluatedKey != null) lastEvaluatedKey.loadFromResult(data);

    return data['Items'].map(_ContentDecoder.fromDynamoMap).map(reader).toList();
  }

  Pager<T> scanPager(String expression, Map<String, String> names, Map<String, dynamic> values) {
    return new _PagingScan(this, expression, names, values);
  }

  Future<List<T>> query(String indexName, Map<String, Object> keys,
      [bool isForward = true, int pageSize = 0, LastEvaluatedKey lastEvaluatedKey = null]) async {
    int index = 0;
    final expressions = [];
    final names = {};
    final values = {};
    keys.keys.forEach((key) {
      index++;
      final value = keys[key];
      final keyName = "#N${index}";
      final valueName = ":V${index}";
      expressions.add("${keyName} = ${valueName}");
      names[keyName] = key;
      values[valueName] = _ContentEncoder.encode(value);
    });
    final params = {
      'ScanIndexForward': isForward,
      'KeyConditionExpression': expressions.join(" and "),
      'ExpressionAttributeNames': names,
      'ExpressionAttributeValues': values
    };
    if (indexName != null) params['IndexName'] = indexName;
    if (0 < pageSize) params['Limit'] = pageSize;
    if (lastEvaluatedKey != null) lastEvaluatedKey.putToParam(params);

    final data = await _invoke('query', params);

    if (lastEvaluatedKey != null) lastEvaluatedKey.loadFromResult(data);

    return data['Items'].map(_ContentDecoder.fromDynamoMap).map(reader).toList();
  }

  Pager<T> queryPager(String indexName, String hashKeyName, String hashKeyValue, bool forward) {
    return new _PagingQuery(this, indexName, forward, hashKeyName, hashKeyValue);
  }
}

class LastEvaluatedKey {
  Map _value;

  bool get isOver => _value != null && _value.isEmpty;

  void reset() {
    _value = null;
  }

  void loadFromResult(JsObject data) {
    final obj = data['LastEvaluatedKey'];
    _value = (obj == null) ? const {} : JSON.decode(_stringify(obj));
    _logger.finer("LastEvaluatedKey loaded: ${_value}");
  }

  void putToParam(Map params) {
    if (_value != null && _value.isNotEmpty) {
      params['ExclusiveStartKey'] = new Map.unmodifiable(_value);
    }
  }
}

class _PagingQuery<T extends DBRecord> implements Pager<T> {
  final DynamoDB_Table<T> table;
  final String indexName, hashKeyName, hashKeyValue;
  final bool isForward;
  final LastEvaluatedKey _lastEvaluatedKey = new LastEvaluatedKey();

  _PagingQuery(this.table, this.indexName, this.isForward, this.hashKeyName, this.hashKeyValue);

  bool get hasMore => !_lastEvaluatedKey.isOver;

  void reset() => _lastEvaluatedKey.reset();

  Future<List<T>> more(int pageSize) =>
      table.query(indexName, {hashKeyName: hashKeyValue}, isForward, pageSize, _lastEvaluatedKey);
}

class _PagingScan<T extends DBRecord> implements Pager<T> {
  final DynamoDB_Table<T> table;
  final String expression;
  final Map<String, String> names;
  final Map<String, dynamic> values;
  final LastEvaluatedKey _lastEvaluatedKey = new LastEvaluatedKey();

  _PagingScan(this.table, this.expression, this.names, this.values);

  bool get hasMore => !_lastEvaluatedKey.isOver;

  void reset() => _lastEvaluatedKey.reset();

  Future<List<T>> more(int pageSize) => table.scan(expression, names, values, pageSize, _lastEvaluatedKey);
}

class _ContentDecoder {
  static decode(Map<String, Object> valueMap) {
    assert(valueMap.length == 1);
    final t = valueMap.keys.first;
    final value = valueMap[t];
    switch (t) {
      case 'M':
        return fromDynamoMap(value as Map);
      case 'L':
        return (value as List).map((a) => decode(a));
      case 'S':
        return value as String;
      case 'N':
        return num.parse(value.toString());
    }
  }

  static Map fromDynamoMap(dmap) {
    if (dmap is JsObject) return fromDynamoMap(JSON.decode(_stringify(dmap)));

    final result = {};
    dmap.forEach((key, Map valueMap) {
      result[key] = decode(valueMap);
    });
    return result;
  }
}

class _ContentEncoder {
  static encode(value) {
    if (value is Map) return {'M': toDynamoMap(value)};
    if (value is List) return {'L': value.map((a) => encode(a))};
    if (value is String) return {'S': value};
    if (value is num) return {'N': value.toString()};
  }

  static Map toDynamoMap(Map map) {
    final result = {};
    map.forEach((key, value) {
      result[key] = encode(value);
    });
    return result;
  }
}
