// |--------------integer 1-----------| |--------------integer 2-----------| |--------------integer 3-----------|
// |00000000 00000000 00000000 00000000 |00000000 00000000 00000000 00000000 |00000000 00000000 00000000 00000000
//              |mod| |liquid|     |ba| |identity    |mod| |back           | |identity    |mod| |front          |

static Zone *get_zone(VALUE self) {
  if (VERBOSE > 1) printf("get_zone\n");
  Zone *z;
  Data_Get_Struct(self, Zone, z);

  return z;
}

static void mark_zone(Zone *zone) {
  if (VERBOSE > 0) printf("mark_zone\n");
}

static void free_zone_objects(Zone *zone) {
  if (zone->freed != true) {
    // Free chunk data
    for (dint i=0; i < zone->chunk_count; i++) {
      xfree(zone->chunks[i].block_data);
    }

    // Free chunks
    xfree(zone->chunks);

    // Free maps
    xfree(zone->active_chunk_indexes);
    xfree(zone->adjacents);
    xfree(zone->blocked_adjacents);

    // Unregister the chunk buffer from the gc
    rb_gc_unregister_address(&(zone->chunk_buffer));

    zone->freed = true;
  }
}

// Free allocated memory
static void free_zone(Zone *zone) {
  free_zone_objects(zone);

  // Free the zone
  xfree(zone);
}

static VALUE free_zone_wrapper(VALUE self) {
  Zone *zone = get_zone(self);
  free_zone_objects(zone);

  return true;
}

static void in_bounds_validation(Zone *zone, dint x, dint y) {
  if (x < 0 || y < 0 || x >= zone->size.x || y >= zone->size.y) {
    rb_raise(rb_eIndexError, "Chunk index out of bounds (%dx%d is not within size %dx%d)", (int)x, (int)y, (int)zone->size.x, (int)zone->size.y);
  }
}

// Get the chunk index for an x and y coordinate
static dint chunk_index(Zone *zone, dint x, dint y) {
  if (VERBOSE > 1) printf("chunk_index\n");

  if (x < 0 || y < 0 || x >= zone->size.x || y >= zone->size.y)
    rb_raise(rb_eIndexError, "Chunk index out of bounds (%dx%d is not within size %dx%d)", (int)x, (int)y, (int)zone->size.x, (int)zone->size.y);

  return (dint) (floor(y / zone->chunk_size.y) * zone->chunk_dimensions.x + floor(x / zone->chunk_size.x));
}


// Get the block index within the chunk
static dint block_index(Zone *zone, dint x, dint y) {
  if (VERBOSE > 1) printf("block_index\n");

  if (x < 0 || y < 0 || x >= zone->size.x || y >= zone->size.y)
    rb_raise(rb_eIndexError, "Block coordinates out of bounds [%d,%d]", (int)x, (int)y);

  x = (dint) ((int)x % (int)zone->chunk_size.x);
  y = (dint) ((int)y % (int)zone->chunk_size.y);
  return (y * zone->chunk_size.x + x) * BLOCK_SIZE;
}


// Get the origin coordinates for a chunk
static Vector2 chunk_origin(Zone *zone, dint index) {
  if (VERBOSE > 1) printf("chunk_origin\n");

  if (index < 0 || index >= zone->chunk_count)
    rb_raise(rb_eIndexError, "Chunk origin out of bounds");

  Vector2 v = (Vector2) {(dint)((int)index % (int)zone->chunk_dimensions.x) * zone->chunk_size.x, ((dint) floor(index / zone->chunk_dimensions.x)) * zone->chunk_size.y};
  return v;
}

// Get a chunk for the block coordinate
static Chunk get_chunk(Zone *zone, dint x, dint y) {
  if (VERBOSE > 1) printf("get_chunk x:%d, y:%d\n", (int)x, (int)y);

  dint idx = chunk_index(zone, x, y); // Validates
  return zone->chunks[idx];
}

static Block get_block(Zone *zone, dint x, dint y) {
  if (VERBOSE > 1) printf("get_block: %d, %d\n", (int)x, (int)y);

  // Validate
  in_bounds_validation(zone, x, y);

  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates

  Block block;
  block.first = chunk.block_data[idx];
  block.second = chunk.block_data[idx + 1];
  block.third = chunk.block_data[idx + 2];

  return block;
}

static void queue_block_update_message(Zone *zone, dint x, dint y, dint layer, dint item, dint mod) {
  if (VERBOSE > 1) printf("queue_block_update_message\n");

  dint idx = chunk_index(zone, x, y); // Validates
  if (zone->active_chunk_indexes[idx] == true) {
    rb_funcall(zone->ruby_zone, rb_intern("queue_block_update"), 6, Qnil, NUM(x), NUM(y), NUM(layer), NUM(item), NUM(mod));
  }
}

