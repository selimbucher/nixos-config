#!/usr/bin/env python3
"""batlog: where the laptop's battery goes, measured over real use.

  batlog report [-d DAYS]         summary of the last DAYS days (default 7)
  batlog ab refresh|bitdepth|blur hands-off A/B power test of a display setting
  batlog ab -a CMD -b CMD         same for any two commands (-a = current state,
                                  it is restored at the end)
  batlog sample                   sampler daemon (as root: RAPL, package
                                  C-states, every process's GPU time)
  batlog mark sleep|wake          suspend bookkeeping, run by the sleep hooks
"""

import argparse
import bisect
import datetime
import glob
import json
import os
import re
import socket
import statistics
import struct
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from collections import defaultdict

SYS_DIR = "/var/lib/batlog"
# runs before the system service exists (no root) write here; report reads both
USER_DIR = os.path.expanduser("~/.local/state/batlog")
BAT = "/sys/class/power_supply/BAT0"
PMC = "/sys/kernel/debug/pmc_core"
# RAPL zones by name: their numbering differs between machines
RAPL_NAMES = {"package-0": "pkg", "core": "core", "uncore": "unc", "psys": "sys"}
# package C-state residency MSRs, counting at TSC rate (MSR 0x10)
PKG_CSTATES = {"pc2": 0x60D, "pc6": 0x3F9, "pc8": 0x630, "pc10": 0x632}
IDLE_AFTER = 180  # s without input before a sample counts as idle
CLK = os.sysconf("SC_CLK_TCK")

TERMINALS = {"kitty", "foot", "alacritty", "wezterm-gui", "ghostty", "konsole",
             "gnome-terminal-server"}
SHELLS = {"zsh", "bash", "fish", "sh", "dash", "nu"}
# a process belongs to its ancestor right below one of these (the user
# manager or the compositor); inside a terminal, to the shell's child
ROOTS = {"systemd", "Hyprland"}


