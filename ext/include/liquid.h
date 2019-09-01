#ifndef __LIQUID__
#define __LIQUID__

static Liquid *get_liquid(VALUE self);
static VALUE liquid_alloc(VALUE klass);

// Liquid initialize
static VALUE liquid_init(VALUE self, VALUE zone);

static dint liquid_transfer(Liquid *liquid, dint item, dint mod, dint source_x, dint source_y, dint dest_x, dint dest_y, dbool vertical, dint minDiff, dbool allowDiagonal);
static VALUE liquid_step(VALUE self);
static void index_all_liquids(Liquid *liquid);
static void index_liquid(Liquid *liquid, dint x, dint y);

static dbool is_wet(Zone *zone, dint x, dint y);
static dbool is_dry(Zone *zone, dint x, dint y);

#endif
