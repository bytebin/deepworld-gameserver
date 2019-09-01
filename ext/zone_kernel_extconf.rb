require 'mkmf'

$CFLAGS += " -std=c99"

have_library('msgpack')

have_header('ruby.h')
have_header('math.h')

$srcs = [
  'zone_kernel.c'
]

create_makefile('zone_kernel')