import 'src/backend_config_io.dart'
    if (dart.library.html) 'src/backend_config_web.dart';

String get backendUrl => backendUrlImpl();
