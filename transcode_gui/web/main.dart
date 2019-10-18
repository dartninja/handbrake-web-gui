import 'package:angular/angular.dart';
import 'package:transcode_gui/app_component.template.dart' as ng;
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL;

  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  runApp(ng.AppComponentNgFactory);
}
