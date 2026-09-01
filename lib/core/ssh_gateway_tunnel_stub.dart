import '../l10n/runtime_l10n.dart';
import 'settings_store.dart';
import 'ssh_gateway_tunnel.dart';

Future<SshGatewayTunnel> openSshGatewayTunnel(
  ConnectionSettings settings, {
  required ConnectionSecretStore secrets,
}) => Future.error(UnsupportedError(runtimeL10n.sshWebUnsupported));
