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

# Check gtksourceview is installed
pkg_check_modules(GTKSOURCEVIEW gtksourceview-2.0)
add_definitions(${GTKSOURCEVIEW_CFLAGS} ${GTKSOURCEVIEW_CFLAGS_OTHER})
link_libraries(${GTKSOURCEVIEW_LIBRARIES})
link_directories(${GTKSOURCEVIEW_LIBRARY_DIRS})
include_directories(${GTKSOURCEVIEW_INCLUDE_DIRS})

# Check gtk is installed
pkg_check_modules(GTK gtk+-2.0)
add_definitions(${GTK_CFLAGS} ${GTK_CFLAGS_OTHER})
link_libraries(${GTK_LIBRARIES})
link_directories(${GTK_LIBRARY_DIRS})
include_directories(${GTK_INCLUDE_DIRS})

# Check libgee is installed
pkg_check_modules(GEE REQUIRED gee-1.0)
add_definitions(${GEE_CFLAGS} ${GEE_CFLAGS_OTHER})
link_libraries(${GEE_LIBRARIES})
link_directories(${GEE_LIBRARY_DIRS})
include_directories(${GEE_INCLUDE_DIRS})

# Check libvte is installed
pkg_check_modules(VTE REQUIRED vte)
add_definitions(${VTE_CFLAGS} ${VTE_CFLAGS_OTHER})
link_libraries(${VTE_LIBRARIES})
link_directories(${VTE_LIBRARY_DIRS})
include_directories(${VTE_INCLUDE_DIRS})

# Check cairo is installed
pkg_check_modules(CAIRO REQUIRED cairo)
add_definitions(${CAIRO_CFLAGS} ${CAIRO_CFLAGS_OTHER})
link_libraries(${CAIRO_LIBRARIES})
link_directories(${CAIRO_LIBRARY_DIRS})
include_directories(${CAIRO_INCLUDE_DIRS})

# Look for GNU readline
find_package(Readline REQUIRED)
include_directories(${READLINE_INCLUDE_DIR})
link_libraries(${READLINE_LIBRARY})

# Add the SAF include directories
include_directories(../saf)
link_libraries(saf)

# If we have GTK source view, compile the editor
if(GTKSOURCEVIEW_FOUND AND GTK_FOUND)
	vala_precompile(_saf_editor_c_sources
		editor_main.vala
		graphics.vala
		sourceview.vala
		sourcebuffer.vala
		sourcebuffersource.vala
		sourcebuffermonitor.vala
	CUSTOM_VAPIS
		../saf/saf.vapi
	PACKAGES
		cairo
		gtksourceview-2.0
		gee-1.0
		gtk+-2.0
		readline
		posix
		vte
	)

	add_executable(saf_editor ${_saf_editor_c_sources})
	target_link_libraries(saf_editor)
else(GTKSOURCEVIEW_FOUND AND GTK_FOUND)
	message(STATUS "!!! GtkSourceview was not found. The SAF editor will not be built.")
endif(GTKSOURCEVIEW_FOUND AND GTK_FOUND)

# vim:sw=4:ts=4:autoindent
