//http://rhg.rubyforge.org/
#include <ruby.h>
#include "include/configuration.hpp"
#include "lib/configuration.cpp"

extern "C" void Init_zone_kernel2() {
  // ZoneKernel module
  VALUE mZoneKernel = rb_define_module("ZoneKernel");

  // Configuration class
  VALUE cConfiguration = rb_define_class_under(mZoneKernel, "Configuration", rb_cObject);
  rb_define_alloc_func(cConfiguration, configuration_alloc);
  rb_define_method(cConfiguration, "initialize", (VALUE(*)(ANYARGS))configuration_init, 1);
}
