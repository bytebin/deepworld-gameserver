#ifndef __LIGHT__
#define __LIGHT__

static void mark_light(Light *light);
static void free_light(Light *light);
static VALUE light_alloc(VALUE klass);
static VALUE light_init(VALUE self, VALUE _zone);
static VALUE recalculate(VALUE self, VALUE x);
static dbool light_at(Light *light, dint x, dint y);
static VALUE light_at_wrapper(VALUE self, VALUE x, VALUE y);
static VALUE dark_at(VALUE self, VALUE x, VALUE y);
static VALUE sunlight(VALUE self);
static dint *light_scan(Zone *zone, dint start_x, dint length);
static dint light_query(Zone *zone, dint x);

#endif