static void block_update(Zone *zone, dint x, dint y, dint layer, dint item, dint mod, dint player_digest, dbool send_update_msg) {
  if (VERBOSE > 1) printf("block_update: x:%d, y:%d, layer:%d, item:%d, mod:%d\n", (int)x, (int)y, (int)layer, (int)item, (int)mod);

  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates

  if (send_update_msg == true) {
    queue_block_update_message(zone, x, y, layer, item, mod);
  }

  switch(layer) {
    case LIQUID: {
      Layer existing = block_peek(zone, x, y, layer);
      if (item == existing.item && mod == existing.mod)
        return;

      dint data = chunk.block_data[idx];

      // Index liquid
      if (item > 0 && mod > 0)
        index_liquid(zone->liquid, x, y);

      if (mod < 0)  { mod  = (data >> 16) & 31; }
      if (item < 0) { item = (data >> 8) & 255; }

      chunk.block_data[idx] = (data & 0x0000000f) | (item & 0x000000ff) << 8 | (mod & 31) << 16;

      break; }

    case BASE: {
        dint data = chunk.block_data[idx];

        chunk.block_data[idx] = (data & 0xfffffff0) | (item & 0x0000000f);
        break;
      }

    case BACK:
    case FRONT: {
      dint data = chunk.block_data[idx + layer];

      if (item < 0)       { player_digest  = (data >> 21) & 2047;
                            item           = data & 65534;
      }
      else if (item == 0) { player_digest  = 0; }
      if (mod < 0)        { mod            = (data >> 16) & 31; }

      chunk.block_data[idx + layer] = (item & 0x0000ffff) | (player_digest & 2047) << 21 | (mod & 31) << 16;

      break;
    }

    default :
      rb_raise(rb_eArgError, "Layer index not recognized");
  }
}

static dint block_owner(Zone *zone, dint x, dint y, dint layer) {
  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates
  return BLOCK_OWNER(idx, layer);
}

static Layer base_peek(Zone *zone, dint x, dint y) {
  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates
  return BASE_PEEK(idx);
}

static Layer back_peek(Zone *zone, dint x, dint y) {
  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates
  return BACK_PEEK(idx);
}

static Layer front_peek(Zone *zone, dint x, dint y) {
  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates
  return FRONT_PEEK(idx);
}

static Layer liquid_peek(Zone *zone, dint x, dint y) {
  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates
  return LIQUID_PEEK(idx);
}

static Layer block_peek(Zone *zone, dint x, dint y, dint layer) {
  if (VERBOSE > 1) printf("block_peek: x:%d, y:%d, layer:%d\n", (int)x, (int)y, (int)layer);

  in_bounds_validation(zone, x, y);

  switch(layer) {
    case BASE:
      return base_peek(zone, x, y);
    case BACK:
      return back_peek(zone, x, y);
    case FRONT:
      return front_peek(zone, x, y);
    case LIQUID:
      return liquid_peek(zone, x, y);
    default :
      rb_raise(rb_eArgError, "Layer index not recognized");
  }
}

static VALUE all_peek(Zone *zone, dint x, dint y) {
  Chunk chunk = get_chunk(zone, x, y); // Validates
  dint idx = block_index(zone, x, y); // Validates

  Layer base = BASE_PEEK(idx);
  Layer back = BACK_PEEK(idx);
  Layer front = FRONT_PEEK(idx);
  Layer liquid = LIQUID_PEEK(idx);

  VALUE ary = rb_ary_new2(7);
  rb_ary_store(ary, 0, NUM(base.item));
  rb_ary_store(ary, 1, NUM(back.item));
  rb_ary_store(ary, 2, NUM(back.mod));
  rb_ary_store(ary, 3, NUM(front.item));
  rb_ary_store(ary, 4, NUM(front.mod));
  rb_ary_store(ary, 5, NUM(liquid.item));
  rb_ary_store(ary, 6, NUM(liquid.mod));
  return ary;
}

static VALUE all_peek_wrapper(VALUE self, VALUE x, VALUE y) {
  Zone *zone = get_zone(self);

  dint _x = DINT(x);
  dint _y = DINT(y);

  return all_peek(zone, _x, _y);
}

static dbool whole_item(Zone *zone, dint item) {
  return zone->config->items[item]->whole;
}

static dbool shelter_item(Zone *zone, dint item) {
  return zone->config->items[item]->shelter;
}

static dbool growth_item(Zone *zone, dint item) {
  return zone->config->items[item]->growth;
}

