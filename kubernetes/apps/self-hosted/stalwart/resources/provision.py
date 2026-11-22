#!/usr/bin/env python3
"""Idempotently create the DAV collections Stalwart does not create on its own.

Owner gets plan/praca/prywatne (VEVENT), todo (VTODO), notatki (VJOURNAL) and the
kontakty address book. Moodle stays a client-side iCal subscription.
"""
import base64
import logging
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

NS = {"d": "DAV:", "c": "urn:ietf:params:xml:ns:caldav", "a": "http://apple.com/ns/ical/"}

OWNER_CALENDARS = {
    "plan": ("Plan", ["VEVENT"], "#1E88E5"),
    "praca": ("Praca", ["VEVENT"], "#F4511E"),
    "prywatne": ("Prywatne", ["VEVENT"], "#33B679"),
    "todo": ("Todo", ["VTODO"], "#8E24AA"),
    "notatki": ("Notatki", ["VJOURNAL"], "#F6BF26"),
}

log = logging.getLogger("provision")


class Dav:
    def __init__(self, base: str, user: str, password: str):
        self.base = base.rstrip("/")
        self.user = user
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        self.auth = f"Basic {token}"

    def request(self, method: str, path: str, body: str | None = None, depth: str | None = None):
        req = urllib.request.Request(self.base + path, method=method, data=body.encode() if body else None)
        req.add_header("Authorization", self.auth)
        if body:
            req.add_header("Content-Type", "application/xml; charset=utf-8")
        if depth is not None:
            req.add_header("Depth", depth)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as err:
            return err.code, err.read()

    def home(self, kind: str) -> str:
        prop = "c:calendar-home-set" if kind == "cal" else "card:addressbook-home-set"
        body = (
            '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" '
            f'xmlns:card="urn:ietf:params:xml:ns:carddav"><d:prop><{prop}/></d:prop></d:propfind>'
        )
        status, data = self.request("PROPFIND", f"/dav/{kind}/", body, depth="0")
        if status != 207:
            raise RuntimeError(f"{self.user}: PROPFIND /dav/{kind}/ returned {status}")
        href = ET.fromstring(data).find(".//{*}" + prop.split(":")[1] + "/{DAV:}href")
        return href.text

    def children(self, home: str) -> set[str]:
        status, data = self.request("PROPFIND", home, '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>', depth="1")
        if status != 207:
            raise RuntimeError(f"{self.user}: PROPFIND {home} returned {status}")
        own = urllib.parse.unquote(home).rstrip("/")
        names = set()
        for href in ET.fromstring(data).iterfind(".//{DAV:}response/{DAV:}href"):
            path = urllib.parse.unquote(href.text).rstrip("/")
            if path != own:
                names.add(path.rsplit("/", 1)[-1])
        return names

    def ensure_calendar(self, home: str, name: str, display: str, components: list[str], color: str) -> None:
        comps = "".join(f'<c:comp name="{c}"/>' for c in components)
        props = f"<d:displayname>{display}</d:displayname><a:calendar-color>{color}</a:calendar-color>"
        if name in self.children(home):
            # Keep display name and colour converged; components cannot change after creation.
            body = f'<?xml version="1.0"?><d:propertyupdate xmlns:d="DAV:" xmlns:a="{NS["a"]}"><d:set><d:prop>{props}</d:prop></d:set></d:propertyupdate>'
            status, _ = self.request("PROPPATCH", f"{home}{name}/", body)
            log.info("%s: calendar %s exists (proppatch %s)", self.user, name, status)
            return
        body = (
            f'<?xml version="1.0"?><c:mkcalendar xmlns:d="DAV:" xmlns:c="{NS["c"]}" xmlns:a="{NS["a"]}">'
            f"<d:set><d:prop>{props}<c:supported-calendar-component-set>{comps}</c:supported-calendar-component-set>"
            "</d:prop></d:set></c:mkcalendar>"
        )
        status, data = self.request("MKCALENDAR", f"{home}{name}/", body)
        if status != 201:
            raise RuntimeError(f"{self.user}: MKCALENDAR {name} returned {status}: {data[:300]!r}")
        log.info("%s: created calendar %s %s", self.user, name, components)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    base = os.environ["DAV_URL"]
    owner = Dav(base, os.environ["OWNER_USER"], os.environ["OWNER_PASSWORD"])

    cal_home = owner.home("cal")
    for name, (display, comps, color) in OWNER_CALENDARS.items():
        owner.ensure_calendar(cal_home, name, display, comps, color)
    # Listing the address book home makes Stalwart create the default "kontakty" book.
    log.info("%s: address books %s", owner.user, sorted(owner.children(owner.home("card"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
