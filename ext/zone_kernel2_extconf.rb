require 'mkmf'

have_header('ruby.h')
have_library('stdc++')

$srcs = [
  'zone_kernel2.cpp'
]

create_makefile('zone_kernel2')
