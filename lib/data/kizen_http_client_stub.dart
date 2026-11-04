import 'package:http/http.dart' as http;

/// Stub untuk web/smoke-test preview (browser fetch menangani jaringan).
http.Client createKizenHttpClient() => http.Client();