static dbool is_shelter(Zone *zone, dint x, dint y, dbool inspect_liquid) {
  if (!in_bounds(zone, x, y)) return true;

  Layer check = block_peek(zone, x, y, FRONT);

  if (check.item == 0) return false;
  if (whole_item(zone, check.item)) return true;
  if (shelter_item(zone, check.item)) return true;

  if (inspect_liquid) {
    check = block_peek(zone, x, y, LIQUID);
    if (check.item > 0 && check.mod > 0) return true;
  }

  return false;
}

static dbool is_whole(Zone *zone, dint x, dint y, dbool inspect_liquid) {
  if (!in_bounds(zone, x, y)) return true;

  Layer check = block_peek(zone, x, y, FRONT);

  if (check.item == 0) return false;
  if (whole_item(zone, check.item)) return true;

  if (inspect_liquid) {
    check = block_peek(zone, x, y, LIQUID);
    if (check.item > 0 && check.mod > 0) return true;
  }

  return false;
}

static dbool in_bounds(Zone *zone, dint x, dint y) {
  if (VERBOSE > 1) printf("in_bounds: %d, %d\n", (int)x, (int)y);

  return x >= 0 && x < zone->size.x && y >= 0 && y < zone->size.y;
}

/* ------------------ Wrapper methods ------------------ */
static VALUE BLOCK2VAL(Block block) {
  if (VERBOSE > 1) printf("BLOCK2VAL\n");

  VALUE block_data = rb_ary_new2(BLOCK_SIZE);
  rb_ary_store(block_data, 0, NUM(block.first));
  rb_ary_store(block_data, 1, NUM(block.second));
  rb_ary_store(block_data, 2, NUM(block.third));

  return block_data;
}

static VALUE LAYER2VAL(Layer layer) {
  if (VERBOSE > 1) printf("LAYER2VAL\n");

  VALUE layer_data = rb_ary_new2(2);
  rb_ary_store(layer_data, 0, NUM(layer.item));
  rb_ary_store(layer_data, 1, NUM(layer.mod));

  return layer_data;
}

static VALUE get_block_wrapper(VALUE self, VALUE x, VALUE y) {
  if (VERBOSE > 1) printf("get_block_wrapper\n");

  dint _x = DINT(x);
  dint _y = DINT(y);

  return BLOCK2VAL(get_block(get_zone(self), _x, _y));
}

static VALUE initialize_chunk_buffer(dint chunk_count, dint data_length) {
  VALUE chunk_buffer = rb_ary_new2(chunk_count);

  for (dint i=0; i < chunk_count; i++) {
    rb_ary_store(chunk_buffer, i, rb_ary_new2(data_length));
  }

  return chunk_buffer;
}

// Get an ruby array representing the chunk at chunk_index
static VALUE get_chunk_wrapper(VALUE self, VALUE chunk_index, VALUE hide_owner) {
  dbool _hide_owner = (hide_owner == Qtrue);

  Zone *zone = get_zone(self);

  // Validate
  dint idx = DINT(chunk_index);
  if (idx < 0 || idx >= zone->chunk_count) rb_raise(rb_eIndexError, "Chunk index out of bounds (wrapper)");

  Chunk source = zone->chunks[idx];
  VALUE chunk = rb_ary_entry(zone->chunk_buffer, idx);

  if (_hide_owner) {
    for (dint i=0; i < zone->data_length; i++) { rb_ary_store(chunk, i, NUM(source.block_data[i] & (dint)2097151)); }
  }
  else {
    for (dint i=0; i < zone->data_length; i++) { rb_ary_store(chunk, i, NUM(source.block_data[i])); }
  }

  return chunk;
}

// Get a ruby array containing chunk arrays
static VALUE get_chunks_wrapper(VALUE self, VALUE hide_owner) {
  if (VERBOSE > 1) printf("get_chunks\n");
  Zone *zone = get_zone(self);

  for (dint i=0; i < zone->chunk_count; i++) {
    get_chunk_wrapper(self, NUM(i), hide_owner);
  }

  return zone->chunk_buffer;
}

