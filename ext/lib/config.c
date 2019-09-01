static Config *get_config(VALUE self) {
  Config *c;

  Data_Get_Struct(self, Config, c);

  return c;
}

// Mark for garbage collector
static void mark_config(Config *config) {
}

// Free allocated memory
static void free_config(Config *config) {
  for(dint i=0; i < MAX_ITEM_ID; i++) {
    xfree(config->items[i]);
  }

  xfree(config->items);
  xfree(config);
}

// Allocate memory
static VALUE config_alloc(VALUE klass) {
  Config *config = ALLOC(Config);
  return Data_Wrap_Struct(klass, mark_config, free_config, config);
}

static int initialize_item(VALUE key, VALUE val, VALUE items) {
  // Get the code
  dint code = DINT(rb_hash_aref(val, rb_str_new2("code")));
  //printf("Code: %s\n", StringValueCStr(key));

  if (code > MAX_ITEM_ID - 1) {
    rb_raise(rb_eIndexError, "Item code %d is beyond the MAX_ITEM_ID of %d", (int)code, (int)MAX_ITEM_ID);
  }

  Item *item = ((Item **)items)[code];
  item->code = code;
  item->whole = rb_hash_aref(val, rb_str_new2("whole")) == Qtrue;
  item->shelter = rb_hash_aref(val, rb_str_new2("shelter")) == Qtrue;
  item->tileable = rb_hash_aref(val, rb_str_new2("tileable")) == Qtrue;
  item->shape = rb_hash_aref(val, rb_str_new2("shape")) == Qnil ? false : true;
  item->solid = rb_hash_aref(val, rb_str_new2("solid")) == Qtrue;
  item->door = rb_hash_aref(val, rb_str_new2("door")) == Qtrue;
  item->door_switched = rb_hash_aref(val, rb_str_new2("door_switched")) == Qtrue;
  item->earthy = rb_hash_aref(val, rb_str_new2("earthy")) == Qtrue;
  item->growth = rb_hash_aref(val, rb_str_new2("growth")) == Qtrue;
  item->toughness = rb_hash_aref(val, rb_str_new2("toughness")) == Qnil ? 0 : DINT(rb_hash_aref(val, rb_str_new2("toughness")));
  item->block_size = vector2_from_coord(rb_hash_aref(val, rb_str_new2("block_size")));
  item->steam = rb_hash_aref(val, rb_str_new2("steam")) == Qtrue;

  return ST_CONTINUE;
}

static Item **initialize_items(VALUE item_config) {
  Item **items = ALLOC_N(Item*, MAX_ITEM_ID);

  // Initialize "null" items
  for(dint i=0; i < MAX_ITEM_ID; i++) {
    items[i] = ALLOC(Item);

    items[i]->code = -1;
    items[i]->whole = false;
    items[i]->shelter = false;
    items[i]->tileable = false;
    items[i]->shape = false;
    items[i]->solid = false;
    items[i]->door = false;
    items[i]->door_switched = false;
    items[i]->earthy = false;
    items[i]->growth = false;
    items[i]->toughness = 0;
    items[i]->block_size = (Vector2) { 0, 0 };
  }

  rb_hash_foreach(item_config, initialize_item, (VALUE)items);

  return items;
}

// Initializer
static VALUE config_init(VALUE self, VALUE item_config) {
  // Get references
  Config *config = get_config(self);

  // Get sunlight indexes
  config->items = initialize_items(item_config);

  return self;
}

static VALUE get_item(VALUE self, VALUE item_code) {
  // Get the code
  dint code = parse_dint(item_code);

  // Get the item
  Config *config = get_config(self);
  Item *item = config->items[code];

  VALUE result = rb_hash_new();
  rb_hash_aset(result, rb_str_new2("code"), NUM(item->code));
  rb_hash_aset(result, rb_str_new2("whole"), bool_value(item->whole));
  rb_hash_aset(result, rb_str_new2("shelter"), bool_value(item->shelter));
  rb_hash_aset(result, rb_str_new2("tileable"), bool_value(item->tileable));
  rb_hash_aset(result, rb_str_new2("shape"), bool_value(item->shape));
  rb_hash_aset(result, rb_str_new2("solid"), bool_value(item->solid));
  rb_hash_aset(result, rb_str_new2("door"), bool_value(item->door));
  rb_hash_aset(result, rb_str_new2("door_switched"), bool_value(item->door_switched));
  rb_hash_aset(result, rb_str_new2("toughness"), NUM(item->toughness));
  rb_hash_aset(result, rb_str_new2("earthy"), bool_value(item->earthy));
  rb_hash_aset(result, rb_str_new2("growth"), bool_value(item->growth));
  rb_hash_aset(result, rb_str_new2("block_size"), coord_from_vector2(item->block_size));

  return result;
}
