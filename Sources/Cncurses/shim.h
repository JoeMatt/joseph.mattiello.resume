#ifndef CursesShim_h
#define CursesShim_h

// Explicitly define NCURSES_WIDECHAR to ensure wide-character support is enabled
// when ncurses.h is processed. This is to counteract SPM prohibiting the flag.
#define NCURSES_WIDECHAR 1

// Ensure ncurses.h is included. This should bring in ncursesw definitions
// when linking against ncursesw.
#include <ncurses.h>

// Explicitly include wchar.h to ensure all wide character types (like wchar_t)
// and related function prototypes are available to the Clang importer.
#include <wchar.h>

// For reference, if specific functions or types were still missing,
// you could try to declare them explicitly here, for example:
// 
// extern int mvwaddwstr(WINDOW *, int, int, const wchar_t *);
// extern int setcchar(cchar_t *, const wchar_t *, const attr_t, short, const void *);
// extern int wadd_wch(WINDOW *, const cchar_t *);
// extern int waddnwstr(WINDOW *, const wchar_t *, int);
// extern int mvwaddnwstr(WINDOW *, int, int, const wchar_t *, int);

#endif /* CursesShim_h */
