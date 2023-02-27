# Copyright (c) 2008, Aldo Cortesi. All rights reserved.
# Copyright (c) 2017, Dirk Hartmann.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from libqtile.layout.base import _SimpleLayoutBase
from libqtile.ipc import find_sockfile
from libqtile.config import Match
import json
import subprocess


class Emacs(_SimpleLayoutBase):
    """Emacs layout

    A layout that displays emacs maximized and will fill the remaining clients in emacs' buffers.
    """

    def __init__(self, **config):
        _SimpleLayoutBase.__init__(self, **config)
        self.emacs = None
        self.pos = {}
        self.ignore_focus = False
        self.last_focus = None

    def is_emacs(self, client):
        return Match(wm_class = "Emacs").compare(client)

    def add_client(self, client):
        if len(self.clients) == 0:
            self.emacs_init()
        if self.is_emacs(client):
            self.emacs = client
        else:
            self.emacs_create_buffer(client)
            return super().add_client(client, 0, client_position="bottom")
        self.group.layout_all()

    def focus(self, client):
        if client is not self.emacs:
            if not self.ignore_focus:
                self.last_focus = self.clients.current_client
                self.emacs_switch_buffer(client)
            super().focus(client)
        else:
            self.group.layout_all()
        self.ignore_focus = False

    def remove(self, client):
        returned = None
        if not client is self.emacs:
            # We need this mess to check which kind of window we should focus
            buffer_res = self.emacs_close_buffer(client)
            if client is self.clients.current_client:
                buffer_res = buffer_res.decode().strip()
                returned = self.emacs
                if buffer_res != "nil":
                    for c in self.clients:
                        if str(c.wid) == buffer_res:
                            returned = c
            super().remove(client)
            return returned
            #if last is not None:# and str(last.wid) in self.pos:
            #    return last
            #else:
            #    return self.emacs
            #    self.group.focus(last)
        else:
            self.emacs = None

    def emacsclient_cmd(self, cmd):
        try:
            out = subprocess.check_output(["emacsclient", "-e", cmd], stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as exc:
            print(f"FAILED: {exc.cmd}")
            print(f"{exc.output}")
            return None
        return out

    def cmd_focus_emacs(self):
        print("FOCUS EMACS")
        if self.emacs is not None:
            self.group.focus(self.emacs)

    def cmd_emacs_close_window(self, wid):
        for client in self.clients:
            if str(client.wid) == wid:
                client.kill()

    def convert_emacs_edges(self, edges):
        return (
            int(edges[0]),
            int(edges[1]),
            int(edges[2]) - int(edges[0]),
            int(edges[3]) - int(edges[1]),
        )

    def buffer_name(self, client):
        return f"qtile - {client.name}"

    def emacs_init(self):
        socket = str(find_sockfile())
        self.emacsclient_cmd(f'(qtile--init "{socket}")')

    def cmd_emacs_remove_wid(self, wid):
        for client in self.clients:
            if client.wid == wid:
                client.kill()

    def cmd_emacs_focus_wid(self, wid):
        for client in self.clients:
            if client.wid == wid:
                self.ignore_focus = True
                self.group.focus(client)

    def cmd_emacs_refresh(self, wins):
        self.pos = json.loads(wins)
        self.group.layout_all()

    def emacs_close_buffer(self, client):
        return self.emacsclient_cmd(f"(qtile-close-buffer {client.wid})")

    def emacs_create_buffer(self, client):
        self.emacsclient_cmd(f'(qtile-create-buffer "{self.buffer_name(client)}" {client.wid})')

    def emacs_switch_buffer(self, client):
        self.emacsclient_cmd(f"(qtile-switch-buffer {client.wid})")

    def configure(self, client, screen_rect):
        if client is self.emacs:
            client.place(
                screen_rect.x, screen_rect.y, screen_rect.width, screen_rect.height, 0, None
            )
            client.unhide()
            return
        if str(client.wid) in self.pos:
            x, y, width, height = self.convert_emacs_edges(self.pos[str(client.wid)])
            client.place(x, y, width, height, 0, None)
            client.unhide()
        else:
            # For some reason this is needed
            client.place(
                0, 0, 1, 1, 0, None
            )
            client.hide()

    cmd_previous = _SimpleLayoutBase.previous
    cmd_next = _SimpleLayoutBase.next

    cmd_up = cmd_previous
    cmd_down = cmd_next
