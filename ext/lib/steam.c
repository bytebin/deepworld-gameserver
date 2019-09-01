#define STEAM_LIMIT 400

static Steam *get_steam(VALUE self) {
  if (VERBOSE > 1) printf("get_steam\n");
  Steam *s;

  Data_Get_Struct(self, Steam, s);

  return s;
}

static void mark_steam(Steam *steam) {
  if (VERBOSE > 0) printf("mark_steam\n");
}


static VALUE steam_alloc(VALUE klass) {
  if (VERBOSE > 0) printf("steam_alloc\n");

  Steam *steam = ALLOC(Steam);
  return Data_Wrap_Struct(klass, mark_steam, free_steam, steam);
}

static void free_steam_objects(Steam *steam) {
  if (steam->freed != true) {
    xfree(steam->recursed);
    steam->freed = true;
  }
}

static void free_steam(Steam *steam) {
  free_steam_objects(steam);

  xfree(steam);
}

static VALUE free_steam_wrapper(VALUE self) {
  Steam *steam = get_steam(self);
  free_steam_objects(steam);

  return true;
}

// Steam initialize
static VALUE steam_init(VALUE self, VALUE _zone) {
  if (VERBOSE > 0) printf("steam_init\n");

  Zone *zone = get_zone(_zone);

  // Get references
  Steam *steam = get_steam(self);
  steam->recursed = ALLOC_N(dbool, zone->size.x * zone->size.y);
  steam->zone = zone;
  zone->steam = steam;

  return self;
}

static VALUE steam_step(VALUE self, VALUE collectors, VALUE steamables, VALUE collectors_always_on) {
  Steam *steam = get_steam(self);
  if (steam->freed == true) {
    return Qnil;
  }

  Zone *zone = steam->zone;
  dbool _collectors_always_on = (collectors_always_on == Qtrue);

  //printf("steam step: %d collector(s), %d steamable(s)\n", (dint)RARRAY_LEN(collectors), (dint)RARRAY_LEN(steamables));

  // Stop power to steamables (they will be reactivated in recursive step if powered)
  for (dint s = 0; s < RARRAY_LEN(steamables); s++) {
    VALUE steamable_position = rb_ary_entry(steamables, s);
    dint x = DINT(rb_ary_entry(steamable_position, 0));
    dint y = DINT(rb_ary_entry(steamable_position, 1));

    Layer front = front_peek(zone, x, y);
    if (front.mod > 0) {
      block_update(zone, x, y, FRONT, front.item, 0, 0, true);
      //printf("disable steam item #%d %dx%d (item %d)\n", s, x, y, front.item);
    }
  }

  // Clear recursed data
  memset(steam->recursed, 0, zone->size.x * zone->size.y);

  // Iterate through collectors
  for (dint c = 0; c < RARRAY_LEN(collectors); c++) {
    VALUE collector_position = rb_ary_entry(collectors, c);
    dint x = DINT(rb_ary_entry(collector_position, 0));
    dint y = DINT(rb_ary_entry(collector_position, 1));

    //printf("steam collector at %dx%d\n", x, y);

    // Only process collector if over steam vent
    if (in_bounds(zone, x + 1, y - 1)) {
      Layer base = base_peek(zone, x + 1, y - 1);
      if (base.item == 10 || _collectors_always_on) {
        // Recurse from each collector spout
        steam_recurse(steam, x + 1, y - 3, 0, 0); // Top
        steam_recurse(steam, x + 3, y - 1, 1, 0); // Right
        steam_recurse(steam, x + 1, y + 1, 2, 0); // Bottom
        steam_recurse(steam, x - 1, y - 1, 3, 0); // Left
      }
    }
  }

  return Qnil;
}

static void steam_recurse(Steam *steam, dint x, dint y, dint direction, dint steps) {
  //if (steps == 0) printf("steam start at %dx%d => %d\n", x, y, direction);
  //else printf("steam recurse at %dx%d => %d (%d steps)\n", x, y, direction, steps);

  // Check bounds
  if (!in_bounds(steam->zone, x, y)) return;

  // Stop recursion if too many steps
  steps++;
  if (steps > STEAM_LIMIT) return;

  // Check if we've already hit this block
  dint idx = y * steam->zone->size.x + x;
  if (steam->recursed[idx] == true) return;
  steam->recursed[idx] = true;

  // Continue recursion if over a pipe
  Layer front = front_peek(steam->zone, x, y);
  if (front.item == 860) {
    if (direction != 2)
      steam_recurse(steam, x, y - 1, 0, steps); // Top
    if (direction != 3)
      steam_recurse(steam, x + 1, y, 1, steps); // Right
    if (direction != 0)
      steam_recurse(steam, x, y + 1, 2, steps); // Bottom
    if (direction != 1)
      steam_recurse(steam, x - 1, y, 3, steps); // Left
  }
  else if (steam->zone->config->items[front.item]->steam) {
    block_update(steam->zone, x, y, FRONT, front.item, 1, 0, true);
  }
}
