"""
GUI server that receives TCP messages from the Fairino robot Lua script and displays a popup.
When the user clicks [Continue] or [Stop], the result is sent back to the robot.
All popup messages are saved to a date-stamped log file in the 'log messages' folder next to this script.

Protocol:
  Lua -> server: "POPUP|title|body\n"
  server -> Lua: "CONTINUE\n" or "STOP\n"

Run: python3 gui_popup_server.py
"""

import socket
import threading
import queue
import tkinter as tk
from tkinter import font as tkfont
from datetime import datetime
import os

HOST = "0.0.0.0"
PORT = 9999

# Absolute path based on script location — works regardless of working directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_DIR    = os.path.join(SCRIPT_DIR, "log messages")

popup_queue = queue.Queue()


# ── Log saving ──────────────────────────────────────────────────
def save_log(title, body, action):
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        date_str = datetime.now().strftime("%Y-%m-%d")
        time_str = datetime.now().strftime("%H:%M:%S")
        log_path = os.path.join(LOG_DIR, f"{date_str}.txt")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{time_str}] [{action}] {title}: {body}\n")
    except Exception as e:
        print(f"[Log error] {e}")


# ── Custom popup dialog ──────────────────────────────────────────
class PopupDialog(tk.Toplevel):
    def __init__(self, parent, title, body):
        super().__init__(parent)
        self.result = "CONTINUE"
        self.title(title)
        self.resizable(False, False)
        self.grab_set()

        bold   = tkfont.Font(weight="bold", size=11)
        normal = tkfont.Font(size=10)

        tk.Label(self, text=title, font=bold, pady=8).pack(padx=20)
        tk.Label(self, text=body, font=normal, wraplength=300,
                 justify="left").pack(padx=20, pady=(0, 16))

        btn_frame = tk.Frame(self)
        btn_frame.pack(pady=(0, 12))
        tk.Button(btn_frame, text="Continue", width=10, bg="#4CAF50", fg="white",
                  font=bold, command=self._continue).pack(side="left", padx=8)
        tk.Button(btn_frame, text="Stop", width=10, bg="#f44336", fg="white",
                  font=bold, command=self._stop).pack(side="left", padx=8)

        self.protocol("WM_DELETE_WINDOW", self._continue)  # closing window = continue
        self.update_idletasks()
        self._center()
        self.wait_window()

    def _center(self):
        w, h = self.winfo_width(), self.winfo_height()
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        self.geometry(f"+{(sw-w)//2}+{(sh-h)//2}")

    def _continue(self):
        self.result = "CONTINUE"
        self.destroy()

    def _stop(self):
        self.result = "STOP"
        self.destroy()


# ── TCP client handler ────────────────────────────────────────
def handle_client(conn):
    try:
        data = b""
        while not data.endswith(b"\n"):
            chunk = conn.recv(1024)
            if not chunk:
                break
            data += chunk

        msg   = data.decode("utf-8").strip()
        parts = msg.split("|")

        if len(parts) == 3 and parts[0] == "POPUP":
            title, body = parts[1], parts[2]
        elif len(parts) == 2 and parts[0] == "POPUP":
            title, body = "Robot Alert", parts[1]
        else:
            title, body = "Robot Alert", msg

        event      = threading.Event()
        result_box = [None]
        popup_queue.put((title, body, event, result_box))
        event.wait()  # block until user clicks

        action = result_box[0] or "CONTINUE"

        # Send response first, then save log (log failure must not block response)
        conn.sendall((action + "\n").encode("utf-8"))
        save_log(title, body, action)

    except Exception as e:
        print(f"[Error] Client handling failed: {e}")
    finally:
        conn.close()


# ── TCP server ──────────────────────────────────────────────────
def tcp_server():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((HOST, PORT))
        srv.listen()
        print(f"[Popup server] Listening on {HOST}:{PORT}...")
        print(f"[Log path] {LOG_DIR}")
        while True:
            conn, addr = srv.accept()
            print(f"[Connected] {addr}")
            threading.Thread(target=handle_client, args=(conn,), daemon=True).start()


# ── Process popup queue in tkinter main loop ────────────────────
def poll_queue(root):
    try:
        while True:
            title, body, event, result_box = popup_queue.get_nowait()
            dlg            = PopupDialog(root, title, body)
            result_box[0]  = dlg.result
            event.set()
    except queue.Empty:
        pass
    root.after(200, poll_queue, root)


def main():
    threading.Thread(target=tcp_server, daemon=True).start()
    root = tk.Tk()
    root.withdraw()
    root.after(200, poll_queue, root)
    root.mainloop()


if __name__ == "__main__":
    main()
