import 'dart:math';

/// Longest a failing host is left alone between polls.
///
/// Capped rather than unbounded so a host that recovers after a long outage is
/// still noticed within a few minutes. The cap only applies to intervals below
/// it: an interval that is already rarer than the cap is its own floor.
const Duration maxPollBackoff = Duration(minutes: 5);

/// Delay before the next poll after [failures] consecutive failures.
///
/// Doubles per failure from [interval] and is capped at [maxPollBackoff], but
/// never drops below [interval] — a host that is down must not be polled more
/// often than a healthy one. The result is then spread by up to 100%: many
/// devices that fail together — a host going down takes them all at once —
/// would otherwise come back as a single burst. [failures] of 0 returns
/// [interval] unchanged, which is the healthy path.
Duration pollBackoffDelay(Duration interval, int failures, {Random? random}) {
  if (failures <= 0) return interval;

  // Beyond 2^30 the doubling is pointless: the cap has taken over long before,
  // and shifting further would overflow on the web's 32-bit ints.
  final exponent = min(failures - 1, 30);
  // Compare before multiplying. Duration holds microseconds in a 64-bit int,
  // which wraps silently: Duration(hours: 3) * (1 << 30) is negative, a
  // negative delay passes the cap check and Timer fires it immediately, so a
  // long outage would turn the loop into back-to-back requests.
  final capped =
      interval.inMicroseconds > (maxPollBackoff.inMicroseconds >> exponent)
          ? maxPollBackoff
          : interval * (1 << exponent);
  final floored = capped < interval ? interval : capped;

  final jitter = (random ?? Random()).nextDouble();
  return floored * (1 + jitter);
}
