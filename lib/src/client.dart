import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'auth.dart';
import 'error.dart';
import 'file.dart';
import 'requests.dart';
import 'utils.dart';
import 'xml.dart';

class Client {
  final String uri;
  Auth auth;
  Map<String, Object> headers;
  HttpClient c;

  Client({
    @required this.uri,
    this.auth,
    this.headers,
    this.c,
  });

  // methods--------------------------------

  //
  void setHeader(String key, String value) => this.headers[key] = value;

  //
  void setTimeout(Duration timeout) => this.c.connectionTimeout = timeout;

  //
  Future<void> ping([CancelToken cancelToken]) async {
    var resp = await c.options(this, '/');
    if (resp.statusCode != 200) {
      throw WebdavError(error: '${resp.reasonPhrase}(${resp.statusCode})');
    }
  }

  //
  Future<List<File>> readDir(String path, [CancelToken cancelToken]) async {
    path = fixSlashes(path);
    var resp = await this
        .c
        .propfind(this, path, true, fileXmlStr, cancelToken: cancelToken);
    String str = await resp.transform(utf8.decoder).join();
    return WebdavXml.toFiles(path, str);
  }

  //
  Future<void> mkdir(String path, [CancelToken cancelToken]) async {
    path = fixSlashes(path);
    var resp = await this.c.mkcol(this, path, cancelToken: cancelToken);
    var status = resp.statusCode;
    if (status != 201 && status != 405) {
      throw WebdavError(error: '${resp.reasonPhrase}(${resp.statusCode})');
    }
  }

  //
  Future<void> mkdirAll(String path, [CancelToken cancelToken]) async {
    path = fixSlashes(path);
    var resp = await this.c.mkcol(this, path, cancelToken: cancelToken);
    var status = resp.statusCode;
    if (status == 201 || status == 405) {
      return;
    } else if (status == 409) {
      var paths = path.split('/');
      var sub = '/';
      for (var e in paths) {
        if (e == '') {
          continue;
        }
        sub += e + '/';
        resp = await this.c.mkcol(this, sub, cancelToken: cancelToken);
        status = resp.statusCode;
        if (status != 201 && status != 405) {
          throw WebdavError(error: '${resp.reasonPhrase}(${resp.statusCode})');
        }
      }
      return;
    }
    throw WebdavError(error: '${resp.reasonPhrase}(${resp.statusCode})');
  }

  //
  Future<void> remove(String path, [CancelToken cancelToken]) {
    return removeAll(path, cancelToken);
  }

//
  Future<void> removeAll(String path, [CancelToken cancelToken]) async {
    var resp = await this.c.delete2(this, path, cancelToken: cancelToken);
    if (resp.statusCode == 200 ||
        resp.statusCode == 204 ||
        resp.statusCode == 404) {
      return;
    }
    throw WebdavError(error: '${resp.reasonPhrase}(${resp.statusCode})');
  }
}

// create new client
Client newClient(String uri, {String user = '', String password = ''}) {
  return Client(
    uri: fixSlash(uri),
    auth: Auth(user: user, pwd: password),
    headers: {},
    c: HttpClient(),
  );
}

class CancelToken {}