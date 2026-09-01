import 'settings_store.dart';
import 'ssh_gateway_tunnel.dart';

Future<SshGatewayTunnel> openSshGatewayTunnel(
  ConnectionSettings settings, {
  required ConnectionSecretStore secrets,
}) => Future.error(
  UnsupportedError('Native SSH connections are not supported on web'),
);