def rd(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def rdint(path, default=None):
    try:
        return int(rd(path))
    except (TypeError, ValueError):
        return default


# --------------------------------------------------------------- sources

class Hypr:
    """Hyprland IPC over the raw socket, so it works from a root service.
    Picks the instance driving real connectors, never a nested test session."""

    def __init__(self):
        self.path = None

    @staticmethod
    def _ask(path, cmd):
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as c:
                c.settimeout(1)
                c.connect(path)
                c.sendall(cmd.encode())
                buf = b""
                while chunk := c.recv(65536):
                    buf += chunk
            return json.loads(buf)
        except (OSError, ValueError):
            return None

    def _find(self):
        socks = glob.glob("/run/user/*/hypr/*/.socket.sock")
        # signature = <hash>_<start time>_<rand>: oldest first
        socks.sort(key=lambda s: s.split("/")[-2].split("_")[1:2])
        for s in socks:
            mons = self._ask(s, "j/monitors")
            if isinstance(mons, list) and any(
                    re.match(r"(eDP|DP|HDMI)-", m.get("name", "")) for m in mons):
                return s
        return None

    def ask(self, cmd):
        if self.path:
            r = self._ask(self.path, cmd)
            if r is not None:
                return r
        self.path = self._find()
        return self._ask(self.path, cmd) if self.path else None


def battery():
    w, wh = rdint(f"{BAT}/power_now"), rdint(f"{BAT}/energy_now")
    return {"st": rd(f"{BAT}/status", "Unknown"),
            "w": w / 1e6 if w is not None else None,
            "wh": wh / 1e6 if wh is not None else None,
            "pct": rdint(f"{BAT}/capacity")}


def rapl_zones():
    """{pkg|core|unc|sys: sysfs dir}"""
    out = {}
    for z in sorted(glob.glob("/sys/class/powercap/intel-rapl:*")):
        k = RAPL_NAMES.get(rd(z + "/name"))
        if k and k not in out:
            out[k] = z
    return out


def gpu_floor():
    """the i915 minimum clock (MHz), set by a udev rule on the laptop"""
    for f in glob.glob("/sys/class/drm/card[0-9]/gt/gt0/rps_min_freq_mhz"):
        return rdint(f)
    return None


def cpu_busy_ticks():
    with open("/proc/stat") as f:
        v = [int(x) for x in f.readline().split()[1:9]]
    return sum(v) - v[3] - v[4]  # minus idle and iowait


def input_irq_labels():
    """built-in keyboard (i8042) and i2c-hid touchpad/touchscreen, as named in /proc/interrupts"""
    return ["i8042"] + [os.path.basename(d)[4:]
                        for d in glob.glob("/sys/bus/i2c/drivers/i2c_hid*/i2c-*")]


def interrupts(labels):
    """(all interrupts, interrupts from built-in input devices), cumulative"""
    total = inp = 0
    with open("/proc/interrupts") as f:
        ncpu = len(f.readline().split())
        for line in f:
            n = 0
            for p in line.split()[1:ncpu + 1]:
                if not p.isdigit():
                    break
                n += int(p)
            total += n
            if any(lb in line for lb in labels):
                inp += n
    return total, inp


def read_msrs():
    try:
        fd = os.open("/dev/cpu/0/msr", os.O_RDONLY)
    except OSError:
        return None
    out = {}
    try:
        for k, reg in [("tsc", 0x10), *PKG_CSTATES.items()]:
            try:
                out[k] = struct.unpack("<Q", os.pread(fd, 8, reg))[0]
            except OSError:
                pass
    finally:
        os.close(fd)
    return out


def clean(comm):
    # nix wrappers: .kitty-wrapped, .claude-unwrapp, ..kiwi-core-wr
    return re.sub(r"(-(un)?wr[a-z]*)+$", "", comm.lstrip(".")) or comm


def scan_procs():
    """pid -> [ppid, name, own ticks, reaped children's ticks, start tick, timeslices]"""
    procs = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as f:
                s = f.read()
        except OSError:
            continue
        lp, rp = s.index("("), s.rindex(")")
        f = s[rp + 2:].split()
        slices = 0  # times scheduled in, summed over threads: ~wakeups
        try:
            for tid in os.listdir(f"/proc/{pid}/task"):
                with open(f"/proc/{pid}/task/{tid}/schedstat") as t:
                    slices += int(t.read().split()[2])
        except (OSError, IndexError, ValueError):
            pass
        procs[int(pid)] = [int(f[1]), clean(s[lp + 1:rp]), int(f[11]) + int(f[12]),
                           int(f[13]) + int(f[14]), int(f[19]), slices]
    return procs


def gpu_clients(procs):
    """DRM client id -> (pid, render/copy/compute ns, video ns), from fdinfo"""
    out = {}
    for pid in procs:
        try:
            fds = os.listdir(f"/proc/{pid}/fd")
        except OSError:
            continue
        for fd in fds:
            try:
                if not os.readlink(f"/proc/{pid}/fd/{fd}").startswith("/dev/dri/"):
                    continue
                with open(f"/proc/{pid}/fdinfo/{fd}") as f:
                    info = f.read()
            except OSError:
                continue
            cid, gfx, vid = None, 0, 0
            for line in info.splitlines():
                k, _, v = line.partition(":")
                if k == "drm-client-id":
                    cid = v.strip()
                elif k.startswith("drm-engine-") and not k.startswith("drm-engine-capacity"):
                    ns = int(v.split()[0])
                    if "video" in k:
                        vid += ns
                    else:
                        gfx += ns
            if cid is not None and cid not in out:
                out[cid] = (pid, gfx, vid)
    return out


def app_of(pid, procs, memo):
    if pid in memo:
        return memo[pid]
    if pid not in procs:
        return "?"
    chain, p = [], pid
    while p in procs and p > 2:
        chain.append(p)
        p = procs[p][0]
    name = lambda q: procs[q][1]
    if p == 2 or pid == 2:
        key = "[kernel]"
    elif not chain:
        key = "systemd"
    else:
        top = chain[-1]  # a system service right below pid 1
        for i, q in enumerate(chain):
            if name(q) in TERMINALS:
                below = chain[:i]
                top = below[-2] if len(below) >= 2 and name(below[-1]) in SHELLS else q
                break
            if name(q) in ROOTS:
                top = chain[i - 1] if i else q
                break
        key = name(top)
        if key == "bwrap":  # flatpak: name it after its app scope
            m = re.search(r"app-flatpak-([\w.-]+?)-\d+\.scope", rd(f"/proc/{pid}/cgroup", ""))
            if m:
                key = m.group(1).rsplit(".", 1)[-1]
        elif key == "electron":  # name it after the app it runs
            m = re.search(r"/([^/\0]+)/(?:resources/)?app\.asar",
                          rd(f"/proc/{top}/cmdline", "").replace("\0", " "))
            if m:
                key = m.group(1)
    memo[pid] = key
    return key


def audio_playing():
    return any("RUNNING" in (rd(s) or "")
               for s in glob.glob("/proc/asound/card*/pcm*p/sub*/status"))


def nvme_ops():
    n = 0
    for f in glob.glob("/sys/block/nvme*n*/stat"):
        v = (rd(f) or "").split()
        if len(v) > 4:
            n += int(v[0]) + int(v[4])
    return n


def snapshot(hy, labels, zones):
    s = {"t": time.time(), "mono": time.monotonic(),
         "boot": time.clock_gettime(time.CLOCK_BOOTTIME), "bat": battery(),
         "busy": cpu_busy_ticks(), "msr": read_msrs()}
    s["irq"], s["inp"] = interrupts(labels)
    s["rapl"] = {k: (rdint(z + "/energy_uj"), rdint(z + "/max_energy_range_uj", 1 << 32))
                 for k, z in zones.items()}
    s["rc6"] = {os.path.basename(g): rdint(g + "/rc6_residency_ms")
                for g in glob.glob("/sys/class/drm/card[0-9]/gt/gt*")}
    s["procs"] = scan_procs()
    s["gpu"] = gpu_clients(s["procs"])
    s["net"] = sum(rdint(f, 0) for f in glob.glob("/sys/class/net/wl*/statistics/[rt]x_bytes"))
    s["io"] = nvme_ops()
    mons = hy.ask("j/monitors")
    s["mon"] = [[m["name"], round(m["refreshRate"]),
                 10 if "2101010" in m.get("currentFormat", "") else 8, m["dpmsStatus"]]
                for m in mons if not m.get("disabled")] if isinstance(mons, list) else None
    w = hy.ask("j/activewindow")
    s["focus"] = (w.get("class") or None) if isinstance(w, dict) else None
    c = hy.ask("j/cursorpos")
    s["cur"] = (c.get("x"), c.get("y")) if isinstance(c, dict) else None
    bl = glob.glob("/sys/class/backlight/*")
    if bl:
        s["bl"] = rdint(bl[0] + "/brightness", 0) / max(rdint(bl[0] + "/max_brightness", 1), 1)
    s["epp"] = rd("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference")
    s["pp"] = rd("/sys/firmware/acpi/platform_profile")
    s["gmin"] = gpu_floor()
    s["aud"] = audio_playing()
    s["bt"] = len(glob.glob("/sys/class/bluetooth/hci*:*"))  # one per connection
    return s


def record(a, b, self_s):
    dt = b["mono"] - a["mono"]
    r = {"t": round(b["t"]), "dt": round(dt, 1)}
    r.update({k: round(v, 3) if isinstance(v, float) else v
              for k, v in b["bat"].items() if v is not None})
    slept = b["boot"] - a["boot"] - dt
    if slept > 5:
        r["sl"] = round(slept)  # energy counters ran on through the suspend
    else:
        for k, (e2, mx) in b["rapl"].items():
            e1 = a["rapl"].get(k, (None,))[0]
            if e1 is not None and e2 is not None:
                r[k] = round((e2 - e1) % mx / 1e6 / dt, 2)
        ma, mb = a["msr"] or {}, b["msr"] or {}
        if "tsc" in ma and "tsc" in mb and mb["tsc"] > ma["tsc"]:
            dtsc = mb["tsc"] - ma["tsc"]
            r["pc"] = {k: round((mb[k] - ma[k]) / dtsc, 3)
                       for k in PKG_CSTATES if k in ma and k in mb}
    r["cpu"] = round((b["busy"] - a["busy"]) / CLK / dt, 3)  # cores busy
    for gt, key in (("gt0", "gpu"), ("gt1", "gpum")):  # render, media (if separate)
        x, y = a["rc6"].get(gt), b["rc6"].get(gt)
        if x is not None and y is not None:
            r[key] = round(min(max(1 - (y - x) / (dt * 1000), 0), 1), 3)
    r["irq"] = round((b["irq"] - a["irq"]) / dt)
    r["inp"] = b["inp"] - a["inp"]
    r["cur"] = a["cur"] is not None and b["cur"] is not None and a["cur"] != b["cur"]
    r["net"] = round((b["net"] - a["net"]) / 1024 / dt, 1)  # KiB/s
    r["io"] = round((b["io"] - a["io"]) / dt, 1)  # SSD ops/s
    for k in ("bl", "epp", "pp", "gmin", "aud", "bt", "mon", "focus"):
        if b.get(k) is not None:
            r[k] = round(b[k], 2) if k == "bl" else b[k]

    # per app: [cpu s, gpu s, video-engine s, wakeups]
    apps = defaultdict(lambda: [0.0, 0.0, 0.0, 0])
    memo = {}
    born_after = a["boot"] * CLK
    pa, pb = a["procs"], b["procs"]
    reaped = defaultdict(int)  # parent -> ticks of dead children already counted
    for pid, p in pa.items():
        q = pb.get(pid)
        if q is None or q[4] != p[4]:
            reaped[p[0]] += p[2] + p[3]
    for pid, q in pb.items():
        p = pa.get(pid)
        if p and p[4] == q[4]:
            own, kids, wk = q[2] - p[2], q[3] - p[3] - reaped.get(pid, 0), q[5] - p[5]
        elif q[4] >= born_after:
            own, kids, wk = q[2], q[3], q[5]
        else:
            continue
        x = apps[app_of(pid, pb, memo)]
        x[0] += own / CLK
        x[3] += max(wk, 0)
        # the session roots reap orphans whose own app is gone by now
        (apps["~exited"] if q[1] in ROOTS else x)[0] += max(kids, 0) / CLK
    for cid, (pid, g, v) in b["gpu"].items():
        if cid in a["gpu"]:
            _, g0, v0 = a["gpu"][cid]
            g, v = g - g0, v - v0
        elif not (pid in pb and pb[pid][4] >= born_after):
            continue  # opened by an older process: counted from the next sample
        x = apps[app_of(pid, pb, memo)]
        x[1] += max(g, 0) / 1e9
        x[2] += max(v, 0) / 1e9
    ranked = sorted(apps.items(), key=lambda kv: -(kv[1][0] + kv[1][1]))
    r["apps"] = {}
    for i, (k, (c, g, v, wk)) in enumerate(ranked):
        k = k if i < 12 else "~other"
        o = r["apps"].setdefault(k, [0, 0, 0, 0])
        o[0], o[1], o[2], o[3] = o[0] + c, o[1] + g, o[2] + v, o[3] + wk
    r["apps"] = {k: [round(c, 2), round(g, 2), round(v, 2), wk]
                 for k, (c, g, v, wk) in r["apps"].items() if c + g + v >= 0.01 or wk >= dt}
    r["self"] = round(self_s * 1000)  # ms of CPU this sample cost batlog itself
    return r


def append(d, rec):
    with open(os.path.join(d, time.strftime("%Y-%m") + ".jsonl"), "a") as f:
        f.write(json.dumps(rec, separators=(",", ":")) + "\n")


def cmd_sample(args):
    root = os.geteuid() == 0
    d = args.dir or (SYS_DIR if root else USER_DIR)
    os.makedirs(d, exist_ok=True)
    hy, labels, zones = Hypr(), input_irq_labels(), rapl_zones()
    prev, cpu0 = snapshot(hy, labels, zones), time.process_time()
    while True:
        time.sleep(args.tick)
        st = rd(f"{BAT}/status")
        # on AC the battery rate is charging, not drain: sample sparsely
        if (st != "Discharging" and st == prev["bat"]["st"]
                and time.monotonic() - prev["mono"] < args.ac_every):
            continue
        try:
            cur = snapshot(hy, labels, zones)
            cpu1 = time.process_time()
            append(d, record(prev, cur, cpu1 - cpu0))
            prev, cpu0 = cur, cpu1
        except Exception as e:  # one bad read must not end the log
            print(f"batlog: {e!r}", file=sys.stderr, flush=True)
        if not root and d == USER_DIR and any(
                time.time() - os.path.getmtime(f) < 900
                for f in glob.glob(f"{SYS_DIR}/*.jsonl")):
            print("batlog: system service is logging, preview exits", flush=True)
            return


def cmd_mark(args):
    d = SYS_DIR if os.geteuid() == 0 else USER_DIR
    os.makedirs(d, exist_ok=True)
    state = os.path.join(d, ".sleep.json")
    r = {"t": round(time.time()), "ev": args.what,
         **{k: v for k, v in battery().items() if v is not None}}
    wake = {}
    for w in glob.glob("/sys/class/wakeup/wakeup*"):
        name = rd(w + "/name")
        if name:
            wake[name] = rdint(w + "/event_count", 0)
    s0ix = rdint(f"{PMC}/slp_s0_residency_usec")
    if args.what == "sleep":
        r["ctx"] = {
            "bt": len(glob.glob("/sys/class/bluetooth/hci*:*")),
            "usb": sorted({rd(p) for p in glob.glob("/sys/bus/usb/devices/*/product")}
                          - {"xHCI Host Controller", None}),
            "ext": [os.path.basename(c).split("-", 1)[1] for c in glob.glob("/sys/class/drm/card*-*")
                    if "eDP" not in c and rd(c + "/status") == "connected"],
            "aud": audio_playing()}
        with open(state, "w") as f:
            json.dump({"wake": wake, "s0ix": s0ix}, f)
    else:
        hw = rdint("/sys/power/suspend_stats/last_hw_sleep")  # µs in S0ix, last suspend
        if hw is not None:
            r["hw"] = hw
        try:
            with open(state) as f:
                before = json.load(f)
            # which wakeup sources fired while asleep (the lid/power key that ended it too)
            r["woke"] = {k: v - before["wake"].get(k, 0) for k, v in wake.items()
                         if v > before["wake"].get(k, 0)}
            if s0ix is not None and before.get("s0ix") is not None:
                r["s0ix"] = s0ix - before["s0ix"]
        except (OSError, ValueError, KeyError):
            pass
    append(d, r)


# ---------------------------------------------------------------- report

def load(dirs, days):
    cutoff = time.time() - days * 86400
    seen, recs, marks = set(), [], []
    for d in dirs:
        for path in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
            try:
                f = open(path)
            except OSError:
                continue
            with f:
                for line in f:
                    try:
                        r = json.loads(line)
                    except ValueError:
                        continue
                    key = (r.get("t", 0), r.get("ev"))
                    if key[0] < cutoff or key in seen:
                        continue
                    seen.add(key)
                    (marks if "ev" in r else recs).append(r)
    recs.sort(key=lambda r: r["t"])
    marks.sort(key=lambda r: r["t"])
    return recs, marks


def classify(recs):
    last = None
    for r in recs:
        if r.get("sl"):
            last = None
        if r.get("inp") or r.get("cur"):
            last = r["t"]
        mons = r.get("mon")
        if mons and not any(m[3] for m in mons):
            r["_s"] = "screen off"
        elif last is not None and r["t"] - last < IDLE_AFTER:
            r["_s"] = "active"
        else:
            r["_s"] = "idle"


def hours(rs):
    return sum(r["dt"] for r in rs) / 3600


def wh(rs, key="w"):
    return sum(r[key] * r["dt"] for r in rs if r.get(key) is not None) / 3600


def wmean(rs, key):
    xs = [(r[key], r["dt"]) for r in rs if r.get(key) is not None]
    t = sum(dt for _, dt in xs)
    return sum(v * dt for v, dt in xs) / t if t else None


def f1(x, unit=""):
    return "–" if x is None else f"{x:.1f}{unit}"


def table(rows, head, min_h=0.1):
    rows = [r for r in rows if r[1] >= min_h]
    if not rows:
        return
    w = max(len(str(r[0])) for r in rows + [head])
    print("  " + str(head[0]).ljust(w) + "".join(f"{h:>10}" for h in head[1:]))
    for r in rows:
        print("  " + str(r[0]).ljust(w) + "".join(
            f"{c:>10}" if isinstance(c, str) else f"{c:>10.1f}" for c in r[1:]))


def group_rows(rs, keyf, min_h):
    g = defaultdict(list)
    for r in rs:
        k = keyf(r)
        if k is not None:
            g[k].append(r)
    rows = [(k, hours(v), wmean(v, "w"), statistics.median(x["w"] for x in v),
             f1(wmean(v, "pkg"))) for k, v in g.items()]
    return sorted([x for x in rows if x[1] >= min_h], key=lambda x: -x[1])


def aw_sites(active):
    """browser samples by site, if ActivityWatch's web watcher has the data"""
    try:
        with urllib.request.urlopen("http://localhost:5600/api/0/buckets/", timeout=1) as u:
            buckets = [k for k, v in json.load(u).items() if v.get("type") == "web.tab.current"]
    except (OSError, ValueError):
        return None
    br = [r for r in active if re.search(r"brave|chrom|firefox", r.get("focus") or "", re.I)]
    if not br or not buckets:
        return None
    iso = lambda t: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(t))  # RFC 3339
    ev = []
    for b in buckets:
        q = urllib.parse.urlencode({"start": iso(br[0]["t"] - 60), "end": iso(br[-1]["t"]),
                                    "limit": 100000})
        try:
            with urllib.request.urlopen(f"http://localhost:5600/api/0/buckets/{b}/events?{q}",
                                        timeout=5) as u:
                for e in json.load(u):
                    s = datetime.datetime.fromisoformat(
                        e["timestamp"].replace("Z", "+00:00")).timestamp()
                    url = e["data"].get("url", "")
                    ev.append((s, s + e["duration"], url.split("/")[2] if "://" in url else url[:30]))
        except (OSError, ValueError, KeyError):
            continue
    ev.sort()
    starts = [e[0] for e in ev]
    out = []
    for r in br:
        i = bisect.bisect_right(starts, r["t"] - 15) - 1
        for e in ev[max(i - 3, 0):i + 2]:
            if e[0] <= r["t"] - 15 <= e[1] + 5:
                out.append(dict(r, site=e[2]))
                break
    return out


