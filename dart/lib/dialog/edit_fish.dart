library triton_note.dialog.edit_fish;

import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:paper_elements/paper_dialog.dart';

import 'package:triton_note/model/report.dart';
import 'package:triton_note/model/value_unit.dart';
import 'package:triton_note/service/preferences.dart';
import 'package:triton_note/util/getter_setter.dart';
import 'package:triton_note/util/enums.dart';
import 'package:triton_note/util/main_frame.dart';

final _logger = new Logger('EditFishDialog');

@Component(selector: 'edit-fish-dialog', templateUrl: 'packages/triton_note/dialog/edit_fish.html', useShadowDom: true)
class EditFishDialog extends AbstractDialog implements ShadowRootAware {
  @NgOneWayOneTime('setter') set setter(Setter<EditFishDialog> v) => v?.value = this; // Optional

  Measures _measures;
  ShadowRoot _root;
  CachedValue<PaperDialog> _dialog;
  PaperDialog get realDialog => _dialog.value;

  GetterSetter<Fishes> _original;
  Fishes tmpFish;

  EditFishDialog() {
    UserPreferences.current.then((c) => _measures = c.measures);
  }

  bool get isCommitable => (tmpFish?.name?.isNotEmpty ?? false) && tmpFishCount > 0;

  // count
  int get tmpFishCount => (tmpFish == null) ? null : tmpFish.count;
  set tmpFishCount(int v) => (tmpFish == null) ? null : tmpFish.count = (v == null) ? null : v;

  // lenth
  int get tmpFishLength => (tmpFish == null) ? null : tmpFish.length.value.round();
  set tmpFishLength(int v) => (tmpFish == null) ? null : tmpFish.length.value = (v == null) ? null : v.toDouble();

  // weight
  int get tmpFishWeight => (tmpFish == null) ? null : tmpFish.weight.value.round();
  set tmpFishWeight(int v) => (tmpFish == null) ? null : tmpFish.weight.value = (v == null) ? null : v.toDouble();

  String get lengthUnit => _measures == null ? null : nameOfEnum(_measures.length);
  String get weightUnit => _measures == null ? null : nameOfEnum(_measures.weight);

  void onShadowRoot(ShadowRoot sr) {
    _root = sr;
    _dialog = new CachedValue(() => _root.querySelector('paper-dialog'));
  }

  openWith(GetterSetter<Fishes> value) {
    UserPreferences.current.then((_) {
      _original = value;
      final fish = _original.value.clone();

      if (fish.count == null || fish.count < 1) fish.count = 1;
      fish.length =
          (fish.length == null) ? new Length.of(_measures.length, 0) : fish.length.convertTo(_measures.length);
      fish.weight =
          (fish.weight == null) ? new Weight.of(_measures.weight, 0) : fish.weight.convertTo(_measures.weight);
      _logger.fine("Editing fish: ${fish}");

      tmpFish = fish;
      open();
    });
  }

  commit() {
    if (!isCommitable) return;

    _logger.fine("Commit fish: ${tmpFish}");
    close();
    final fish = tmpFish.clone();

    if (fish.length != null && fish.length.value == 0) fish.length = null;
    if (fish.weight != null && fish.weight.value == 0) fish.weight = null;
    _logger.finest("Set fish: ${fish}");

    _original.value = fish;
  }

  delete() {
    _logger.fine("Deleting fish");
    close();
    _original.value = null;
  }

  cancel() {
    close();
  }
}
