from __future__ import annotations

from typing import TYPE_CHECKING

import cairocffi
from wlroots.util.region import PixmanRegion32

from libqtile.backend import base

if TYPE_CHECKING:
    from libqtile.backend.wayland.window import Internal
    from libqtile.core.manager import Qtile
    from libqtile.utils import ColorsType


class Drawer(base.Drawer):
    """
    A helper class for drawing and text layout.

    1. We stage drawing operations locally in memory using a cairo RecordingSurface.
    2. Then apply these operations to the windows's underlying ImageSurface.
    """

    def __init__(self, qtile: Qtile, win: Internal, width: int, height: int):
        base.Drawer.__init__(self, qtile, win, width, height)

    def _draw(
        self,
        offsetx: int = 0,
        offsety: int = 0,
        width: int | None = None,
        height: int | None = None,
    ) -> None:
        if offsetx > self._win.width:
            return

        # We need to set the current draw area so we can compare to the previous one
        self.current_rect = (offsetx, offsety, width, height)
        # rect_changed = current_rect != self.previous_rect

        if not self.needs_update:
            return

        # Keep track of latest rect covered by this drawwer
        self.previous_rect = self.current_rect

        # Make sure geometry doesn't extend beyond texture
        if width is None:
            width = self.width
        if width > self._win.width - offsetx:
            width = self._win.width - offsetx
        if height is None:
            height = self.height
        if height > self._win.height - offsety:
            height = self._win.height - offsety

        # Paint recorded operations to our window's underlying ImageSurface
        with cairocffi.Context(self._win.surface) as context:
            context.set_source_surface(self.surface, offsetx, offsety)
            context.rectangle(offsetx, offsety, width, height)
            context.fill()

        damage = PixmanRegion32()
        damage.init_rect(offsetx, offsety, width, height)  # type: ignore
        # TODO: do we really need to `set_buffer` here? would be good to just set damage
        self._win._scene_buffer.set_buffer_with_damage(self._win.wlr_buffer, damage)
        damage.fini()

    def clear(self, colour: ColorsType) -> None:
        # Draw background straight to ImageSurface
        ctx = cairocffi.Context(self.surface)
        ctx.save()
        ctx.set_operator(cairocffi.OPERATOR_SOURCE)
        self.set_source_rgb(colour, ctx=ctx)
        ctx.paint()
        ctx.restore()
