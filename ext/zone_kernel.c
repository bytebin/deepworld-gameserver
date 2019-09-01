// Docs
// http://clalance.blogspot.com/search/label/C
// http://blog.jacius.info/ruby-c-extension-cheat-sheet/

#include <ruby.h>
#include <math.h>
#include "msgpack.h"
#include "include/debug.h"
#include "include/config.h"
#include "include/zone_kernel.h"
#include "include/helpers.h"
#include "include/light.h"
#include "include/liquid.h"
#include "include/steam.h"
#include "include/growth.h"
#include "include/util.h"

#include "lib/helpers.c"
#include "lib/config.c"
#include "lib/zone.c"
#include "lib/light.c"
#include "lib/liquid.c"
#include "lib/steam.c"
#include "lib/growth.c"
#include "lib/util.c"

// Ruby extension initialization
void Init_zone_kernel(void) {
  if (VERBOSE == 1) printf("Init_zone_kernel\n");

  // ZoneKernel module
  mZoneKernel = rb_define_module("ZoneKernel");

  // Zone Class
  cZone = rb_define_class_under(mZoneKernel, "Zone", rb_cObject);
  rb_define_alloc_func(cZone, zone_alloc);
  rb_define_method(cZone, "initialize", zone_init, 7);
  rb_define_method(cZone, "chunk", get_chunk_wrapper, 2);
  rb_define_method(cZone, "chunks", get_chunks_wrapper, 1);
  rb_define_method(cZone, "chunk_data", get_chunk_data_wrapper, 1);
  rb_define_method(cZone, "chopped_chunks", chopped_chunks_data_wrapper, 4);
  rb_define_method(cZone, "block", get_block_wrapper, 2);
  rb_define_method(cZone, "block_update", block_update_wrapper, 6);
  rb_define_method(cZone, "block_peek", block_peek_wrapper, 3);
  rb_define_method(cZone, "all_peek", all_peek_wrapper, 2);
  rb_define_method(cZone, "block_owner", block_owner_wrapper, 3);
  rb_define_method(cZone, "clear_owners", clear_owners_wrapper, 0);
  rb_define_method(cZone, "item_counts", item_counts_wrapper, 0);
  rb_define_method(cZone, "block_query", block_query_wrapper, 5);
  rb_define_method(cZone, "earth_query", earthy_query_wrapper, 4);
  rb_define_method(cZone, "below_query", below_query_wrapper, 4);
  rb_define_method(cZone, "raycast", raycast_wrapper, 9);
  //rb_define_method(cZone, "cache_blocked", cache_blocked_wrapper, 0);
  rb_define_method(cZone, "blocked?", is_blocked_wrapper, 5);
  rb_define_method(cZone, "free!", free_zone_wrapper, 0);
  rb_define_method(cZone, "step!", zone_step, 1);

  // Liquid Class
  cLiquid = rb_define_class_under(mZoneKernel, "Liquid", rb_cObject);
  rb_define_alloc_func(cLiquid, liquid_alloc);
  rb_define_method(cLiquid, "initialize", liquid_init, 1);
  rb_define_method(cLiquid, "step!", liquid_step, 0);
  rb_define_method(cLiquid, "free!", free_liquid_wrapper, 0);

  // Steam Class
  cSteam = rb_define_class_under(mZoneKernel, "Steam", rb_cObject);
  rb_define_alloc_func(cSteam, steam_alloc);
  rb_define_method(cSteam, "initialize", steam_init, 1);
  rb_define_method(cSteam, "step!", steam_step, 3);
  rb_define_method(cSteam, "free!", free_steam_wrapper, 0);

  // Light Class
  cLight = rb_define_class_under(mZoneKernel, "Light", rb_cObject);
  rb_define_alloc_func(cLight, light_alloc);
  rb_define_method(cLight, "initialize", light_init, 1);
  rb_define_method(cLight, "light_at", light_at_wrapper, 2);
  rb_define_method(cLight, "dark_at", dark_at, 2);
  rb_define_method(cLight, "recalculate", recalculate, 1);
  rb_define_method(cLight, "sunlight", sunlight, 0);

  // Growth Class
  cGrowth = rb_define_class_under(mZoneKernel, "Growth", rb_cObject);
  rb_define_alloc_func(cGrowth, growth_alloc);
  rb_define_method(cGrowth, "initialize", growth_init, 1);
  rb_define_method(cGrowth, "growables", growables, 0);

  // Configuration Class
  cConfig = rb_define_class_under(mZoneKernel, "Config", rb_cObject);
  rb_define_alloc_func(cConfig, config_alloc);
  rb_define_method(cConfig, "initialize", config_init, 1);
  rb_define_method(cConfig, "get_item", get_item, 1);

  // Utility Class
  cUtil = rb_define_class_under(mZoneKernel, "Util", rb_cObject);
  rb_define_singleton_method(cUtil, "within_range?", within_range_wrapper, 5);
}
