import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

void logToConsole (LogRecord rec) {
print('${rec.level.name}: ${rec.time}: ${rec.message}');
if(rec.error!=null) {
print(rec.error.toString());
}
if(rec.stackTrace!=null) {
print(Trace.format(rec.stackTrace));
}
}