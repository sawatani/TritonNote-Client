library triton_note.element.num_input;

import 'package:logging/logging.dart';
import 'package:angular/angular.dart';

import 'package:triton_note/util/getter_setter.dart';

final _logger = new Logger('NumInputElement');

@Component(
    selector: 'num-input',
    templateUrl: 'packages/triton_note/element/num_input.html',
    cssUrl: 'packages/triton_note/element/num_input.css',
    useShadowDom: true)
class NumInputElement {
  @NgOneWayOneTime('setter') set setter(Setter<NumInputElement> v) => v?.value = this; // Optional
  @NgTwoWay('value') int value;
  @NgAttr('digits') String digits;
  @NgAttr('font-size') String size;
  @NgAttr('max') String max;
  @NgAttr('min') String min;

  int get numDigits => digits == null ? 2 : int.parse(digits);
  int get fontSize => size == null ? 20 : int.parse(size);
  int get minValue => min == null ? null : int.parse(min);
  int get maxValue => max == null ? null : int.parse(max);

  int get curValue => value ?? (minValue ?? 0);
  set curValue(int v) {
    final s = v.toString();
    int a = 0;
    try {
      a = int.parse(s);
    } catch (ex) {
      _logger.info("Invalid integer: ${s}");
    }
    return value = _limit(a);
  }

  _loop(int v) {
    final loop = (maxValue - minValue + 1);
    return (v + loop) % loop + minValue;
  }

  _limit(int v) {
    if (maxValue != null && minValue != null) return _loop(v);
    if (minValue != null && v < minValue) return minValue;
    if (maxValue != null && maxValue < v) return maxValue;
    return v;
  }

  up() {
    curValue = curValue + 1;
  }

  down() {
    curValue = curValue - 1;
  }
}
