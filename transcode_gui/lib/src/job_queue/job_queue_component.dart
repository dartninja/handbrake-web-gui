import 'dart:async';

import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:logging/logging.dart';
import '../data/job_queue_entry.dart';
import '../rpc_service.dart';
import '../job_settings/job_settings_component.dart';

@Component(
  selector: 'job-queue',
  //styleUrls: ['todo_list_component.css'],
  templateUrl: 'job_queue_component.html',
  directives: [
    MaterialCheckboxComponent,
    MaterialFabComponent,
    MaterialIconComponent,
    materialInputDirectives,
    MaterialListComponent,
    MaterialButtonComponent,
    MaterialProgressComponent,
    MaterialExpansionPanel,
    MaterialSpinnerComponent,
    MaterialExpansionPanelSet,
    MaterialDialogComponent,
    JobSettingsComponent,
    ModalComponent,
    NgFor,
    NgIf,
  ],
  providers: [overlayBindings, const ClassProvider(RpcService)],
)
class JobQueueComponent implements OnInit {
  final Logger log = new Logger('JobQueueComponent');

  final RpcService _jobQueueService;

  bool showDialog = false;

  List<JobQueueEntry> items = [];
  String newTodo = '';

  Map<String,bool> expanded = <String,bool>{};

  JobQueueEntry selectedJob;

  JobQueueComponent (this._jobQueueService);



  @override
  Future<void> ngOnInit() async {
    log.finest("ngOnInit");

    await refresh();
    var timer = new Timer.periodic(new Duration(seconds: 5), (t) => refresh(), );
  }

  Future<void> refresh() async {
    log.finest("refresh");

    items = await _jobQueueService.getJobQueue();
  }

  Future<void> info(String id) async {
    log.finest("info($id)");
    selectedJob = items.firstWhere((JobQueueEntry e) => e.id==id);
    showDialog = true;
  }

  Future<void> edit(String id) async {

  }


}