def cmd_report(args):
    dirs = args.dir or [SYS_DIR, USER_DIR]
    recs, marks = load(dirs, args.days)
    if not recs and not marks:
        sys.exit(f"no data in {' or '.join(dirs)} yet — is `batlog sample` running?")
    classify(recs)
    B = [r for r in recs if r.get("st") == "Discharging" and r.get("w") and not r.get("sl")]
    day = lambda t: time.strftime("%a %d %b %H:%M", time.localtime(t))
    first = min([r["t"] for r in recs + marks])
    print(f"batlog  {day(first)} → {day(time.time())}\n")
    full = (rdint(f"{BAT}/energy_full") or 0) / 1e6 or None

    if B:
        mean_w, med_w = wmean(B, "w"), statistics.median(r["w"] for r in B)
        print(f"On battery: {hours(B):.1f} h sampled, {wh(B):.0f} Wh used, "
              f"mean {mean_w:.1f} W, median {med_w:.1f} W")
        if full:
            print(f"  a full charge ({full:.1f} Wh) lasts {full / mean_w:.1f} h at your mean, "
                  f"{full / med_w:.1f} h at your median")
        has_pkg = any(r.get("pkg") is not None for r in B)
        if has_pkg:
            p = wmean(B, "pkg")
            print(f"  SoC package {p:.1f} W (cores {f1(wmean(B, 'core'))}, "
                  f"uncore/GPU {f1(wmean(B, 'unc'))}) + rest of the laptop {mean_w - p:.1f} W "
                  f"(display, RAM, SSD, Wi-Fi, conversion losses)"
                  + (f"; psys reads {wmean(B, 'sys'):.1f} W" if wmean(B, "sys") else ""))
        print()

        print("By state")
        rows = []
        for s in ("active", "idle", "screen off"):
            rs = [r for r in B if r["_s"] == s]
            if rs:
                deep = [r["pc"].get("pc8", 0) + r["pc"].get("pc10", 0) for r in rs if r.get("pc")]
                rows.append((s + (", screen on" if s == "idle" else ""), hours(rs), wh(rs),
                             wmean(rs, "w"), f1(wmean(rs, "pkg")),
                             f"{statistics.mean(deep) * 100:.0f}%" if deep else "–"))
        table(rows, ("", "hours", "Wh", "mean W", "SoC W", "PC8+"), 0)
        print()

        active = [r for r in B if r["_s"] == "active"]
        sites = aw_sites(active)
        for title, rs, kf in (("Focused app, while active", active,
                               lambda r: r.get("focus") or "(none)"),
                              ("Browser by site, while active (via ActivityWatch)", sites or [],
                               lambda r: r["site"])):
            rows = group_rows(rs, kf, 0.15)
            if rows:
                print(title)
                table(rows, ("", "hours", "mean W", "median W", "SoC W"))
                print()

        # split the SoC's power above its idle floor by CPU + GPU time
        val = (lambda r: r.get("pkg")) if has_pkg else (lambda r: r["w"])
        vals = sorted(v for v in map(val, B) if v is not None)
        base = vals[len(vals) // 20]
        est, tot = defaultdict(lambda: [0.0, 0.0, 0.0, 0.0, 0.0]), hours(B) * 3600
        for r in B:
            apps = r.get("apps") or {}
            wt = sum(c + g for c, g, *_ in apps.values())
            dyn = max((val(r) or base) - base, 0)
            for k, (c, g, v, wk) in apps.items():
                e = est[k]
                e[0] += dyn * r["dt"] * (c + g) / wt / 3600 if wt else 0
                e[1] += c
                e[2] += g
                e[3] += v
                e[4] += wk
        src = "SoC package" if has_pkg else "battery"
        print(f"Apps by estimated energy, all battery time ({src} power above its "
              f"{base:.1f} W floor, split by CPU+GPU time; rough)")
        rows = [(k, e[0], e[1] / tot, e[2] / tot * 100, e[3] / tot * 100, e[4] / tot)
                for k, e in sorted(est.items(), key=lambda kv: -kv[1][0])[:14]]
        table([(k, a, f"{c:.2f}", f"{g:.0f}%", f"{v:.0f}%", f"{w:.0f}") for k, a, c, g, v, w in rows],
              ("", "≈Wh", "CPU cores", "GPU", "video", "wakeups/s"), 0)
        print()

        print("While active, by setting")
        edp = lambda r: next((m for m in r.get("mon") or [] if m[0].startswith("eDP")), None)
        settings = [
            ("refresh", lambda r: f"{edp(r)[1]} Hz" if edp(r) else None),
            ("bit depth", lambda r: f"{edp(r)[2]}-bit" if edp(r) else None),
            ("brightness", lambda r: f"{int(r['bl'] * 4) * 25}–{int(r['bl'] * 4) * 25 + 25}%"
                                     if r.get("bl") is not None else None),
            ("GPU floor", lambda r: f"{r['gmin']} MHz" if r.get("gmin") else None),
            ("EPP", lambda r: r.get("epp")),
            ("ext display", lambda r: "yes" if any(not m[0].startswith("eDP") for m in r.get("mon") or [])
                                      else "no"),
            ("audio out", lambda r: "playing" if r.get("aud") else "silent"),
            ("BT links", lambda r: str(r.get("bt", 0))),
        ]
        for name, kf in settings:
            rows = group_rows(active, kf, 0.25)
            if len(rows) > 1:
                print(f"  {name:12}" + "   ".join(f"{k}: {w:.1f} W ({h:.1f} h)"
                                                   for k, h, w, *_ in sorted(rows)))
        print("  (these mix in whatever else was running; `batlog ab` isolates one setting)\n")

        # heaviest quarter hours and what ran in them
        g = defaultdict(list)
        for r in B:
            g[r["t"] // 900].append(r)
        heavy = sorted((k for k in g if hours(g[k]) >= 0.1), key=lambda k: -wmean(g[k], "w"))[:5]
        if heavy:
            print("Heaviest 15 minutes")
            for k in heavy:
                apps = defaultdict(float)
                for r in g[k]:
                    for a, (c, gg, *_) in (r.get("apps") or {}).items():
                        apps[a] += c + gg
                span = sum(r["dt"] for r in g[k])
                top = ", ".join(f"{a} {v / span:.1f}" for a, v in
                                sorted(apps.items(), key=lambda kv: -kv[1])[:3])
                foc = statistics.mode([r.get("focus") or "-" for r in g[k]])
                print(f"  {day(k * 900)}  {wmean(g[k], 'w'):5.1f} W  focus {foc}; busiest: {top} (cores+GPU)")
            print()
    else:
        print("No battery samples yet: unplug and use the laptop as usual.\n")

    # suspends: pair each sleep mark with the next wake
    pairs, pending = [], None
    for m in marks:
        if m["ev"] == "sleep":
            pending = m
        elif pending:
            pairs.append((pending, m))
            pending = None
    pairs = [(s, w) for s, w in pairs if s.get("st") == "Discharging"
             and w.get("st") == "Discharging" and w["t"] - s["t"] >= 600]
    susp_w = None
    if pairs:
        h = sum(w["t"] - s["t"] for s, w in pairs) / 3600
        e = sum(s["wh"] - w["wh"] for s, w in pairs)
        pct = sum(s["pct"] - w["pct"] for s, w in pairs)
        susp_w = e / h
        print(f"Suspend: {len(pairs)} on battery, {h:.1f} h, {e:.1f} Wh, "
              f"{susp_w:.2f} W average ({pct / h:.2f} %/h, {pct / h * 24:.0f} %/day)")
        rows = []
        for s, w in pairs:
            dur = w["t"] - s["t"]
            hw = f"{w['hw'] / 1e6 / dur * 100:.0f}%" if w.get("hw") is not None else "–"
            woke = ", ".join(f"{k}×{v}" for k, v in sorted(
                (w.get("woke") or {}).items(), key=lambda kv: -kv[1])[:3])
            ctx = s.get("ctx") or {}
            extra = " ".join(filter(None, [f"BT {ctx['bt']}" if ctx.get("bt") else "",
                                           "ext display" if ctx.get("ext") else "",
                                           "audio" if ctx.get("aud") else "",
                                           ("usb: " + ", ".join(ctx["usb"])) if ctx.get("usb") else ""]))
            rows.append((day(s["t"]), dur / 3600, (s["wh"] - w["wh"]) / (dur / 3600), hw, woke or "–", extra))
        w0 = max(len(r[0]) for r in rows)
        print(f"  {'':{w0}}  hours      W  S0ix  woken by / context")
        for d, hh, ww, hw, wk, ex in rows:
            print(f"  {d:{w0}}  {hh:5.1f}  {ww:5.2f}  {hw:>4}  {wk}{'  · ' + ex if ex else ''}")
        print()

    hints = []
    if B:
        idle = [r for r in B if r["_s"] == "idle"]
        if hours(idle) >= 0.5:
            sw = susp_w if susp_w is not None else 0.4
            hints.append(f"{hours(idle):.1f} h idle with the screen on cost {wh(idle):.0f} Wh "
                         f"({wmean(idle, 'w'):.1f} W). Suspended it would have been "
                         f"~{hours(idle) * sw:.0f} Wh: the idle timeouts only act on battery "
                         f"and yield to idle inhibitors, so check what held them off.")
        pcs = [r["pc"] for r in idle if r.get("pc")]
        if pcs:
            deep = statistics.mean(p.get("pc8", 0) + p.get("pc10", 0) for p in pcs)
            if deep < 0.5:
                hints.append(f"Idle with the screen on, the SoC sits in PC8 or deeper only "
                             f"{deep * 100:.0f}% of the time; something keeps it awake "
                             f"(check wakeups/s above; NVMe APST is off via the kernel cmdline).")
        wk = defaultdict(float)
        for r in idle:
            for a, x in (r.get("apps") or {}).items():
                wk[a] += x[3]
        ih = hours(idle) * 3600
        loud = [(a, v / ih) for a, v in wk.items() if ih and v / ih > 150]
        for a, v in sorted(loud, key=lambda kv: -kv[1])[:3]:
            hints.append(f"{a} wakes the CPU {v:.0f}×/s while you're idle.")
    for s, w in pairs:
        dur = w["t"] - s["t"]
        if w.get("hw") is not None and w["hw"] / 1e6 / dur < 0.9:
            hints.append(f"Suspend at {day(s['t'])} spent only {w['hw'] / 1e6 / dur * 100:.0f}% "
                         f"in S0ix ({(s['wh'] - w['wh']) / (dur / 3600):.2f} W).")
    if hints:
        print("Worth a look")
        for h in hints:
            print("  • " + h)


# -------------------------------------------------------------------- ab

def hypr_eval(lua):
    r = subprocess.run(["hyprctl", "eval", lua], capture_output=True, text=True)
    if r.returncode or r.stdout.strip() != "ok":
        raise RuntimeError(f"hyprctl eval failed: {(r.stdout + r.stderr).strip()}")


def presets(name, hy):
    if name == "blur":
        on = (hy.ask("j/getoption decoration:blur:enabled") or {}).get("bool", True)
        lua = lambda v: f"hl.config({{ decoration = {{ blur = {{ enabled = {str(v).lower()} }} }} }})"
        return ((f"blur {'on' if on else 'off'}", lambda: hypr_eval(lua(on))),
                (f"blur {'off' if on else 'on'}", lambda: hypr_eval(lua(not on))))
    m = next((m for m in hy.ask("j/monitors") or [] if m["name"].startswith("eDP")), None)
    if not m:
        sys.exit("no internal display found")
    hz, bits = round(m["refreshRate"]), 10 if "2101010" in m["currentFormat"] else 8
    scale = m["scale"]
    scale = str(int(scale)) if scale == int(scale) else str(scale)

    def mon(hz, bits):
        return lambda: hypr_eval(
            f'hl.monitor({{ output = "{m["name"]}", mode = "{m["width"]}x{m["height"]}@{hz}", '
            f'position = "{m["x"]}x{m["y"]}", scale = "{scale}", bitdepth = {bits} }})')
    if name == "refresh":
        size = f'{m["width"]}x{m["height"]}@'
        rates = sorted({round(float(x[len(size):].rstrip("Hz"))) for x in m.get("availableModes", [])
                        if x.startswith(size)} - {hz})
        if not rates:
            sys.exit(f"{m['name']} only runs at {hz} Hz: nothing to compare")
        alt = 60 if 60 in rates else rates[-1]
        return (f"{hz} Hz", mon(hz, bits)), (f"{alt} Hz", mon(alt, bits))
    alt = 8 if bits == 10 else 10
    return (f"{bits}-bit", mon(hz, bits)), (f"{alt}-bit", mon(hz, alt))


def cmd_ab(args):
    hy = Hypr()
    if args.preset:
        (na, fa), (nb, fb) = presets(args.preset, hy)
    elif args.a and args.b:
        na, nb = args.a, args.b
        fa = lambda: subprocess.run(args.a, shell=True, check=True)
        fb = lambda: subprocess.run(args.b, shell=True, check=True)
    else:
        sys.exit("give a preset (refresh, bitdepth, blur) or both -a and -b")
    if rd(f"{BAT}/status") != "Discharging" and not args.allow_ac:
        sys.exit("unplug the charger first: the battery only reports drain while discharging")
    seq = (["a", "b", "b", "a"] * args.rounds)[:2 * args.rounds]  # ABBA cancels drift
    total = len(seq) * (args.settle + args.secs)
    print(f"A = {na}\nB = {nb}\n{len(seq)} phases, {total // 60} min {total % 60} s. "
          f"Hands off: no keys, no touchpad, nothing moving on screen.")
    for i in range(5, 0, -1):
        print(f"  starting in {i}…", end="\r", flush=True)
        time.sleep(1)
    labels = input_irq_labels()
    rapl = rapl_zones().get("pkg")
    mx = rdint(f"{rapl}/max_energy_range_uj", 1 << 32)
    names, funcs, res = {"a": na, "b": nb}, {"a": fa, "b": fb}, {"a": [], "b": []}
    try:
        for i, ph in enumerate(seq, 1):
            funcs[ph]()
            time.sleep(args.settle)
            _, i0 = interrupts(labels)
            e0, t0, ws = rdint(f"{rapl}/energy_uj"), time.monotonic(), []
            while time.monotonic() - t0 < args.secs:
                w = rdint(f"{BAT}/power_now")
                if w:
                    ws.append(w / 1e6)
                time.sleep(1)
            e1, t1 = rdint(f"{rapl}/energy_uj"), time.monotonic()
            _, i1 = interrupts(labels)
            pkg = (e1 - e0) % mx / 1e6 / (t1 - t0) if e0 is not None and e1 is not None else None
            res[ph].append((statistics.mean(ws), pkg))
            print(f"  {i}/{len(seq)}  {names[ph]:>12}  {statistics.mean(ws):6.2f} W battery"
                  + (f"  {pkg:6.2f} W package" if pkg is not None else "")
                  + ("   ← input during this phase" if i1 > i0 else ""))
    finally:
        fa()  # back to where you started
    ma = statistics.mean(x for x, _ in res["a"])
    mb = statistics.mean(x for x, _ in res["b"])
    d = mb - ma
    print(f"\n  A {na}: {ma:.2f} W    B {nb}: {mb:.2f} W    B−A {d:+.2f} W ({d / ma * 100:+.0f}%)")
    if all(p is not None for _, p in res["a"] + res["b"]):
        pa = statistics.mean(p for _, p in res["a"])
        pb = statistics.mean(p for _, p in res["b"])
        print(f"  package: {pa:.2f} W → {pb:.2f} W ({pb - pa:+.2f} W)")
    full = (rdint(f"{BAT}/energy_full") or 0) / 1e6
    if full:
        print(f"  a full charge at this load: {full / ma:.1f} h (A) vs {full / mb:.1f} h (B)")
    spread = max(max(x for x, _ in v) - min(x for x, _ in v) for v in res.values())
    if args.rounds < 2:
        print("  one phase per setting, so no noise estimate: use --rounds 2 or more")
    elif spread >= abs(d):
        print(f"  repeats of the same setting differ by up to {spread:.2f} W, as much as B−A: "
              f"not a real difference yet (try --rounds 4 or --secs 120)")


def main():
    ap = argparse.ArgumentParser(prog="batlog", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("sample", help="sampler daemon")
    s.add_argument("--dir", help=f"output directory (default {SYS_DIR} as root, else {USER_DIR})")
    s.add_argument("--tick", type=float, default=30, help="seconds between samples on battery")
    s.add_argument("--ac-every", type=float, default=300, help="seconds between samples on AC")
    m = sub.add_parser("mark", help="suspend bookkeeping")
    m.add_argument("what", choices=["sleep", "wake"])
    r = sub.add_parser("report", help="summary")
    r.add_argument("-d", "--days", type=float, default=7)
    r.add_argument("--dir", action="append", help="data directory (repeatable)")
    a = sub.add_parser("ab", help="hands-off A/B power test")
    a.add_argument("preset", nargs="?", choices=["refresh", "bitdepth", "blur"])
    a.add_argument("-a", help="command for setting A (your current state; restored at the end)")
    a.add_argument("-b", help="command for setting B")
    a.add_argument("--secs", type=int, default=60, help="measuring time per phase")
    a.add_argument("--settle", type=int, default=15, help="seconds to settle after switching")
    a.add_argument("--rounds", type=int, default=2, help="A/B pairs, run as ABBA")
    a.add_argument("--allow-ac", action="store_true", help=argparse.SUPPRESS)
    args = ap.parse_args()
    {"sample": cmd_sample, "mark": cmd_mark, "report": cmd_report, "ab": cmd_ab}[args.cmd](args)


if __name__ == "__main__":
    main()
