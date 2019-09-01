static Light *get_light(VALUE self) {
  if (VERBOSE > 0) printf("get_light\n");
  Light *l;

  Data_Get_Struct(self, Light, l);

  return l;
}

// Mark for garbage collector
static void mark_light(Light *light) {
  if (VERBOSE > 0) printf("mark_light\n");
}

// Free allocated memory
static void free_light(Light *light) {
  if (VERBOSE > 0) printf("free_chunks\n");

  // Free sunlight indexes
  xfree(light->sunlight);

  // Free the light
  xfree(light);
}

// Allocate memory
static VALUE light_alloc(VALUE klass) {
  if (VERBOSE > 0) printf("light_alloc\n");

  Light *light = ALLOC(Light);
  return Data_Wrap_Struct(klass, mark_light, free_light, light);
}

// Light initialize
static VALUE light_init(VALUE self, VALUE _zone) {
  if (VERBOSE > 0) printf("light_init\n");

  Zone *zone = get_zone(_zone);

  // Get references
  Light *light = get_light(self);
  light->zone = zone;
  zone->light = light;

  // Get sunlight indexes
  light->sunlight = light_scan(zone, 0, zone->size.x);

  return self;
}

// NOTE: this allocates a results array that needs to be freed
static dint *light_scan(Zone *zone, dint start_x, dint length) {
  if (VERBOSE > 1) printf("light_scan\n");

  if (start_x < 0 || start_x > zone->size.x - 1 || length < 0 || start_x + length - 1 > zone->size.x)
    rb_raise(rb_eArgError, "Light scan arguments are out of zone bounds.");

  // Allocate and fill the results
  dint *results = ALLOC_N(dint, length);
  for(dint x = start_x; x < start_x + length; x++) { results[x] = light_query(zone, x); }
  return results;
}

// Query for the topmost shelter coordinate
static dint light_query(Zone *zone, dint x) {
  if (VERBOSE > 1) printf("light query\n");

  if (x < 0 || x > zone->size.x - 1)
    rb_raise(rb_eArgError, "Light query x argument is out of zone bounds.");

  // Search for the first shelter
  for(dint y = 0; y < zone->size.y; y++) {
    if (is_shelter(zone, x, y, true)) return y;
  }

  return zone->size.y - 1;
}

// Update sunlight at an x coordinate
static VALUE recalculate(VALUE self, VALUE _x) {
  Light *light = get_light(self);

  dint x = DINT(_x);
  dint y = light_query(light->zone, x);

  if (y != light->sunlight[x]) {
    light->sunlight[x] = y;
    rb_funcall(light->zone->ruby_zone, rb_intern("queue_light_update"), 2, _x, NUM(y));
  }

  return NUM(y);
}

static VALUE light_at_wrapper(VALUE self, VALUE x, VALUE y) {
  Light *light = get_light(self);
  return light_at(light, DINT(x), DINT(y)) ? Qtrue : Qfalse;
}

static dbool light_at(Light *light, dint x, dint y) {
  if (x < 0 || x >= light->zone->size.x) return false;
  return light->sunlight[x] >= y;
}

static VALUE dark_at(VALUE self, VALUE x, VALUE y) {
  Light *light = get_light(self);
  return light->sunlight[DINT(x)] < DINT(y) ? Qtrue : Qfalse;
}

static VALUE sunlight(VALUE self) {
  Light *light = get_light(self);

  // Load up a ruby array
  VALUE sun = rb_ary_new2(light->zone->size.x);
  for (dint i=0; i < light->zone->size.x; i++) { rb_ary_store(sun, i, NUM(light->sunlight[i])); }

  return sun;
}
