// Parse a dint from a string or fixnum value
static dint parse_dint(VALUE value) {
  switch( TYPE(value) ) {
    case T_STRING: {
      return DINT(rb_funcall(value, rb_intern("to_i"), 0));
      }

    case T_FIXNUM: {
      return DINT(value);
      }

    default : {
      rb_raise(rb_eArgError, "Invalid type for integer parse.");
      break;
    }
  }
}

static VALUE coord_from_vector2(Vector2 vector2) {
  VALUE coord = rb_ary_new2(2);
  rb_ary_store(coord, 0, NUM(vector2.x));
  rb_ary_store(coord, 1, NUM(vector2.y));

  return coord;
}

static Vector2 vector2_from_coord(VALUE coord) {
  if (coord == Qnil) return (Vector2){ 0, 0 };

  if (RARRAY_LEN(coord) != 2)
    rb_raise(rb_eArgError, "Array length of %d for coordinate is incorrect!", (int)RARRAY_LEN(coord));

  return (Vector2){ DINT(rb_ary_entry(coord, 0)), DINT(rb_ary_entry(coord, 1)) };
}

static VALUE bool_value(dbool value) {
  return value ? Qtrue : Qfalse;
}