static VALUE get_chunk_data_wrapper(VALUE self, VALUE chunk_indexes) {
  Zone *zone = get_zone(self);

  // Initialize msgpack
  msgpack_sbuffer* buffer = msgpack_sbuffer_new();
  msgpack_packer* pk = msgpack_packer_new(buffer, msgpack_sbuffer_write);

  unsigned int num_chunks = (unsigned int) RARRAY_LEN(chunk_indexes);

  // Loop through chunks and pack data
  msgpack_pack_array(pk, num_chunks);

  for (dint ch = 0; ch < (dint) num_chunks; ch++) {
    dint idx = DINT(rb_ary_entry(chunk_indexes, ch));
    if (idx < 0 || idx >= zone->chunk_count) rb_raise(rb_eIndexError, "Chunk index out of bounds (wrapper)");

    Chunk chunk = zone->chunks[idx];
    dint x = idx % zone->chunk_dimensions.x * zone->chunk_size.x;
    dint y = idx / zone->chunk_dimensions.x * zone->chunk_size.y;
    unsigned int len = (unsigned int) (zone->chunk_size.x * zone->chunk_size.y * BLOCK_SIZE);

    // Chunk origin/size
    msgpack_pack_array(pk, 5);
    msgpack_pack_int32(pk, x);
    msgpack_pack_int32(pk, y);
    msgpack_pack_int32(pk, zone->chunk_size.x);
    msgpack_pack_int32(pk, zone->chunk_size.y);

    // Block data
    msgpack_pack_array(pk, len);
    for (dint i = 0; i < (dint) len; i++)
      msgpack_pack_int32(pk, chunk.block_data[i]);
  }

  VALUE packed = rb_str_new(buffer->data, buffer->size);

  // Clear msgpack
  msgpack_sbuffer_free(buffer);
  msgpack_packer_free(pk);

  return packed;
}

static VALUE chopped_chunks_data_wrapper(VALUE self, VALUE _from_x, VALUE _from_y, VALUE _width, VALUE _height) {
  // Convert to dints
  dint from_x = DINT(_from_x);
  dint from_y = DINT(_from_y);
  dint width = DINT(_width);
  dint height = DINT(_height);
  Zone *zone = get_zone(self);

  //printf("from x %d from y %d width %d height %d", (int)from_x, (int)from_y, (int)width, (int)height );

  // Protect from bad size
  if (width % zone->chunk_size.x > 0 || height % zone->chunk_size.y > 0)
    rb_raise(rb_eArgError, "Size request of %dx%d is not multiples of %dx%d chunks.", (int)width, (int)height, (int)zone->chunk_size.x, (int)zone->chunk_size.y);

  if (from_x + width > zone->size.x || from_y + height > zone->size.y)
    rb_raise(rb_eArgError, "Size requested falls outside of the zone bounds %dx%d, starting at %d,%d.", (int)width, (int)height, (int)from_x, (int)from_y);


  dint chunk_width = (dint)ceil(width / zone->chunk_size.x);
  dint chunk_height = (dint)ceil(height / zone->chunk_size.y);

  //printf("chunk_width %d chunk_height %d", (int)chunk_width, (int)chunk_height);

  VALUE data = rb_ary_new2(chunk_width * chunk_height);

  for (dint h = 0; h < chunk_height; h++) {
    for (dint w = 0; w < chunk_width; w++) {

      // Initialize and fill the chunk data
      VALUE chunk_data = rb_ary_new2(zone->chunk_size.x * zone->chunk_size.y);

      for (dint y = 0; y < zone->chunk_size.y; y++) {
        for (dint x = 0; x < zone->chunk_size.x; x++) {
          dint new_y = h * zone->chunk_size.y + y;
          dint new_x = w * zone->chunk_size.x + x;
          //printf("new_y %d\n", (int)new_y);
          //printf("new_x %d\n", (int)new_x);

          dint prev_y = from_y + new_y;
          dint prev_x = from_x + new_x;
          //printf("prev_x %d\n", (int)prev_x);
          //printf("prev_y %d\n", (int)prev_y);

          dint prev_index = block_index(zone, prev_x, prev_y);
          Chunk chunk = get_chunk(zone, prev_x, prev_y);

          dint new_index = block_index(zone, new_x, new_y);

          for (dint i = 0; i < BLOCK_SIZE; i++) {
            rb_ary_store(chunk_data, new_index + i, NUM(chunk.block_data[prev_index + i] & (dint)2097151));
          }
        }
      }

      rb_ary_store(data, h * chunk_width + w, chunk_data);
    }
  }

  return data;
}

static VALUE block_update_wrapper(VALUE self, VALUE x, VALUE y, VALUE layer, VALUE item, VALUE mod, VALUE player_digest) {
  Zone *zone = get_zone(self);
  if (zone->freed == true) {
    return Qnil;
  }

  dint _x = DINT(x);
  dint _y = DINT(y);
  dint _layer = DINT(layer);
  dint _item = TYPE(item) == T_NIL ? -1 : DINT(item);
  dint _mod = TYPE(mod) == T_NIL ? -1 : DINT(mod);
  dint _player_digest = TYPE(player_digest) == T_NIL ? 0 : DINT(player_digest);

  block_update(zone, _x, _y, _layer, _item, _mod, _player_digest, false);
  return Qnil;
}

static VALUE block_peek_wrapper(VALUE self, VALUE x, VALUE y, VALUE layer) {
  Zone *zone = get_zone(self);
  if (zone->freed == true) {
    return LAYER2VAL((Layer){ 0, 0});
  }

  dint _x = DINT(x);
  dint _y = DINT(y);
  dint _layer = DINT(layer);

  return LAYER2VAL(block_peek(zone, _x, _y, _layer));
}

