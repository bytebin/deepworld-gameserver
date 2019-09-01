class Configuration {

    int x;
    int y;

  public:

    void do_some_shit(){

    };
};

// Mark for garbage collector
static void mark_configuration(Configuration *config) {
}

// Free allocated memory
static void free_configuration(Configuration *config) {
  xfree(config);
}

// Allocate memory
static VALUE configuration_alloc(VALUE self) {
  Configuration *config = new Configuration();

  return Data_Wrap_Struct(self, mark_configuration, free_configuration, config);
}

static Configuration *get_config(VALUE self) {
  Configuration *c;

  Data_Get_Struct(self, Configuration, c);

  return c;
}

// Initialization
static VALUE configuration_init(VALUE self, VALUE item_hash) {
  //Configuration *config = get_config(self);
  // Parse the item hash
  return self;
}
