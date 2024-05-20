"""
extra CFFI definitions for wlroots, currently not upstreamed in pywlroots
"""

SOURCE = """
#include <wlr/types/wlr_output.h>
#include <wlr/types/wlr_output_layout.h>
"""

CDEF = """
struct wlr_output_layout_output *wlr_output_layout_get(
        struct wlr_output_layout *layout, struct wlr_output *reference);
"""
