int int_cmp(const void *a, const void *b) {
    const dint *ia = (const dint *)a; // casting pointer types
    const dint *ib = (const dint *)b;
    return (int) (*ia  - *ib);
}

static Liquid *get_liquid(VALUE self) {
  if (VERBOSE > 1) printf("get_liquid\n");
  Liquid *l;

  Data_Get_Struct(self, Liquid, l);

  return l;
}

static void mark_liquid(Liquid *liquid) {
  if (VERBOSE > 0) printf("mark_liquid\n");
}

static void free_liquid_objects(Liquid *liquid) {
  if (liquid->freed != true) {
    xfree(liquid->blocks);

    liquid->freed = true;
  }
}

static void free_liquid(Liquid *liquid) {
  free_liquid_objects(liquid);

  xfree(liquid);
}

static VALUE free_liquid_wrapper(VALUE self) {
  Liquid *liquid = get_liquid(self);
  free_liquid_objects(liquid);

  return true;
}

static VALUE liquid_alloc(VALUE klass) {
  if (VERBOSE > 0) printf("liquid_alloc\n");

  Liquid *liquid = ALLOC(Liquid);
  return Data_Wrap_Struct(klass, mark_liquid, free_liquid, liquid);
}

// Liquid initialize
static VALUE liquid_init(VALUE self, VALUE _zone) {
  if (VERBOSE > 0) printf("liquid_init\n");

  Zone *zone = get_zone(_zone);

  // Get references
  Liquid *liquid = get_liquid(self);
  liquid->zone = zone;
  zone->liquid = liquid;
  liquid->steps = 0;
  liquid->blocks = ALLOC_N(dint, 1);

  index_all_liquids(liquid);

  return self;
}

static void index_liquid(Liquid *liquid, dint x, dint y) {
  if (liquid->blocks_count < liquid->max_blocks_count) {
    liquid->blocks[liquid->blocks_count] = y * liquid->zone->size.x + x;
    liquid->blocks_count++;
  }
  else
    printf("Liquid index error: blocks count is greater than max blocks count!\n");
}

static void index_all_liquids(Liquid *liquid) {
  Zone *zone = liquid->zone;

  // Count liquid blocks
  dint count = 0;
  for (dint y = 0; y < zone->size.y; y++) {
    for (dint x = 0; x < zone->size.x; x++) {
      if (is_wet(zone, x, y))
        count++;
    }
  }

  // Reindex liquid blocks
  xfree(liquid->blocks);

  liquid->blocks_count = 0;
  liquid->blocks = ALLOC_N(dint, count);
  count = 0;
  for (dint y = 0; y < zone->size.y; y++) {
    for (dint x = 0; x < zone->size.x; x++) {
      if (is_wet(zone, x, y)) {
        liquid->blocks[liquid->blocks_count] = y * zone->size.x + x;
        liquid->blocks_count++;
      }
    }
  }
}

static dbool is_dry(Zone *zone, dint x, dint y) {
  if (!in_bounds(zone, x, y)) return true;

  Layer layer = liquid_peek(zone, x, y);
  if (layer.item == 0) return true;
  return !(layer.mod > 0);
}

static dbool is_wet(Zone *zone, dint x, dint y) {
  return !is_dry(zone, x, y);
}

