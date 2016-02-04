library triton_note.page.report_detail;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_header_panel.dart';
import 'package:core_elements/core_dropdown.dart';
import 'package:paper_elements/paper_icon_button.dart';
import 'package:paper_elements/paper_autogrow_textarea.dart';
import 'package:paper_elements/paper_toast.dart';

import 'package:triton_note/element/expandable_gmap.dart';
import 'package:triton_note/dialog/confirm.dart';
import 'package:triton_note/dialog/edit_fish.dart';
import 'package:triton_note/dialog/edit_timestamp.dart';
import 'package:triton_note/dialog/edit_tide.dart';
import 'package:triton_note/dialog/edit_weather.dart';
import 'package:triton_note/model/report.dart';
import 'package:triton_note/model/location.dart' as Loc;
import 'package:triton_note/model/value_unit.dart';
import 'package:triton_note/service/preferences.dart';
import 'package:triton_note/service/reports.dart';
import 'package:triton_note/service/facebook.dart';
import 'package:triton_note/service/natural_conditions.dart';
import 'package:triton_note/service/googlemaps_browser.dart';
import 'package:triton_note/util/blinker.dart';
import 'package:triton_note/util/enums.dart';
import 'package:triton_note/util/fabric.dart';
import 'package:triton_note/util/getter_setter.dart';
import 'package:triton_note/util/main_frame.dart';

final Logger _logger = new Logger('ReportDetailPage');

const String editFlip = "create";
const String editFlop = "done";

const Duration blinkDuration = const Duration(seconds: 2);
const Duration blinkDownDuration = const Duration(milliseconds: 300);
const frameBackground = const [
  const {'background': "#fffcfc"},
  const {'background': "#fee"}
];
const frameBackgroundDown = const [
  const {'background': "#fee"},
  const {'background': "white"}
];

const submitDuration = const Duration(minutes: 1);

typedef void OnChanged(newValue);

@Component(
    selector: 'report-detail',
    templateUrl: 'packages/triton_note/page/report_detail.html',
    cssUrl: 'packages/triton_note/page/report_detail.css',
    useShadowDom: true)
class ReportDetailPage extends SubPage {
  final Future<Report> _report;

  ReportDetailPage(RouteProvider rp) : this._report = Reports.get(rp.parameters['reportId']);

  Report report;
  _Comment comment;
  _Catches catches;
  _PhotoSize photo;
  _Location location;
  _Conditions conditions;
  _MoreMenu moreMenu;
  List<_PartOfPage> _parts;

  Getter<EditTimestampDialog> editTimestamp = new PipeValue();
  Timer _submitTimer;
  Getter<Element> toolbar;

  @override
  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);
    FabricAnswers.eventContentView(contentName: "ReportDetailPage");

    toolbar = new CachedValue(() => root.querySelector('core-header-panel[main] core-toolbar'));

    _report.then((v) async {
      report = v;
      photo = new _PhotoSize(root);
      comment = new _Comment(root, _onChanged, report);
      catches = new _Catches(root, _onChanged, new Getter(() => report.fishes));
      conditions = new _Conditions(report.condition, _onChanged);
      location = new _Location(root, report.location, _onChanged);
      moreMenu = new _MoreMenu(root, report, _onChanged, back);

      _parts = [photo, comment, catches, conditions, location, moreMenu];
    });
  }

  void detach() {
    super.detach();
    _parts.forEach((p) => p.detach());

    if (_submitTimer != null && _submitTimer.isActive) {
      _submitTimer.cancel();
      _update();
    }
  }

  DateTime get timestamp => report == null ? null : report.dateAt;
  set timestamp(DateTime v) {
    if (report != null && v != null && v != report.dateAt) {
      report.dateAt = v;
      conditions._update(v);
      _onChanged(v);
    }
  }

  void _onChanged(newValue) {
    _logger.finest("Changed value(${newValue}), Start timer to submit.");
    if (_submitTimer != null && _submitTimer.isActive) _submitTimer.cancel();
    _submitTimer = new Timer(submitDuration, _update);
  }

  void _update() {
    Reports.update(report).then((_) {
      FabricAnswers.eventCustom(name: 'ModifyReport');
    }).catchError((ex) {
      _logger.warning(() => "Failed to update report: ${ex}");
    });
  }
}

