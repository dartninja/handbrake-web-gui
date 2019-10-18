import 'dart:async';

import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:logging/logging.dart';
import '../data/job_settings.dart';
import '../rpc_service.dart';

@Component(
  selector: 'job-settings',
  //styleUrls: ['todo_list_component.css'],
  templateUrl: 'job_settings_component.html',
  directives: [
    MaterialDropdownSelectComponent,
    NgFor,
    NgIf,
  ],
  providers: [overlayBindings, popupBindings, const ClassProvider(RpcService)],
)
class JobSettingsComponent implements OnInit {
  final Logger log = new Logger('JobSettingsComponent');

  final RpcService _rpcService;

  JobSettings settings;

  JobSettingsComponent(this._rpcService);

  SelectionOptions<String> encoders = new StringSelectionOptions([]);

  SelectionModel<String> encoderSelection = new SingleSelectionModel();

  String get encoder {
    if (encoderSelection.isEmpty)
      return "Encoder";
    else
      return encoderSelection.selectedValues.first;
  }

  @override
  Future<void> ngOnInit() async {
    log.finest("ngOnInit");
    await refresh();
  }

  Future<void> refresh() async {
    log.finest("refresh");

    Map enums = await _rpcService.getEnums();
    List<String> encoders = new List<String>.from(enums["encoders"]);
    this.encoders = new StringSelectionOptions(encoders);
  }
}
