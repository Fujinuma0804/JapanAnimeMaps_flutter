// lib/services/rate_limiter.dart

class RateLimiter {
  final Map<String, DateTime> _lastAccessTimes = {};
  final Duration minInterval = const Duration(minutes: 5);

  bool canAccess(String url) {
    final now = DateTime.now();
    final lastAccess = _lastAccessTimes[url];

    if (lastAccess == null || now.difference(lastAccess) >= minInterval) {
      _lastAccessTimes[url] = now;
      return true;
    }

    return false;
  }

  void trackAccess(String url) {
    _lastAccessTimes[url] = DateTime.now();
  }
}