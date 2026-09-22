import 'dart:math';

/// Longest a failing host is left alone between polls.
///
/// Capped rather than unbounded so a host that recovers after a long outage is
/// still noticed within a few minutes.
const Duration maxPollBackoff = Duration(minutes: 5);

/// Delay before the next poll after [failures] consecutive failures.
///
/// Doubles per failure from [interval], capped at [maxPollBackoff], then spread
/// by up to 100% of the result: many devices that fail together — a host going
/// down takes them all at once — would otherwise come back as a single burst.
/// [failures] of 0 returns [interval] unchanged, which is the healthy path.
Duration pollBackoffDelay(Duration interval, int failures, {Random? random}) {
  if (failures <= 0) return interval;

  // Beyond 2^30 the multiplication is pointless: the cap has taken over long
  // before, and shifting further would overflow on the web's 32-bit ints.
  final exponent = min(failures - 1, 30);
  final backoff = interval * (1 << exponent);
  final capped = backoff > maxPollBackoff ? maxPollBackoff : backoff;

  final jitter = (random ?? Random()).nextDouble();
  return capped * (1 + jitter);
}
