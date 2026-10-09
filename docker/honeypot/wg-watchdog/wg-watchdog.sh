#!/bin/sh
# Restart the tunnel when its last handshake goes stale.
#
# wg-quick resolves the peer hostname once, at interface start, and the
# interface stays "up" whether or not anything reaches the far side. After the
# home router rebooted on 2026-10-09 the honeypot kept an interface that looked
# healthy while the router received nothing at all, and nothing recovered it --
# admin SSH is bound to this tunnel, so that cost a provider-console trip.
set -eu

IFACE="${IFACE:-wg1}"
MAX_AGE="${MAX_AGE:-300}"      # seconds since the last handshake
MIN_GAP="${MIN_GAP:-300}"      # seconds between restarts, so a genuinely
                               # unreachable peer is not hammered
STAMP="/run/wg-watchdog-${IFACE}.last"

handshake="$(wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{print $2; exit}')"
[ -n "${handshake:-}" ] || { echo "no peer on ${IFACE}"; exit 0; }

now="$(date +%s)"
# A peer that has never completed a handshake reports 0; treat it as stale.
if [ "$handshake" -eq 0 ]; then
    age="$MAX_AGE"
else
    age=$(( now - handshake ))
fi

[ "$age" -gt "$MAX_AGE" ] || exit 0

if [ -r "$STAMP" ]; then
    last="$(cat "$STAMP")"
    [ $(( now - last )) -ge "$MIN_GAP" ] || exit 0
fi

echo "$now" > "$STAMP"
echo "handshake on ${IFACE} is ${age}s old, restarting wg-quick@${IFACE}"
systemctl restart "wg-quick@${IFACE}"
