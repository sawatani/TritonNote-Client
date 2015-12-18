library triton_note.page.reports_list;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:core_elements/core_animation.dart';

import 'package:triton_note/model/report.dart';
import 'package:triton_note/service/reports.dart';
import 'package:triton_note/util/cordova.dart';
import 'package:triton_note/util/main_frame.dart';
import 'package:triton_note/util/pager.dart';

final _logger = new Logger('ReportsListPage');

@Component(
    selector: 'reports-list',
    templateUrl: 'packages/triton_note/page/reports_list.html',
    cssUrl: 'packages/triton_note/page/reports_list.css',
    useShadowDom: true)
class ReportsListPage extends MainPage {
  final pageSize = 20;

  final PagingList<Report> _reports = Reports.paging;

  ReportsListPage(Router router) : super(router);

  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);

    hideSplashScreen();
  }

  bool get _isEmpty => _reports.list.isEmpty && !_reports.hasMore;
  bool noReports = false;

  PagingList<Report> get reports {
    if (_isEmpty != noReports) {
      noReports = _isEmpty;
      if (noReports) new Future.delayed(new Duration(seconds: 3), () {
        if (noReports) {
          final target = root.querySelector('.list .no-reports');
          final dy = (window.innerHeight / 4).round();

          _logger.finest(() => "Show add_first_report button: ${target}: +${dy}");
          new CoreAnimation()
            ..target = target
            ..duration = 180
            ..easing = 'ease-in'
            ..fill = "both"
            ..keyframes = [
              {'transform': "none", 'opacity': '0'},
              {'transform': "translate(0px, ${dy}px)", 'opacity': '1'}
            ]
            ..play();
        }
      });
    }
    return _reports;
  }

  goReport(Event event, String id) {
    event.target as Element..style.opacity = '1';
    afterRippling(() {
      router.go('report-detail', {'reportId': id});
    });
  }

  addReport() {
    router.go('add', {});
  }
}
