import 'dart:io';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:twake/models/authentication/authentication.dart';
import 'package:twake/models/globals/globals.dart';
import 'package:twake/services/service_bundle.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:twake/utils/api_data_transformer.dart';

class AuthenticationRepository {
  final _api = ApiService.instance;
  final _storage = StorageService.instance;
  final _appAuth = FlutterAppAuth();
  bool _validatorRunning = false;

  AuthenticationRepository();

  Future<bool> isAuthenticated() async {
    final result = await _storage.first(table: Table.authentication);
    if (result.isEmpty) return false;
    var authentication = Authentication.fromJson(result);

    switch (hasExpired(authentication)) {
      case Expiration.Valid:
        Globals.instance.tokenSet = authentication.token;
        break;
      case Expiration.Both:
        logout();
        return false;
      case Expiration.Primary:
        if (!Globals.instance.isNetworkConnected) {
          Globals.instance.tokenSet = authentication.token;
          return true;
        }
        authentication = await prolongAuthentication(authentication);
    }
    return true;
  }

  Future<bool> authenticate({
    required String username,
    required String password,
  }) async {
    dynamic authenticationResult = {};
    try {
      authenticationResult = await _api.post(
        endpoint: Endpoint.authorize,
        data: {
          'username': username.trim(),
          'password': password.trim(),
          'device': Platform.isAndroid ? 'android' : 'apple',
          'timezoneoffset': tzo,
          'fcm_token': Globals.instance.fcmToken,
        },
      );
    } catch (e) {
      Logger().e('Error occured during authentication:\n$e');
      return false;
    }

    final authentication = Authentication.fromJson(authenticationResult);

    _storage.cleanInsert(table: Table.authentication, data: authentication);
    Globals.instance.tokenSet = authentication.token;

    return true;
  }

  Future<bool> webviewAuthenticate() async {
    final AuthorizationTokenResponse? tokenResponse =
        await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        Globals.instance.clientId!,
        'twakemobile.com://oauthredirect',
        discoveryUrl:
            '${Globals.instance.oidcAuthority}/.well-known/openid-configuration',
        scopes: ['openid', 'profile', 'email'],
        preferEphemeralSession: true,
      ),
    );
    if (tokenResponse == null) {
      return false;
    }
    final authenticationResult = await _api.post(
      endpoint: Endpoint.login,
      data: {'remote_access_token': tokenResponse.accessToken},
    );
    // register device
    _api.post(endpoint: Endpoint.device, data: {
      'resource': {
        'type': 'FCM',
        'value': Globals.instance.fcmToken,
        'version': Globals.version,
      }
    });

    final authentication = Authentication.fromJson(ApiDataTransformer.token(
      payload: authenticationResult,
      tokenResponse: tokenResponse,
    ));

    _storage.cleanInsert(table: Table.authentication, data: authentication);
    Globals.instance.tokenSet = authentication.token;

    return true;
  }

  Future<Authentication> prolongAuthentication(
    Authentication authentication,
  ) async {
    Map<String, dynamic> authenticationResult = {};

    Globals.instance.tokenSet = authentication.refreshToken;

    try {
      authenticationResult = await _api.post(
        endpoint: Endpoint.authorizationProlong,
        data: const {},
      );
    } catch (e, ss) {
      final message = 'Error while prolonging token with valid refresh:\n$e';
      Logger().wtf(message);
      Sentry.captureException(Exception(message), stackTrace: ss);
      throw e;
    }

    final freshAuthentication = Authentication.complementWithConsole(
      json: ApiDataTransformer.token(payload: authenticationResult),
      other: authentication,
    );

    _storage.cleanInsert(
      table: Table.authentication,
      data: freshAuthentication,
    );

    Globals.instance.tokenSet = freshAuthentication.token;

    return freshAuthentication;
  }

  Future<void> logout() async {
    if (Globals.instance.isNetworkConnected) {
      _api.post(endpoint: Endpoint.logout, data: {
        'fcm_token': Globals.instance.fcmToken,
      });
    }

    // final result = await _storage.first(table: Table.authentication);
    // final authentication = Authentication.fromJson(result);

    // await _appAuth.endSession(
    // EndSessionRequest(
    // postLogoutRedirectUrl: 'twakemobile.com://signout',
    // idTokenHint: authentication.idToken,
    // discoveryUrl:
    // '${Globals.instance.oidcAuthority}/.well-known/openid-configuration',
    // ),
    // );
    Logger().w('session ended');
//
    Globals.instance.reset();

    await _storage.truncateAll();
  }

  Expiration hasExpired(Authentication authentication) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expired = authentication.expiration < now;
    final refreshExpired = authentication.refreshExpiration < now;

    if (refreshExpired) return Expiration.Both;
    if (expired) return Expiration.Primary;
    return Expiration.Valid;
  }

  void startTokenValidator() async {
    if (_validatorRunning) return;

    _tokenValidityCheck();
  }

  Future<void> _tokenValidityCheck() async {
    if (!Globals.instance.isNetworkConnected) {
      _validatorRunning = false;
      return;
    }
    final result = await _storage.first(table: Table.authentication);
    if (result.isEmpty) {
      _validatorRunning = false;
      return;
    }

    var authentication = Authentication.fromJson(result);

    Logger().v(
      'Token validity check, expires at: '
      '${DateTime.fromMillisecondsSinceEpoch(authentication.expiration * 1000)}',
    );

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final needToProlong = authentication.expiration - now <
        59 * 60; // less than 10 minutes to expiration
    if (needToProlong) {
      authentication = await prolongAuthentication(authentication);
    }
    Future.delayed(Duration(seconds: 120), () => _tokenValidityCheck());
  }

  int get tzo => -DateTime.now().timeZoneOffset.inMinutes;
}

enum Expiration {
  Valid,
  Primary,
  Both,
}
