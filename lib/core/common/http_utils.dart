// OCSInventory Agent
// Copyright (C) OCSInventory
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

// External packages imports
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:ocsinventory_agent/core/config.dart';
import 'package:sprintf/sprintf.dart';

// Core imports
import 'package:ocsinventory_agent/core/log.dart';

/// This class will execute and log the status of the query
class HTTPUtils {
  late Logger logger;
  late IOClient ioClient;
  late Config config;
  bool _certificateFileLogPrinted = false;

  /// Constructor
  HTTPUtils(Logger logger, Config config) {
    this.logger = logger;
    this.config = config;
    this.ioClient = createHttpsClient();
    _logCertificateMode();
  }

  void _logCertificateMode() {
    String url = (config.getInventoryConfig("url") ?? "").toString();
    bool isHttps = Uri.tryParse(url)?.scheme.toLowerCase() == "https";
    bool ssl =
        config.getInventoryConfig("ssl").toString().toLowerCase() == "true";
    String certificatePath =
        (config.getInventoryConfig("certificate") ?? "").toString().trim();
    bool certificateFileExists =
        certificatePath.isNotEmpty && File(certificatePath).existsSync();

    if (!isHttps) {
      logger.info(this.runtimeType.toString(),
          "Certificate mode: TLS disabled (HTTP).");
      return;
    }

    if (ssl) {
      logger.warning(this.runtimeType.toString(),
          "Certificate mode: TLS enabled with validation bypass (ssl=true, insecure).");
      return;
    }

    if (certificateFileExists) {
      logger.info(this.runtimeType.toString(),
          "Certificate mode: TLS enabled (system store), fallback certificate path available: $certificatePath");
      return;
    }

    logger.info(this.runtimeType.toString(),
        "Certificate mode: TLS enabled (system store), no fallback certificate path available.");
  }