static VALUE block_owner_wrapper(VALUE self, VALUE x, VALUE y, VALUE layer) {
  Zone *zone = get_zone(self);
  if (zone->freed == true) {
    return NUM(0);
  }

  dint _x = DINT(x);
  dint _y = DINT(y);
  dint _layer = DINT(layer);

  return NUM(block_owner(zone, _x, _y, _layer));
}

static VALUE clear_owners_wrapper(VALUE self) {
  Zone *zone = get_zone(self);

  for (dint x = 0; x < zone->size.x; x++) {
    for (dint y = 0; y < zone->size.y; y++) {
      Chunk chunk = get_chunk(zone, x, y); // Validates
      dint idx = block_index(zone, x, y); // Validates

      chunk.block_data[idx + BACK]  = chunk.block_data[idx + BACK] & (dint)2097151;
      chunk.block_data[idx + FRONT] = chunk.block_data[idx + FRONT] & (dint)2097151;
    }
  }

  return Qtrue;
}

static VALUE item_counts_wrapper(VALUE self) {
  Zone *zone = get_zone(self);
  VALUE back, front, prev;
  VALUE zero = NUM(0);

  VALUE items = rb_hash_new();

  for (dint y = 0; y < zone->size.y; y++) {
    for (dint x = 0; x < zone->size.x; x++) {

      // Get the front
      front = NUM(front_peek(zone, x, y).item);
      if (front != zero) {
        prev = rb_hash_aref(items, front);
        rb_hash_aset(items, front, (prev == Qnil ? NUM(1) : NUM(DINT(prev) + 1)));
      }

      // Get the back
      back = NUM(back_peek(zone, x, y).item);
      if (back != zero) {
        prev = rb_hash_aref(items, back);
        rb_hash_aset(items, back, (prev == Qnil ? NUM(1) : NUM(DINT(prev) + 1)));
      }
    }
  }

  return items;
}

/*
static dint surface_query(Zone *zone, dint x, VALUE base, dint front, dint liquid) {
  if (VERBOSE > 1) printf("surface_query\n");

  if (x < 0 || x > zone->size.x - 1)
    rb_raise(rb_eArgError, "Surface query x argument is out of zone bounds.");

  for (dint y = 0; y < zone->size.y; y++) {
    dbool match = true;
    dint item;

    // Base (true or false is underground query, otherwise match item)
    if (base != Qnil) {
      item = base_peek(zone, x, y).item;

      if (base == Qtrue) {
        match = match && (item > 0);
      }
      else if (base == Qfalse) {
        match = match && (item <= 0);
      }
      else {
        match = match && (item == DINT(base));
      }
    }

    // Front
    if (front >= 0) {
      item = front_peek(zone, x, y).item;

      if (item == 0) {
        match = false;
      }
      else {
        match = match && (item == front);
      }
    }

    // Liquid
    if (liquid >= 0) {
      item = liquid_peek(zone, x, y).item;

      if (item == 0) {
        match = false;
      }
      else {
        match = match && (item == liquid);
      }
    }

    if (match) return y;
  }

  return -1;
}
*/

// // NOTE: this allocates a results array that needs to be freed
// static dint *surface_scan(Zone *zone, dint start_x, dint length, VALUE base, dint front, dint liquid) {
//   if (VERBOSE > 1) printf("surface_scan\n");

//   if (start_x < 0 || start_x > zone->size.x - 1 || length < 0 || start_x + length - 1 > zone->size.x)
//     rb_raise(rb_eArgError, "Surface query arguments are out of zone bounds.");

//   // Allocate the results
//   dint *results = ALLOC_N(dint, length);

//   for(dint x = start_x; x < start_x + length; x++) {
//     results[x] = surface_query(zone, x, base, front, liquid);
//   }

//   return results;
// }

