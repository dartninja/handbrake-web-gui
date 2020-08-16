import 'dart:async';
import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'src/job_queue/job_queue_component.dart';
import 'src/rpc_service.dart';
import 'package:angular_components/angular_components.dart';

// AngularDart info: https://webdev.dartlang.org/angular
// Components info: https://webdev.dartlang.org/components

@Component(
  selector: 'my-server',
  styleUrls: [
    'app_component.css',
    'package:angular_components/app_layout/layout.scss.css'
  ],
  templateUrl: 'app_component.html',
  directives: [
    JobQueueComponent,
    MaterialButtonComponent,
    MaterialIconComponent
  ],
  providers: [const ClassProvider(RpcService)],
)
class AppComponent {
  final Logger log = new Logger('JobQueueComponent');

  final RpcService _rpcService;

  @ViewChild('job_queue')
  JobQueueComponent jobQueue;

  MaterialRadioComponent radioComponent;

  AppComponent(this._rpcService);

  Future<void> clear() async {
    await _rpcService.clearComplete();
    await refresh();
  }

  Future<void> refresh() async {
    jobQueue.refresh();
  }
}
