# Location policy — keeper

## Forbidden as trust (weight = 0)

- Public IPv4/IPv6 assigned by ISP
- ASN / “ISP name”
- GeoIP country/city databases

**Why (especially India):** CGNAT, mobile IP churn, shared NATs, VPN, and city-level GeoIP errors cause both false deny and false trust. IP is not place and is not a secret.

## Allowed (future factors; not required in MVP CLI)

- Live **GPS/GNSS** fix with quality gates (`accuracy_m`, freshness)
- **Frequent trusted places** (operator-enrolled geofences: home, parents, Stockholm base)
- Match: `haversine(fix, place) ≤ radius` — never GeoIP

## MVP behavior

This release does **not** implement GPS enrollment. Location is documented so implementers never wire IP trust by accident. Tests assert docs forbid ISP/public IP as trust.

## Future share S6

When implemented: sealed share released only when GPS ∈ trusted frequent place; travel mode and S6 waive with yellow status.