abstract class _PartOfPage {
  void detach();
}

class _MoreMenu extends _PartOfPage {
  final ShadowRoot _root;
  final Report _report;
  final OnChanged _onChanged;
  bool published = false;
  final _back;

  Getter<ConfirmDialog> confirmDialog = new PipeValue();
  final PipeValue<bool> dialogResult = new PipeValue();

  _MoreMenu(this._root, this._report, this._onChanged, void back()) : this._back = back {
    setPublished(_report?.published?.facebook);
  }

  setPublished(String id) async {
    if (id == null) {
      published = false;
    } else {
      try {
        final obj = await FBPublish.getAction(id);
        if (obj != null) {
          published = true;
        } else {
          published = false;
          _onChanged(_report.published.facebook = null);
        }
      } catch (ex) {
        _logger.warning(() => "Error on getting published action: ${ex}");
        published = false;
      }
    }
  }

  CoreDropdown get dropdown => _root.querySelector('#more-menu core-dropdown');

  void detach() {}

  confirm(String message, whenOk()) {
    dropdown.close();
    confirmDialog.value
      ..message = message
      ..onClossing(() {
        if (confirmDialog.value.result) whenOk();
      })
      ..open();
  }

  toast(String msg, [Duration dur = const Duration(seconds: 8)]) =>
      _root.querySelector('#more-menu paper-toast') as PaperToast
        ..classes.remove('fit-bottom')
        ..duration = dur.inMilliseconds
        ..text = msg
        ..show();

  publish() {
    final msg =
        published ? "This report is already published. Are you sure to publish again ?" : "Publish to Facebook ?";
    confirm(msg, () async {
      try {
        final published = await FBPublish.publish(_report);
        _onChanged(published);
        toast("Completed on publishing to Facebook");
      } catch (ex) {
        _logger.warning(() => "Error on publishing to Facebook: ${ex}");
        toast("Failed on publishing to Facebook");
      }
    });
  }

  delete() => confirm("Delete this report ?", () async {
        await Reports.remove(_report.id);
        _back();
      });
}

class _Comment extends _PartOfPage {
  final ShadowRoot _root;
  final OnChanged _onChanged;
  final Report _report;

  CachedValue<List<Element>> _area;
  Blinker _blinker;

  bool isEditing = false;

  _Comment(this._root, this._onChanged, this._report) {
    _area = new CachedValue(() => _root.querySelectorAll('#comment .editor').toList(growable: false));
    _blinker = new Blinker(blinkDuration, blinkDownDuration, [new BlinkTarget(_area, frameBackground)]);
  }

  bool get isEmpty => _report.comment == null || _report.comment.isEmpty;

  String get text => _report.comment;
  set text(String v) {
    if (v == null || _report.comment == v) return;
    _report.comment = v;
    _onChanged(v);
  }

  void detach() {
    _blinker.stop();
  }

  toggle(event) {
    final button = event.target as PaperIconButton;
    _logger.fine("Toggle edit: ${button.icon}");
    button.icon = isEditing ? editFlip : editFlop;

    if (isEditing) {
      _blinker.stop();
      new Future.delayed(_blinker.blinkStopDuration, () {
        isEditing = false;
      });
    } else {
      _logger.finest("Start editing comment.");
      isEditing = true;
      new Future.delayed(new Duration(milliseconds: 10), () {
        final a = _root.querySelector('#comment .editor  paper-autogrow-textarea') as PaperAutogrowTextarea;
        a.update(a.querySelector('textarea'));

        _area.clear();
        _blinker.start();
      });
    }
  }
}

class _Catches extends _PartOfPage {
  static const frameButton = const [
    const {'opacity': 0.05},
    const {'opacity': 1}
  ];

