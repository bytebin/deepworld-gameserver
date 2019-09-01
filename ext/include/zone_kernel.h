#ifndef __ZONE_KERNEL__
#define __ZONE_KERNEL__

// Constants
#define VERBOSE       0

#define BASE          0
#define BACK          1
#define FRONT         2
#define LIQUID        3
#define LIGHT         4

#define BLOCK_SIZE    3
#define LIQUID_LEVELS 5
#define MAX_ITEM_ID   3000

#define DINT(num) (dint) NUM2INT(num)
#define NUM(num) INT2NUM((int)num)

// Typedefs
typedef char dbool;
typedef int32_t dint;

// Structs
typedef struct {
  dint x, y;
} Vector2;

typedef struct {
  dint first, second, third;
} Block;

typedef struct {
  dint *block_data;
} Chunk;

typedef struct {
  dint item, mod;
} Layer;

typedef struct Zone Zone;
typedef struct Liquid Liquid;
typedef struct Steam Steam;
typedef struct Light Light;
typedef struct Growth Growth;
typedef struct Item Item;
typedef struct Config Config;

struct Zone {
  Vector2 size;
  Vector2 chunk_size;
  Vector2 chunk_dimensions;
  dint chunk_count;
  dint data_length;
  Chunk *chunks;
  dbool *active_chunk_indexes;
  VALUE ruby_zone;
  Liquid *liquid;
  Steam *steam;
  Vector2 *adjacents;
  dint adjacents_count;
  Vector2 *blocked_adjacents;
  dbool *blocked;
  dint blocked_adjacents_count;
  Light *light;
  Config *config;
  VALUE chunk_buffer;
  dbool freed;
};

struct Liquid {
  Zone *zone;
  dint *blocks;
  dint blocks_count;
  dint max_blocks_count;
  dint steps;
  dbool freed;
};

struct Light {
  Zone *zone;
  dint *sunlight;
};

struct Growth {
  Zone *zone;
};

struct Steam {
  Zone *zone;
  dbool *recursed;
  dbool freed;
};

struct Item {
  dint code;
  dbool whole;
  dbool shelter;
  dbool tileable;
  dbool shape;
  dbool solid;
  dbool door;
  dbool door_switched;
  dbool earthy;
  dbool steam;
  dbool growth;
  dint toughness;
  Vector2 block_size;
};

struct Config {
  Item **items;
};

// Modules and classes
VALUE mZoneKernel;
VALUE cZone;
VALUE cLiquid;
VALUE cSteam;
VALUE cLight;
VALUE cGrowth;
VALUE cConfig;
VALUE cUtil;

static dbool whole_item(Zone *zone, dint item);
static dbool shelter_item(Zone *zone, dint item);
static dbool growth_item(Zone *zone, dint item);
static dbool in_bounds(Zone *zone, dint x, dint y);
static dbool is_whole(Zone *zone, dint x, dint y, dbool inspect_liquid);
static dint compact(dint *array, dint size);
static Layer block_peek(Zone *zone, dint x, dint y, dint layer);
//static dint surface_query(Zone *zone, dint x, VALUE base, dint front, dint liquid);
//static void cache_blocked_at(Zone *zone, dint x, dint y, dbool is_removal);
//static dint *surface_scan(Zone *zone, dint start_x, dint length, VALUE base, dint front, dint liquid);

#define max( a, b ) ( ((a) > (b)) ? (a) : (b) )
#define min( a, b ) ( ((a) < (b)) ? (a) : (b) )
#define sign( x ) ( (x > 0)? 1 : ((x < 0)? -1: 0) )

#define BLOCK_OWNER(idx, layer) (chunk.block_data[idx + layer] >> 21) & 2047
#define BASE_PEEK(idx) (Layer) { chunk.block_data[idx] & 0x0000000f, 0 }
#define BACK_PEEK(idx) (Layer) { chunk.block_data[idx + 1] & 0x0000ffff, (chunk.block_data[idx + 1] >> 16) & 31 }
#define FRONT_PEEK(idx) (Layer) { chunk.block_data[idx + 2] & 0x0000ffff, (chunk.block_data[idx + 2] >> 16) & 31 }
#define LIQUID_PEEK(idx) (Layer) { chunk.block_data[idx] >> 8 & 0x000000ff, (chunk.block_data[idx] >> 16) & 31 }

// #ifndef printf_array
//   #define printf_array( array, len ) \
//     printf("Array has %d elements: ", len); \
//     for (int i; i <= len; i++) { printf(" %d", array[i]); } \
//     printf("\n");
// #endif

#endif