static VALUE block_query_wrapper(VALUE self, VALUE chunk_index, VALUE base, VALUE back, VALUE front, VALUE liquid) {
  if (VERBOSE > 1) printf("block_query_wrapper\n");

  Zone *zone = get_zone(self);

  Vector2 origin;
  Vector2 destination;

  if (chunk_index == Qnil) {
    origin = (Vector2) { 0, 0 };
    destination = zone->size;
  }
  else {
    origin = chunk_origin(zone, DINT(chunk_index));
    destination = (Vector2) { origin.x + zone->chunk_size.x, origin.y + zone->chunk_size.y };
  }

  VALUE locations = rb_ary_new();

  // Query and load up the array
  for (dint x = origin.x; x < destination.x; x++) {
    for (dint y = origin.y; y < destination.y; y++) {
      dbool match = true;

      // Base (true or false is underground query, otherwise match item)
      if (match && base != Qnil) {
        if (base == Qtrue) {
          match = match && (block_peek(zone, x, y, BASE).item > 0);
        }
        else if (base == Qfalse) {
          match = match && (block_peek(zone, x, y, BASE).item <= 0);
        }
        else {
          match = match && (block_peek(zone, x, y, BASE).item == DINT(base));
        }
      }

      // Back
      if (match && back != Qnil) {
        match = match && (block_peek(zone, x, y, BACK).item == DINT(back));
      }

      // Front
      if (match && front != Qnil) {
        match = match && (block_peek(zone, x, y, FRONT).item == DINT(front));
      }

      // Liquid
      if (match && liquid != Qnil) {
        match = match && (block_peek(zone, x, y, LIQUID).item == DINT(liquid));
      }

      if (match) {
        VALUE coord = rb_ary_new2(2);
        rb_ary_store(coord, 0, NUM(x));
        rb_ary_store(coord, 1, NUM(y));
        rb_ary_push(locations, coord);
      }
    }
  }

  return locations;
}

/// Find blocks of a specific front item that have beneath them another specific front item
static VALUE below_query_wrapper(VALUE self, VALUE chunk_index, VALUE underground, VALUE front, VALUE below_front) {
  if (VERBOSE > 1) printf("below_query_wrapper\n");

  Zone *zone = get_zone(self);
  VALUE matches = block_query_wrapper(self, chunk_index, underground, Qnil, front, Qnil);

  dint below_front_code = DINT(below_front);

  VALUE locations = rb_ary_new();

  for (dint b = 0; b < RARRAY_LEN(matches); b++) {
    VALUE match = rb_ary_entry(matches, b);
    dint x = DINT(rb_ary_entry(match, 0));
    dint y = DINT(rb_ary_entry(match, 1));
    dint y_ = y + 1;

    if (in_bounds(zone, x, y_)) {
      Layer match_front = front_peek(zone, x, y_);
      if (match_front.item == below_front_code)
        rb_ary_push(locations, match);
    }
  }

  return locations;
}



#define EARTHY_SURROUND_MIN 5
static VALUE earthy_query_wrapper(VALUE self, VALUE chunk_index, VALUE base, VALUE front, VALUE underground) {
  if (VERBOSE > 1) printf("earth_query_wrapper\n");

  Zone *zone = get_zone(self);
  VALUE matches = block_query_wrapper(self, chunk_index, base, underground ? NUM(0) : Qnil, front, Qnil);

  VALUE locations = rb_ary_new();

  for (dint b = 0; b < RARRAY_LEN(matches); b++) {
    dint surround_count = 0;

    VALUE match = rb_ary_entry(matches, b);
    dint x = DINT(rb_ary_entry(match, 0));
    dint y = DINT(rb_ary_entry(match, 1));

    Layer front;
    Item *item;
    surround_count = 0;

    // Only check surrounding blocks if underground query or if we're aboveground and have nothing undernearth us (so we can drop the block)
    if (underground == Qtrue || (in_bounds(zone, x, y + 1) && front_peek(zone, x, y + 1).item == 0)) {

      for (int i = 0; i < zone->adjacents_count; i++) {
        int x_ = x + zone->adjacents[i].x;
        int y_ = y + zone->adjacents[i].y;

        if (in_bounds(zone, x_, y_) ) {
          front = front_peek(zone, x_, y_);
          item = zone->config->items[front.item];
          if (item->earthy) {
            surround_count++;
            if (underground == Qtrue && surround_count >= EARTHY_SURROUND_MIN) {
              // Don't need to check any more
              break;
            }
          }
        }
      }

      if ((underground == Qtrue && surround_count >= EARTHY_SURROUND_MIN) || (underground == Qfalse && surround_count < 3))
        rb_ary_push(locations, match);
    }
  }

  return locations;
}