  final ShadowRoot _root;
  final OnChanged _onChanged;
  final Getter<List<Fishes>> list;
  final GetterSetter<EditFishDialog> dialog = new PipeValue();

  CachedValue<List<Element>> _addButton;
  CachedValue<List<Element>> _fishItems;
  Blinker _blinker;

  bool isEditing = false;

  _Catches(this._root, this._onChanged, this.list) {
    _addButton = new CachedValue(() => _root.querySelectorAll('#fishes paper-icon-button.add').toList(growable: false));
    _fishItems = new CachedValue(() => _root.querySelectorAll('#fishes .content').toList(growable: false));

    _blinker = new Blinker(blinkDuration, blinkDownDuration,
        [new BlinkTarget(_addButton, frameButton), new BlinkTarget(_fishItems, frameBackground, frameBackgroundDown)]);
  }

  void detach() {
    _blinker.stop();
  }

  toggle(event) {
    final button = event.target as PaperIconButton;
    _logger.fine("Toggle edit: ${button.icon}");
    button.icon = isEditing ? editFlip : editFlop;

    if (isEditing) {
      _blinker.stop();
      new Future.delayed(_blinker.blinkStopDuration, () {
        isEditing = false;
      });
    } else {
      isEditing = true;
      new Future.delayed(new Duration(milliseconds: 10), () {
        _addButton.clear();
        _fishItems.clear();
        _blinker.start();
      });
    }
  }

  add() => afterRippling(() {
        _logger.fine("Add new fish");
        final fish = new Fishes.fromMap({'count': 1});
        dialog.value.openWith(new GetterSetter(() => fish, (v) {
          list.value.add(v);
          _onChanged(list.value);
        }));
      });

  edit(index) => afterRippling(() {
        _logger.fine("Edit at $index");
        dialog.value.openWith(new GetterSetter(() => list.value[index], (v) {
          if (v == null) {
            list.value.removeAt(index);
          } else {
            list.value[index] = v;
          }
          _onChanged(list.value);
        }));
      });
}

class _Location extends _PartOfPage {
  static const frameBorder = const [
    const {'border': "solid 2px #fee"},
    const {'border': "solid 2px #f88"}
  ];
  static const frameBorderStop = const [
    const {'border': "solid 2px #f88"},
    const {'border': "solid 2px white"}
  ];

  final ShadowRoot _root;
  final Loc.Location _location;
  final OnChanged _onChanged;
  Getter<Element> getScroller;
  Getter<Element> getBase;
  final FuturedValue<ExpandableGMapElement> gmapElement = new FuturedValue();
  final FuturedValue<GoogleMap> setGMap = new FuturedValue();

  CachedValue<List<Element>> _blinkInput, _blinkBorder;
  Blinker _blinker;

  bool isEditing = false;

  String get spotName => _location.name;
  set spotName(String v) {
    if (v == null || _location.name == v) return;
    _location.name = v;
    _onChanged(v);
  }

  Loc.GeoInfo get geoinfo => _location.geoinfo;
  set geoinfo(Loc.GeoInfo v) {
    if (v == null || _location.geoinfo == v) ;
    _location.geoinfo = v;
    _onChanged(v);
  }

  _Location(this._root, this._location, this._onChanged) {
    getBase = new Getter<Element>(() => _root.querySelector('#base'));
    getScroller = new Getter<Element>(() {
      final panel = _root.querySelector('core-header-panel[main]') as CoreHeaderPanel;
      return (panel == null) ? null : panel.scroller;
    });

    gmapElement.future.then((elem) {
      elem
        ..onExpanding = (gmap) {
          gmap
            ..showMyLocationButton = true
            ..options.draggable = true
            ..options.disableDoubleClickZoom = false;
        }
        ..onShrinking = (gmap) {
          gmap
            ..showMyLocationButton = false
            ..options.draggable = false
            ..options.disableDoubleClickZoom = true;
        };
    });
    setGMap.future.then((gmap) {
      gmap
        ..options.draggable = false
        ..putMarker(_location.geoinfo)
        ..onClick = (pos) {
          if (isEditing) {
            gmap.clearMarkers();
            gmap.putMarker(pos);
            geoinfo = pos;
          }
        };
    });

    _blinkInput = new CachedValue(() => _root.querySelectorAll('#location .editor input').toList(growable: false));
    _blinkBorder = new CachedValue(() => _root.querySelectorAll('#location .content .gmap').toList(growable: false));

    _blinker = new Blinker(blinkDuration, blinkDownDuration,
        [new BlinkTarget(_blinkInput, frameBackground), new BlinkTarget(_blinkBorder, frameBorder, frameBorderStop)]);
  }

