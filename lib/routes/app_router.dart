import 'package:shelf_router/shelf_router.dart';
import '../controller/controllers.dart';

class AppRouter {
  static Router router = Router()
    ..get('/', rootHandler)
    ..get('/echo/<message>', echoHandler);
}