static VALUE raycast_wrapper(VALUE self, VALUE xa_, VALUE ya_, VALUE xb_, VALUE yb_, VALUE path_, VALUE liquid_, VALUE all_, VALUE next_, VALUE items_) {
  if (xa_ == Qnil || ya_ == Qnil || xb_ == Qnil || yb_ == Qnil)
    rb_raise(rb_eArgError, "Raypath values must be fixnums");

  Zone *zone = get_zone(self);

  dint xa = DINT(xa_);
  dint ya = DINT(ya_);
  dint xb = DINT(xb_);
  dint yb = DINT(yb_);

  dbool path = (path_ == Qtrue);
  dbool liquid = (liquid_ == Qtrue);
  dbool all = (all_ == Qtrue);
  dbool next = (next_ == Qtrue);
  dbool include_items = (items_ == Qtrue);

  if (!in_bounds(zone, xa, ya)) rb_raise(rb_eArgError, "Origin must be in bounds");

  VALUE coords = Qnil;
  if (path) { coords = rb_ary_new(); }

  // http://www.cs.umd.edu/class/fall2003/cmsc427/bresenham.html
  dint x = xa;
  dint y = ya;
  dint dx = (dint) abs((int)xb - (int)xa);
  dint dy = (dint) abs((int)yb - (int)ya);
  dint s1 = (dint) sign((int)xb - (int)xa);
  dint s2 = (dint) sign((int)yb - (int)ya);
  dint swap = 0;
  dint coord_size = include_items ? 3 : 2;

  if (dy > dx) {
    dint temp = dx;
    dx = dy;
    dy = temp;
    swap = 1;
  }

  dint D = 2*dy - dx;

  for (dint i = 0; i < dx; i++) {
    if (!all && is_shelter(zone, x, y, liquid)) {
      if (path) return coords;

      VALUE coord = rb_ary_new2(coord_size);
      rb_ary_store(coord, 0, NUM(x));
      rb_ary_store(coord, 1, NUM(y));
      if (include_items)
        rb_ary_store(coord, 2, all_peek(zone, x, y));
      return coord;
    }

    if (path) {
      VALUE coord = rb_ary_new2(coord_size);
      rb_ary_store(coord, 0, NUM(x));
      rb_ary_store(coord, 1, NUM(y));
      if (include_items)
        rb_ary_store(coord, 2, all_peek(zone, x, y));
      rb_ary_push(coords, coord);

      if (next && i == 1) return coords;
    }

    while (D >= 0) {
      D = D - 2*dx;

      if (swap) {
        x += s1;
      }
      else {
        y += s2;
      }
    }

    D = D + 2*dy;

    if (swap) {
      y += s2;
    }
    else {
      x += s1;
    }
  }

  return all ? coords : Qnil;
}

/* ------------------ Initializers --------------------- */

// Initialize the chunk data
static Chunk *initialize_chunks(VALUE chunk_data, dint chunk_count, dint data_length) {
  if (VERBOSE > 0) printf("initialize_chunks\n");

  Chunk *chunks = ALLOC_N(Chunk, chunk_count);

  for(dint i=0; i < chunk_count; i++) {
    Chunk chunk;
    chunk.block_data = ALLOC_N(dint, data_length);

    for(dint j=0; j < data_length; j++) {
      chunk.block_data[j] = DINT(rb_ary_entry(rb_ary_entry(chunk_data, i), j));
    }
    chunks[i] = chunk;
  }

  return chunks;
}

static VALUE zone_alloc(VALUE klass) {
  if (VERBOSE > 0) printf("zone_alloc\n");

  Zone *zone = ALLOC(Zone);
  zone->freed = false;
  return Data_Wrap_Struct(klass, mark_zone, free_zone, zone);
}

static VALUE zone_step(VALUE self, VALUE active_chunks) {
  if (VERBOSE > 1) printf("zone_step\n");
  Zone *zone = get_zone(self);

  // Set active chunks
  memset(zone->active_chunk_indexes, '\0', zone->chunk_count);

  for (dint i=0; i < RARRAY_LEN(active_chunks); i++) {
    dint chunk_index = DINT(rb_ary_entry(active_chunks, i));

    if (chunk_index < 0 || chunk_index >= zone->chunk_count)
      rb_raise(rb_eIndexError, "Active chunk index out of bounds");

    zone->active_chunk_indexes[chunk_index] = true;
  }

  return Qnil;
}