  void detach() {
    _blinker.stop();
  }

  toggle(event) {
    final button = event.target as PaperIconButton;
    _logger.fine("Toggle edit: ${button.icon}");
    button.icon = isEditing ? editFlip : editFlop;

    if (isEditing) {
      _blinker.stop();
      new Future.delayed(_blinker.blinkStopDuration, () {
        isEditing = false;
      });
    } else {
      _logger.finest("Start editing location.");
      isEditing = true;
      new Future.delayed(new Duration(milliseconds: 10), () {
        _blinkInput.clear();
        _blinkBorder.clear();
        _blinker.start();
      });
    }
  }
}

class _PhotoSize extends _PartOfPage {
  final ShadowRoot _root;

  _PhotoSize(this._root);

  void detach() {}

  int _width;
  int get width {
    if (_width == null) {
      final divNormal = _root.querySelector('#photo');
      if (divNormal != null && 0 < divNormal.clientWidth) {
        _width = divNormal.clientWidth;
      }
    }
    return _width;
  }

  int get height => width;
}

class _Conditions extends _PartOfPage {
  final Loc.Condition _src;
  final OnChanged _onChanged;
  final _WeatherWrapper weather;
  final Getter<EditWeatherDialog> weatherDialog = new PipeValue();
  final Getter<EditTideDialog> tideDialog = new PipeValue();

  _Conditions(Loc.Condition src, OnChanged onChanged)
      : this._src = src,
        this._onChanged = onChanged,
        this.weather = new _WeatherWrapper(src.weather, onChanged);

  void detach() {}

  Loc.Tide get tide => _src.tide;
  set tide(Loc.Tide v) {
    if (_src.tide == v) return;
    _src.tide = v;
    _onChanged(v);
  }

  String get tideName => nameOfEnum(_src.tide);
  String get tideImage => Loc.Tides.iconOf(_src.tide);

  int get moon => _src.moon.age.round();
  String get moonImage => _src.moon.image;

  dialogWeather() => weatherDialog.value.open();
  dialogTide() => tideDialog.value.open();

  _update(DateTime now) async {
    _src.moon = await NaturalConditions.moon(now);
  }
}

class _WeatherWrapper implements Loc.Weather {
  final Loc.Weather _src;
  final OnChanged _onChanged;

  _WeatherWrapper(this._src, this._onChanged);

  Map get asMap => _src.asMap;

  Future<TemperatureUnit> _temperatureUnit;
  Temperature _temperature;
  Temperature get temperature {
    if (_temperature == null && _temperatureUnit == null) {
      _temperatureUnit = UserPreferences.current.then((c) => c.measures.temperature);
      _temperatureUnit.then((unit) {
        _temperature = _src.temperature.convertTo(unit);
        _temperatureUnit = null;
      });
    }
    return _temperature;
  }

  set temperature(Temperature v) {
    if (v == null) return;
    if (_temperature != null && _temperature == v) return;
    _src.temperature = v;
    _temperature = null;
    _onChanged(v);
  }

  String get nominal => _src.nominal;
  set nominal(String v) {
    if (v == null || _src.nominal == v) return;
    _src.nominal = v;
    _onChanged(v);
  }

  String get iconUrl => _src.iconUrl;
  set iconUrl(String v) {
    if (v == null || _src.iconUrl == v) return;
    _src.iconUrl = v;
    _onChanged(v);
  }
}