  /// Return header in json format.
  Map<String, String> getHeader() {
    // Get data from inventory.json file
    String token = Config.token;

    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.authorizationHeader: "Token $token"
    };
  }

  /// Create https client
  IOClient createHttpsClient({bool useCertificateFile = false}) {
    bool ssl =
        config.getInventoryConfig("ssl").toString().toLowerCase() == "true";
    String certificatePath =
        (config.getInventoryConfig("certificate") ?? "").toString().trim();
    String url = (config.getInventoryConfig("url") ?? "").toString();
    bool isHttps = Uri.tryParse(url)?.scheme.toLowerCase() == "https";

    try {
      if (!isHttps) {
        logger.debug(this.runtimeType.toString(),
            "Agent URL is HTTP: SSL/TLS verification disabled (no SSL).");
        return IOClient(HttpClient());
      }

      if (ssl) {
        HttpClient client = HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
        return IOClient(client);
      }

      if (useCertificateFile) {
        if (certificatePath.isNotEmpty && File(certificatePath).existsSync()) {
          SecurityContext context = SecurityContext(withTrustedRoots: true);
          context.setTrustedCertificates(certificatePath);
          if (!_certificateFileLogPrinted) {
            logger.info(this.runtimeType.toString(),
                sprintf("Using certificate file: %s", [certificatePath]));
            _certificateFileLogPrinted = true;
          }
          return IOClient(HttpClient(context: context));
        }
      }

      return IOClient(HttpClient());
    } catch (exception) {
      logger.error(this.runtimeType.toString(),
          sprintf("HTTP query: %s", [exception.toString().trim()]));
      return IOClient(HttpClient());
    }
  }

  bool _shouldTryCertificateFallback(Uri uri) {
    String certPath = (config.getInventoryConfig("certificate") ?? "")
        .toString()
        .trim();
    bool ssl =
        config.getInventoryConfig("ssl").toString().toLowerCase() == "true";
    return uri.scheme.toLowerCase() == "https" &&
        !ssl &&
        certPath.isNotEmpty &&
        File(certPath).existsSync();
  }

  Future<dynamic> _sendWithTlsHandling(
      Uri uri, Future<dynamic> Function(IOClient) send) async {
    try {
      return await send(ioClient);
    } on HandshakeException catch (primaryError) {
      if (_shouldTryCertificateFallback(uri)) {
        final fallback = createHttpsClient(useCertificateFile: true);
        try {
          return await send(fallback);
        } on HandshakeException catch (fallbackError) {
          logger.error(
              this.runtimeType.toString(),
              "TLS validation failed with both system store and certificate file. "
              "Scanned certificate paths: [${config.getInventoryConfig("certificate")}]. "
              "Primary error: ${primaryError.toString().trim()} | "
              "Fallback error: ${fallbackError.toString().trim()}");
          rethrow;
        } finally {
          fallback.close();
        }
      }
      logger.error(
          this.runtimeType.toString(),
          "TLS validation failed using system store. "
          "Scanned certificate paths: [${config.getInventoryConfig("certificate")}]. "
          "Error: ${primaryError.toString().trim()}");
      rethrow;

    } catch (exception) {
      logger.error(
          this.runtimeType.toString(),
          sprintf("HTTP query: %s", [exception.toString().trim()]));
      rethrow;
    }
  }

  /// Return the statusCode message
  String? statusCodeMessage(String type, int statusCode, String detail) {
    var statusMessage = new Map<int, String>();
    statusMessage[200] = sprintf("[%s] [200] %s", [type, detail]);
    statusMessage[201] = sprintf("[%s] [201] %s", [type, detail]);
    statusMessage[400] = sprintf("[%s] [400] %s", [type, detail]);
    statusMessage[401] = sprintf("[%s] [401] %s", [type, detail]);
    statusMessage[403] = sprintf("[%s] [403] %s", [type, detail]);
    statusMessage[404] = sprintf("[%s] [404] %s", [type, detail]);
    statusMessage[500] = sprintf("[%s] [500] %s", [type, detail]);
    return statusMessage[statusCode];
  }

  /// Do a delete HTTP query
  Future<Map<String, dynamic>> delete(
      Uri uri, Map<String, String>? headers) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query =
          await _sendWithTlsHandling(uri, (client) => client.delete(uri, headers: headers));
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] =
          statusCodeMessage("DELETE", query.statusCode, query.body);
    } catch (exception) {
      logger.error(this.runtimeType.toString(),
          sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a get HTTP query
  Future<Map<String, dynamic>> get(Uri url, Map<String, String> headers) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query =
          await _sendWithTlsHandling(url, (client) => client.get(url, headers: headers));
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] = "[GET] [${query.statusCode}] ${query.body}";
      returnObject["body"] = query.body;
      returnObject["headers"] = query.headers;
    } catch (exception) {
      logger.error(this.runtimeType.toString(),
          sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a patch HTTP query
  Future<Map<String, dynamic>> patch(
      Uri uri, Map<String, String>? headers, Object? body) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query = await _sendWithTlsHandling(
          uri, (client) => client.patch(uri, headers: headers, body: body));
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] =
          statusCodeMessage("PATCH", query.statusCode, query.body);
    } catch (exception) {
      logger.error(this.runtimeType.toString(),
          sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a post HTTP query
  Future<Map<String, dynamic>> post(
      Uri uri, Map<String, String>? headers, Object? body) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query = await _sendWithTlsHandling(
          uri, (client) => client.post(uri, headers: headers, body: body));
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] =
          statusCodeMessage("POST", query.statusCode, query.body);
    } catch (exception) {
      logger.error(this.runtimeType.toString(),
          sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a put HTTP query
  Future<Map<String, dynamic>> put(
      Uri uri, Map<String, String>? headers, Object? body) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query =
          await _sendWithTlsHandling(uri, (client) => client.put(uri, headers: headers, body: body));
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] =
          statusCodeMessage("PUT", query.statusCode, query.body);
    } catch (exception) {
      logger.error(this.runtimeType.toString(),
          sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }
}
