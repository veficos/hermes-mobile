import 'settings_store.dart';
import 'ssh_gateway_tunnel_stub.dart'
    if (dart.library.io) 'ssh_gateway_tunnel_io.dart'
    as platform;

abstract class SshGatewayTunnel {
  String get baseUrl;
  String get apiKey;

  Future<void> close();
}

Future<SshGatewayTunnel> openSshGatewayTunnel(
  ConnectionSettings settings, {
  required ConnectionSecretStore secrets,
}) => platform.openSshGatewayTunnel(settings, secrets: secrets);
