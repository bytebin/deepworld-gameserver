static VALUE within_range_wrapper(VALUE self, VALUE x1, VALUE y1, VALUE x2, VALUE y2, VALUE range) {
  dint _x1 = DINT(x1);
  dint _y1 = DINT(y1);
  dint _x2 = DINT(x2);
  dint _y2 = DINT(y2);
  dint _range = DINT(range);

  if (abs(_x1 - _x2) <= _range && abs(_y1 - _y2) <= _range && hypot(_x2 - _x1, _y2 - _y1) <= _range) {
    return Qtrue;
  }
  else {
    return Qfalse;
  }
}