// Zone initialize
static VALUE zone_init(VALUE self, VALUE ruby_zone, VALUE zone_width, VALUE zone_height, VALUE chunk_width, VALUE chunk_height, VALUE chunk_data, VALUE kernel_config) {
  if (VERBOSE > 0) printf("zone_init\n");

  Zone *zone = get_zone(self);
  Config *config = get_config(kernel_config);

  zone->ruby_zone = ruby_zone;
  zone->size = (Vector2) { DINT(zone_width), DINT(zone_height) };
  zone->chunk_size = (Vector2) { DINT(chunk_width), DINT(chunk_height) };
  zone->chunk_dimensions = (Vector2) { (dint)ceil(zone->size.x / zone->chunk_size.x), (dint)ceil(zone->size.y / zone->chunk_size.y) };
  zone->chunk_count = (dint) RARRAY_LEN(chunk_data);
  zone->data_length = zone->chunk_size.x * zone->chunk_size.y * BLOCK_SIZE;
  zone->chunks = initialize_chunks(chunk_data, zone->chunk_count, zone->data_length);

  zone->chunk_buffer = initialize_chunk_buffer(zone->chunk_count, zone->data_length);
  rb_gc_register_address(&(zone->chunk_buffer));

  // Adjacent blocks for immediate checks
  zone->adjacents_count = 8;
  zone->adjacents = ALLOC_N(Vector2, zone->adjacents_count);
  zone->adjacents[0] = (Vector2){-1, -1};
  zone->adjacents[1] = (Vector2){0, -1};
  zone->adjacents[2] = (Vector2){0, -1};
  zone->adjacents[3] = (Vector2){-1, 0};
  zone->adjacents[4] = (Vector2){1, 0};
  zone->adjacents[5] = (Vector2){-1, 1};
  zone->adjacents[6] = (Vector2){0, 1};
  zone->adjacents[7] = (Vector2){1, 1};

  // Adjacent block check for is_blocked
  zone->blocked_adjacents_count = 12;
  zone->blocked_adjacents = ALLOC_N(Vector2, zone->blocked_adjacents_count);
  zone->blocked_adjacents[0] = (Vector2){0, 0};
  zone->blocked_adjacents[1] = (Vector2){0, 1};
  zone->blocked_adjacents[2] = (Vector2){0, 2};
  zone->blocked_adjacents[3] = (Vector2){-1, 0};
  zone->blocked_adjacents[4] = (Vector2){-1, 1};
  zone->blocked_adjacents[5] = (Vector2){-1, 2};
  zone->blocked_adjacents[6] = (Vector2){-2, 0};
  zone->blocked_adjacents[7] = (Vector2){-2, 1};
  zone->blocked_adjacents[8] = (Vector2){-2, 2};
  zone->blocked_adjacents[9] = (Vector2){-3, 0};
  zone->blocked_adjacents[10] = (Vector2){-3, 1};
  zone->blocked_adjacents[11] = (Vector2){-3, 2};

  zone->active_chunk_indexes = ALLOC_N(dbool, zone->chunk_count);
  memset(zone->active_chunk_indexes, '\0', zone->chunk_count);

  // Configuration
  zone->config = config;

  return self;
}

/*static VALUE cache_blocked_wrapper(VALUE self) {
  Zone *zone = get_zone(self);
  zone->blocked =  ALLOC_N(dbool, zone->size.x * zone->size.y);
  for (dint x = 0; x < zone->size.x; x++) {
    for (dint y = 0; y < zone->size.y; y++) {
      cache_blocked_at(zone, x, y, false);
    }
  }

  return Qtrue;
}
*/

/*static void cache_blocked_at(Zone *zone, dint x, dint y, dbool is_removal) {
  if (is_removal) {

  }
  else {
    //if (item->shape && )
  }
}
*/


static dbool is_blocked(Zone *zone, dint origin_x, dint origin_y, dint x, dint y, dint type) {
  if (zone) {
    x += origin_x;
    y += origin_y;

    // Out of bounds
    if (!in_bounds(zone, x, y)) return true;

    // Optimization - common scenario
    Layer front = front_peek(zone, x, y);
    Item *item = zone->config->items[front.item];

    if (
      (type == 0 ? item->shape : item->solid) &&
      !((type == 0 ? item->door : item->door_switched) && front.mod % 2 == 1)
    )
      return true;

    for (int i = 0; i < zone->blocked_adjacents_count; i++) {
      int x_ = x + zone->blocked_adjacents[i].x;
      int y_ = y + zone->blocked_adjacents[i].y;

      if (in_bounds(zone, x_, y_) ) {
        front = front_peek(zone, x_, y_);
        item = zone->config->items[front.item];
        if (
          !item->tileable &&
          (type == 0 ? item->shape : item->solid) &&
          !((type == 0 ? item->door : item->door_switched) && front.mod % 2 == 1) &&
          item->block_size.x > abs(zone->blocked_adjacents[i].x) &&
          item->block_size.y > abs(zone->blocked_adjacents[i].y))
          return true;
      }
    }
  }
  return false;
}

static VALUE is_blocked_wrapper(VALUE self, VALUE origin_x_, VALUE origin_y_, VALUE x_, VALUE y_, VALUE type_) {
  Zone *zone = get_zone(self);
  if (zone) {
    dint origin_x = DINT(origin_x_);
    dint origin_y = DINT(origin_y_);
    dint x = DINT(x_);
    dint y = DINT(y_);
    dint type = DINT(type_);

    return is_blocked(zone, origin_x, origin_y, x, y, type) ? Qtrue : Qfalse;
  }
  return Qfalse;
}

static dint compact(dint *array, dint size) {
  dint i;
  dint last = 0;
  for (i = 1; i < size; i++)
  {
      if (array[i] != array[last])
          array[++last] = array[i];
  }
  return(last + 1);
}