static VALUE liquid_step(VALUE self) {
  Liquid *liquid = get_liquid(self);

  // Ignore if liquid has been freed
  if (liquid->freed == true) {
    return Qnil;
  }

  Zone *zone = liquid->zone;

  if (VERBOSE > 1)
    printf("liquid_step (%d liquids) \n", (int)liquid->blocks_count);

  // Get our liquid reserves hash
  VALUE reserves = rb_iv_get(zone->ruby_zone, "@liquid_reserves");
  if(reserves == Qnil)
    rb_raise(rb_eNoMethodError, "Unable to access liquid_reserves hash from zone");

  dint mod;

  for (dint step = 0; step < 1; step++) {

    // Remove liquid index duplicates
    dint pre_dup_blocks_count = liquid->blocks_count;
    if (liquid->blocks_count > 0)
      liquid->blocks_count = compact(liquid->blocks, liquid->blocks_count);
    if (VERBOSE > 2)
      printf("liquid_step (%d liquids, %d dups)\n", (int)liquid->blocks_count, (int)(pre_dup_blocks_count - liquid->blocks_count));

    // Sort liquid indices
    qsort(liquid->blocks, liquid->blocks_count, sizeof(dint), int_cmp);

    // Copy old liquid index
    dint old_liquid_blocks_count = liquid->blocks_count;
    dint *old_liquid_blocks = liquid->blocks;

    // Allocate new liquid index
    liquid->blocks_count = 0;
    liquid->max_blocks_count = max(old_liquid_blocks_count * 3, 1000);
    liquid->blocks = ALLOC_N(dint, liquid->max_blocks_count);

    // Iterate through liquid blocks and transfer
    for (dint l = old_liquid_blocks_count - 1; l >= 0; l--) {
      dint idx = old_liquid_blocks[l];
      dint x = (dint) ((int)idx % (int)zone->size.x);
      dint y = (dint) ((int)idx / (int)zone->size.x);

      //printf("liq { %d x %d } idx %d, size %d", (int)x, (int)y, (int)idx, (int)zone->size.x);

      // Skip if liquid not in active chunk
      dint chunk_idx = chunk_index(zone, x, y);
      if (zone->active_chunk_indexes[chunk_idx] == false) {
        index_liquid(liquid, x, y); // Just reindex, since we're not moving
      }

      // Process liquid
      else {
        Layer liq = block_peek(zone, x, y, LIQUID);
        if (liq.item > 0 && liq.mod > 0) {

          // Evaporate if a whole block sits in front of the liquid
          if (is_whole(zone, x, y, false)) {
            dint prev = DINT(rb_hash_aref(reserves, NUM(liq.item)));
            rb_hash_aset(reserves, NUM(liq.item), NUM(prev + liq.mod));

            block_update(zone, x, y, LIQUID, 0, 0, 0, true);
          }
          else {
            mod = liquid_transfer(liquid, liq.item, liq.mod, x, y, x, y + 1, true, 0, false); // Down
            if (mod == liq.mod) {
              mod = liquid_transfer(liquid, liq.item, liq.mod, x, y, x - 1, y, false, 1, true); // Left
              if (mod > 0) {
                mod = liquid_transfer(liquid, liq.item, mod, x, y, x + 1, y, false, 1, true); // Right
                if (mod > 0) {
                  for (dint hdir = -1; hdir <= 1; hdir += 2) {
                    dint h = 2; // Start with distance 2
                    dint hmax = 15; // Max distance from origin
                    while (h < hmax && mod > 0) {
                      if (in_bounds(zone, x + (h * hdir), y) && // If still in bounds
                        !is_whole(zone, x + ((h-1) * hdir), y, false) &&  // The block before the destination is not whole
                        (block_peek(zone, x + (h * hdir), y, LIQUID).item > 0 || // The block is either liquid...
                        (!in_bounds(zone, x + (h * hdir), y + 1) || is_whole(zone, x + (h * hdir), y + 1, false))) // Or the block beneath it is whole
                      ){
                        mod = liquid_transfer(liquid, liq.item, mod, x, y, x + (h * hdir), y, false, 1, false);
                        h++;
                      }
                      else
                        h = hmax;
                    }
                  }
                }
              }
            }

            // Evaporate if we have a 1 mod with no nearby water
            if (false && liq.mod == 1) {
              if (is_dry(zone, x, y - 1) && is_dry(zone, x, y + 1) && is_dry(zone, x + 1, y) && is_dry(zone, x - 1, y)) {
                dint prev = DINT(rb_hash_aref(reserves, NUM(liq.item)));
                rb_hash_aset(reserves, NUM(liq.item), NUM(prev + liq.mod));

                block_update(zone, x, y, LIQUID, 0, 0, 0, true);
                mod = 0;
              }
            }

            if (mod > 0)
              index_liquid(liquid, x, y);
          }
        }
      }
    }

    //printf("Reindexed liquid blocks: %d\n", liquid->blocks_count);
    xfree(old_liquid_blocks);
  }

  liquid->steps++;

  // Occasionally reindex entire map
  /*if (liquid->steps % 40 == 39) {
    free(liquid->blocks);
    index_all_liquids(liquid);
  }*/

  return Qnil;
}

static dint liquid_transfer(Liquid *liquid, dint item, dint mod, dint source_x, dint source_y, dint dest_x, dint dest_y, dbool vertical, dint minDiff, dbool allowDiagonal) {
  if (VERBOSE > 1) printf("liquid_transfer\n");

  Zone *zone = liquid->zone;

  // Do nothin if we're out of bounds
  if (!in_bounds(zone, dest_x, dest_y)) return mod;

  dint dest_mod, xfer = 0;

  Layer dest_liq = block_peek(zone, dest_x, dest_y, LIQUID);
  Layer dest_front = block_peek(zone, dest_x, dest_y, FRONT);

  if (dest_liq.item > 0 || (dest_front.item == 0 || whole_item(zone, dest_front.item) == false)) {
    dest_mod = dest_liq.item == 0 ? 0 : dest_liq.mod;
    if (dest_mod >= LIQUID_LEVELS) return mod;

    // Transfer as many vertically as possible
    if (vertical) {
      xfer = min(LIQUID_LEVELS - dest_mod, mod);
      //xfer = dest_mod <= LIQUID_LEVELS - 2 && mod >= 2 ? 2 : 1;
    }

    // Horizontal
    else {
      // If destination block's liquid level is less than minimum difference from current block
      if (dest_mod < mod - minDiff) {
        xfer = 1;
      }
      // Else if the block beneath the destination block is open
      else if (allowDiagonal && in_bounds(zone, dest_x, dest_y + 1)) {
        Layer dest_bottom_liq = block_peek(zone, dest_x, dest_y + 1, LIQUID);
        if ((dest_bottom_liq.item == 0 || dest_bottom_liq.mod < LIQUID_LEVELS) && !is_whole(zone, dest_x, dest_y + 1, false))
          xfer = 1;
      }
    }

    if (xfer > 0) {
      block_update(zone, dest_x, dest_y, LIQUID, item, dest_mod + xfer, 0, true);
      block_update(zone, source_x, source_y, LIQUID, mod - xfer == 0 ? 0 : item, mod - xfer, 0, true);
      //printf("%d,%d to %d,%d %d mods\n", source_x, source_y, dest_x, dest_y, xfer);
    }

    return mod - xfer;
  }

  return mod;
}