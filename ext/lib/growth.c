static Growth *get_growth(VALUE self) {
  if (VERBOSE > 0) printf("get_growth\n");
  Growth *g;

  Data_Get_Struct(self, Growth, g);

  return g;
}

// Mark for garbage collector
static void mark_growth(Growth *growth) {
  if (VERBOSE > 0) printf("mark_growth\n");
}

// Free allocated memory
static void free_growth(Growth *growth) {
  if (VERBOSE > 0) printf("free_growth\n");

  xfree(growth);
}

// Allocate memory
static VALUE growth_alloc(VALUE klass) {
  if (VERBOSE > 0) printf("growth_alloc\n");

  Growth *growth = ALLOC(Growth);
  return Data_Wrap_Struct(klass, mark_growth, free_growth, growth);
}

// Growth initialize
static VALUE growth_init(VALUE self, VALUE _zone) {
  if (VERBOSE > 0) printf("growth_init\n");

  Zone *zone = get_zone(_zone);

  // Get references
  Growth *growth = get_growth(self);
  growth->zone = zone;

  return self;
}

// Returns an array of light growable items
// [[x coord of growable, y coord of growable, item_code above it, mod above it], ...]
static VALUE growables(VALUE self) {
  Growth *growth = get_growth(self);
  Zone *zone = growth->zone;

  VALUE results = rb_ary_new();

  // Find surface growables that are within sunlight
  for (dint x = 0; x < zone->size.x; x++) {
    // Determine max depth to check based on sunlight
    dint max_y = zone->light->sunlight[x] + 1;
    if (max_y >= zone->size.y) max_y = zone->size.y;

    for (dint y = 1; y < max_y; y++) {
      Layer front = front_peek(zone, x, y);
      // Add to results if growable
      if (growth_item(zone, front.item)) {
        // Get item above
        Layer above = front_peek(zone, x, y - 1);

        // Create result array
        VALUE grow = rb_ary_new2(5);
        rb_ary_store(grow, 0, NUM(x)); // x
        rb_ary_store(grow, 1, NUM(y)); // y
        rb_ary_store(grow, 2, NUM(front.item)); // growable item
        rb_ary_store(grow, 3, NUM(above.item)); // above item
        rb_ary_store(grow, 4, NUM(above.mod)); // above mod
        rb_ary_push(results, grow);
      }
    }
  }

  return results;
}
