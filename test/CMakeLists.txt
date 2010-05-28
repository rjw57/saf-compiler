# Include Vala support.
include(ValaPrecompile)
include(ValaVersion)
find_package(PkgConfig)

# Check Vala is installed.
find_package(Vala)
ensure_vala_version("0.8.0" MINIMUM)

# Check GLib is installed
pkg_check_modules(GLIB REQUIRED glib-2.0)
add_definitions(${GLIB_CFLAGS} ${GLIB_CFLAGS_OTHER})
link_libraries(${GLIB_LIBRARIES})
link_directories(${GLIB_LIBRARY_DIRS})
include_directories(${GLIB_INCLUDE_DIRS})

# Check GObject is installed
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
add_definitions(${GOBJECT_CFLAGS} ${GOBJECT_CFLAGS_OTHER})
link_libraries(${GOBJECT_LIBRARIES})
link_directories(${GOBJECT_LIBRARY_DIRS})
include_directories(${GOBJECT_INCLUDE_DIRS})

# Check libxml is installed
pkg_check_modules(LIBXML REQUIRED libxml-2.0)
add_definitions(${LIBXML_CFLAGS} ${LIBXML_CFLAGS_OTHER})
link_libraries(${LIBXML_LIBRARIES})
link_directories(${LIBXML_LIBRARY_DIRS})
include_directories(${LIBXML_INCLUDE_DIRS})

# Check libgee is installed
pkg_check_modules(GEE REQUIRED gee-1.0)
add_definitions(${GEE_CFLAGS} ${GEE_CFLAGS_OTHER})
link_libraries(${GEE_LIBRARIES})
link_directories(${GEE_LIBRARY_DIRS})
include_directories(${GEE_INCLUDE_DIRS})

# Add the SAF include directories
include_directories(../saf)
link_libraries(saf)

vala_precompile(_test_tokeniser_vala_c_sources
	test_tokeniser.vala
CUSTOM_VAPIS
	../saf/saf.vapi
PACKAGES
	libxml-2.0
	gee-1.0
)

add_executable(test_tokeniser ${_test_tokeniser_vala_c_sources})
target_link_libraries(test_tokeniser)

vala_precompile(_test_parser_vala_c_sources
	test_parser.vala
CUSTOM_VAPIS
	../saf/saf.vapi
PACKAGES
	libxml-2.0
	gee-1.0
)

add_executable(test_parser ${_test_parser_vala_c_sources})
target_link_libraries(test_parser)

# vim:sw=4:ts=4:autoindent
