import 'package:multicast_dns/multicast_dns.dart';

class MdnsDiscovery {
  static const String _serviceType = '_taskapp._tcp.local';
  String? _cachedServerIp;

  Future<String> findServer() async {
    if (_cachedServerIp != null) return _cachedServerIp!;

    final MDnsClient client = MDnsClient();
    try {
      await client.start();

      // Get the stream of PTR records
      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_serviceType))) {
        
        // Resolve the SRV record to get host details
        final srv = await client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        ).first;

        // Get the IP address
        final ip = await client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        ).first;

        _cachedServerIp = ip.address.address;
        return _cachedServerIp!;
      }
      
      throw Exception('No TaskApp server found');
    } finally {
      client.stop();
    }
  }

  void retryDiscovery() {
    _cachedServerIp = null;
  }
}