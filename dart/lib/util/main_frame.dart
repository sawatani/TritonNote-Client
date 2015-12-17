library triton_note.util.main_frame;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:paper_elements/paper_dialog.dart';
import 'package:core_elements/core_drawer_panel.dart';

import 'package:triton_note/util/cordova.dart';

final _logger = new Logger('MainFrame');

const ripplingDuration = const Duration(milliseconds: 250);

Future afterRippling(Proc()) {
  return new Future.delayed(ripplingDuration, Proc);
}

const listenDur = const Duration(milliseconds: 10);
void listenOn(Element target, String eventType, void proc(Element target)) {
  Timer timer;
  target.on[eventType].listen((event) {
    if (event.target == target) {
      if (timer != null && timer.isActive) timer.cancel();
      timer = new Timer(listenDur, () => proc(target));
    }
  });
}

abstract class _Backable {
  static List<_Backable> _current;

  _pushMe() {
    if (_current == null) {
      _current = [];

      _logger.finest(() => "Listen on 'backbutton'");
      document.addEventListener('backbutton', (event) {
        if (_current.isNotEmpty) _current.last.backButton();
      }, false);
    }
    _current.add(this);
    _logger.finest(() => "Pushed current page: ${_current}");
  }

  _popMe() {
    _current.remove(this);
    _logger.finest(() => "Poped current page: ${_current}");
  }

  backButton();
}

abstract class _AbstractPage extends _Backable implements ShadowRootAware, AttachAware, DetachAware {
  ShadowRoot _root;
  ShadowRoot get root => _root;

  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
  }

  void attach() => _pushMe();
  void detach() => _popMe();

  rippling(proc()) => afterRippling(proc);
}

abstract class MainPage extends _AbstractPage {
  final Router router;

  MainPage(this.router);

  bool _drawerOpened = false;
  CoreDrawerPanel get drawerPanel => root.querySelector('core-drawer-panel#mainFrame');

  openMenu() {
    drawerPanel.openDrawer();
    _drawerOpened = true;
  }

  closeMenu() {
    drawerPanel.closeDrawer();
    _drawerOpened = false;
  }

  backButton() {
    if (_drawerOpened) {
      closeMenu();
    } else {
      exit();
    }
  }

  void _goByMenu(String routeId) => rippling(() {
        _logger.info("Going to ${routeId}");
        drawerPanel.closeDrawer();
        router.go(routeId, {});
      });
  void goReportsList() => _goByMenu('reports-list');
  void goPreferences() => _goByMenu('preferences');
  void goDistributions() => _goByMenu('distributions');
  void goExperiment() => _goByMenu('experiment');
}

abstract class SubPage extends _AbstractPage {
  back() => window.history.back();
  backButton() => back();
}

abstract class AbstractDialog extends _Backable {
  PaperDialog get realDialog;
  var _onOpenning, _onClossing;

  Completer<Null> _closed;

  backButton() => close();

  onOpening(proc()) => _onOpenning = proc;
  onClossing(proc()) => _onClossing = proc;

  open() {
    if (!(_closed?.isCompleted ?? true)) return;
    _closed = new Completer();

    if (_onOpenning != null) _onOpenning();
    realDialog.open();

    realDialog.on['core-overlay-close-completed'].listen((event) {
      if (!_closed.isCompleted) _closed.complete();
    });

    _pushMe();
    _closed.future.then((_) {
      _popMe();
    });
  }

  close() async {
    if (_onClossing != null) _onClossing();

    realDialog.close();

    new Timer(ripplingDuration, () {
      if (!_closed.isCompleted) {
        _logger.warning(() => "Time over: clear overlay manually...");
        realDialog.style.display = 'none';
        _closed.complete();
      }
      document.body.querySelectorAll('.core-overlay-backdrop').forEach((e) {
        _logger.finest(() => "Clearing overlay: ${e}");
        e.remove();
      });
    });

    return _closed.future;
  }
}
