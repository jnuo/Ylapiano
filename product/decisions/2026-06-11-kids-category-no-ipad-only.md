# Decision: Kids Category = NO · iPad-only stays

**Date:** 2026-06-11 · **Status:** LOCKED — explicitly confirmed by Onur
(2026-06-11, after veto window offered) · **Card:** B18 (#26)

## Kids Category = NO (file standard 4+ instead)

1. **One-way door.** Apple allows opting INTO the Kids Category later, but
   effectively never out of it. Filing 4+ keeps the option; filing Kids burns
   it before launch teaches us anything.
2. **Permanent rule bundle.** Kids apps must parental-gate every external
   link, may never add third-party analytics/ads SDKs, and face stricter
   review on every update — forever. v1 happens to comply today, but the
   bundle binds future choices for no gain.
3. **Kids tab skews free.** v1 launches paid (~€1). The Kids shelf's
   discovery is dominated by free titles — we'd take the constraints without
   the discovery upside.

The app remains genuinely kid-safe regardless: 4+ rating, no ads, no
tracking, Data Not Collected, no mic, fully offline. Kids Category is shelf
placement + rules, not the age rating.

**Revisit trigger:** if post-launch acquisition stalls AND the price model
moves to free + paid unlock, re-evaluate the Kids shelf with eyes open about
the one-way door.

## iPad-only stays (TARGETED_DEVICE_FAMILY=2)

- The game's core layout (15 white keys + falling lanes at kid-finger size)
  needs iPad width; a usable iPhone layout would be a redesign, not a port.
- One device family = one screenshot set, one layout to test with kids,
  fewer review surfaces for v1.
- `store-config.md`'s iPhone 6.7" screenshot plan is superseded by this
  decision (B20/#20 fixes store config accordingly).

**Revisit trigger:** v1.1+ if TestFlight parents ask for iPhone, weigh a
phone-specific "mini keyboard" mode as its own design effort.
