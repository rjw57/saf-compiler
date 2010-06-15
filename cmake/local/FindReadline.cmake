find_path(READLINE_INCLUDE_DIR readline/readline.h)
find_library(READLINE_LIBRARY NAMES readline) 

if(READLINE_INCLUDE_DIR AND READLINE_LIBRARY)
	set(READLINE_FOUND TRUE)
endif(READLINE_INCLUDE_DIR AND READLINE_LIBRARY)

if(READLINE_FOUND)
   if(NOT Readline_FIND_QUIETLY)
      message(STATUS "Found GNU readline: ${READLINE_LIBRARY}")
   endif(NOT Readline_FIND_QUIETLY)
else(READLINE_FOUND)
   if(Readline_FIND_REQUIRED)
      message(FATAL_ERROR "Could not find GNU readline")
   endif(Readline_FIND_REQUIRED)
endif(READLINE_FOUND)

# vim:sw=4:ts=4:autoindent
