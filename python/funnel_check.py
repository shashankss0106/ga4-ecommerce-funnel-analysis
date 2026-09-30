#!/usr/bin/env python3
"""Same checks as funnel_check.py but uses ONLY the Python standard library (no pandas).
Usage: python funnel_check.py overall.csv segments.csv weekly.csv"""
import csv, sys

MIN_SESSIONS = 1000
STEPS = [("pct_session_to_view", "session -> view item"), ("pct_view_to_cart", "view -> add to cart"),
         ("pct_cart_to_checkout", "cart -> checkout"), ("pct_checkout_to_purchase", "checkout -> purchase")]
COUNTS = ["sessions", "viewed_item", "added_to_cart", "began_checkout", "purchased"]

def read(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        for k, v in r.items():
            try:
                r[k] = float(v) if v not in ("", None) else None
            except ValueError:
                pass   # keep text columns (dimension, segment, week_start)
    return rows

def main(overall_p, seg_p, weekly_p):
    o, s, w = read(overall_p)[0], read(seg_p), read(weekly_p)

    for dim in sorted({r["dimension"] for r in s}):
        g = [r for r in s if r["dimension"] == dim]
        for c in COUNTS:
            tot = sum(r[c] for r in g)
            assert tot == o[c], f"{dim}: {c} sums to {tot:,.0f} but overall is {o[c]:,.0f}"
    print("OK: channel, device and user-type tables all add up to the overall funnel.")
    pwc = o["purchases_without_checkout_event"]
    print(f"Purchases with no checkout event: {pwc:,.0f} ({100*pwc/o['purchased']:.1f}% of purchases) - data-quality caveat.")

    print(f"\nOverall: {o['sessions']:,.0f} sessions -> {o['purchased']:,.0f} purchases ({o['pct_session_to_purchase']:.2f}%)")
    for col, name in STEPS:
        print(f"  {name}: {o[col]:.1f}% continue")
    worst = min(STEPS[1:], key=lambda x: o[x[0]])
    print(f"Biggest leak among shopping steps: {worst[1]} ({100-o[worst[0]]:.1f}% lost)")

    for dim in sorted({r["dimension"] for r in s}):
        g = sorted([r for r in s if r["dimension"] == dim and r["sessions"] >= MIN_SESSIONS],
                   key=lambda r: r["pct_session_to_purchase"], reverse=True)
        if not g:
            continue
        print(f"\n{dim}: best {g[0]['segment']} {g[0]['pct_session_to_purchase']:.2f}% | "
              f"worst {g[-1]['segment']} {g[-1]['pct_session_to_purchase']:.2f}% (session->purchase)")
        for r in g:
            leak = min(STEPS[1:], key=lambda x: r[x[0]])
            print(f"   {str(r['segment']):<16} {r['sessions']:>9,.0f} sessions  conv {r['pct_session_to_purchase']:5.2f}%  biggest leak: {leak[1]}")

    w = w[1:]   # skip the partial first week
    top = max(w, key=lambda r: r["pct_session_to_purchase"])
    print(f"\nHighest weekly conversion: week of {top['week_start']} at {top['pct_session_to_purchase']:.2f}%")

if __name__ == "__main__":
    main(*sys.argv[1:4])
