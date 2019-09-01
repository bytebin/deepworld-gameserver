#ifndef __STEAM__
#define __STEAM__

static Steam *get_steam(VALUE self);
static VALUE steam_alloc(VALUE klass);
static void free_steam(Steam *steam);

// Steam initialize
static VALUE steam_init(VALUE self, VALUE zone);

static VALUE steam_step(VALUE self, VALUE collectors, VALUE steamables, VALUE collectors_always_on);
static void steam_recurse(Steam *steam, dint x, dint y, dint direction, dint steps);
//static void index_collectors(Steam *steam);
//static dbool is_collector(Zone *zone, dint x, dint y);

#endif
