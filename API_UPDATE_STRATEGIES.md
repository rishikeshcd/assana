# API Update Strategies for ASSANA App

## Understanding REST APIs

REST APIs are **stateless** and work on a **request-response** model:
- Client sends a request → Server responds with data
- Server does NOT push updates automatically
- Client must actively request data to get updates

---

## Update Strategies

### 1. **Pull-to-Refresh** (Recommended for most cases)
User manually refreshes data by pulling down.

**When to use:**
- Appointments list
- Surgeries list
- Consultations list
- Dashboard stats

**Implementation:**
```dart
RefreshIndicator(
  onRefresh: () async {
    await _loadData();
  },
  child: ListView(...),
)
```

---

### 2. **Automatic Polling** (For time-sensitive data)
App automatically fetches data at regular intervals.

**When to use:**
- Dashboard statistics (every 30-60 seconds)
- Active surgeries (every 30 seconds)
- Upcoming appointments (every 1-2 minutes)

**Implementation:**
```dart
Timer.periodic(Duration(seconds: 30), (timer) {
  _refreshData();
});
```

**Considerations:**
- ⚠️ Uses battery and data
- ⚠️ Increases server load
- ✅ Good for critical real-time data

---

### 3. **On Screen Focus** (Recommended)
Refresh data when user navigates to a screen.

**When to use:**
- All list screens
- Dashboard
- Profile page

**Implementation:**
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (ModalRoute.of(context)?.isCurrent ?? false) {
    _loadData();
  }
}
```

---

### 4. **WebSockets** (For real-time updates)
Persistent connection for instant updates.

**When to use:**
- Live surgery status updates
- Real-time appointment changes
- Instant notifications

**Implementation:**
```dart
// Requires WebSocket server
WebSocket.connect('wss://api.assana.com/ws')
  ..listen((message) {
    // Handle real-time updates
  });
```

**Considerations:**
- ✅ Real-time updates
- ✅ Efficient for frequent changes
- ⚠️ More complex to implement
- ⚠️ Requires WebSocket server

---

### 5. **Push Notifications** (For important events)
Server sends notifications, app refreshes on notification.

**When to use:**
- New appointment scheduled
- Surgery status changed
- Important alerts

**Implementation:**
```dart
FirebaseMessaging.onMessage.listen((message) {
  // Refresh relevant data
  _refreshAppointments();
});
```

---

## Recommended Strategy for ASSANA App

### **Hybrid Approach:**

1. **On Screen Focus** - Refresh when user opens a screen
   - Home/Dashboard
   - Surgeries
   - Meet/Consultations
   - Settings

2. **Pull-to-Refresh** - Manual refresh option
   - All list screens
   - Dashboard

3. **Automatic Polling** - For critical data only
   - Active surgeries (every 30 seconds)
   - Today's appointments (every 1 minute)

4. **Push Notifications** - For important events
   - New appointments
   - Surgery status changes
   - Meeting reminders

---

## Implementation Example

### API Service with Refresh Strategy

```dart
class ApiService {
  static const String baseUrl = 'https://api.assana.com/v1';
  
  // Cache duration
  static const Duration cacheDuration = Duration(minutes: 1);
  
  // Last fetch times
  static final Map<String, DateTime> _lastFetch = {};
  
  // Check if data needs refresh
  static bool _needsRefresh(String endpoint) {
    final lastFetch = _lastFetch[endpoint];
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) > cacheDuration;
  }
  
  // Get appointments with smart refresh
  static Future<List<Appointment>> getAppointments({
    bool forceRefresh = false,
  }) async {
    final endpoint = '/appointments';
    
    // Check cache first (if not forcing refresh)
    if (!forceRefresh && !_needsRefresh(endpoint)) {
      return _getCachedAppointments();
    }
    
    // Fetch from API
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _lastFetch[endpoint] = DateTime.now();
      _cacheAppointments(data);
      return _parseAppointments(data);
    }
    
    // If API fails, return cached data
    return _getCachedAppointments();
  }
}
```

---

## Best Practices

### 1. **Cache Data Locally**
- Store API responses in SharedPreferences or local database
- Show cached data immediately
- Refresh in background
- Update UI when new data arrives

### 2. **Show Loading States**
```dart
bool _isLoading = false;
bool _isRefreshing = false;

// Initial load
_isLoading = true;
await _loadData();
_isLoading = false;

// Refresh
_isRefreshing = true;
await _refreshData();
_isRefreshing = false;
```

### 3. **Handle Offline Mode**
- Check internet connection
- Show cached data if offline
- Queue updates for when online
- Show offline indicator

### 4. **Optimize API Calls**
- Don't refresh too frequently
- Use pagination for large lists
- Only fetch changed data when possible
- Use ETags/Last-Modified headers

### 5. **User Experience**
- Show last updated time
- Provide manual refresh option
- Show loading indicators
- Handle errors gracefully

---

## Example: Home Page with Smart Refresh

```dart
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Refresh when screen becomes visible
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _refreshData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final appointments = await ApiService.getAppointments();
      setState(() {
        _appointments = appointments;
        _lastRefresh = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Show error
    }
  }

  Future<void> _refreshData() async {
    try {
      final appointments = await ApiService.getAppointments(
        forceRefresh: true,
      );
      setState(() {
        _appointments = appointments;
        _lastRefresh = DateTime.now();
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          children: [
            // Last updated indicator
            if (_lastRefresh != null)
              Text('Last updated: ${_formatTime(_lastRefresh!)}'),
            
            // Appointments list
            ..._appointments.map((apt) => AppointmentCard(apt)),
          ],
        ),
      ),
    );
  }
}
```

---

## Summary

**For ASSANA App, use:**
1. ✅ **On Screen Focus** - Refresh when user opens screen
2. ✅ **Pull-to-Refresh** - Manual refresh option
3. ✅ **Local Caching** - Show cached data immediately
4. ⚠️ **Polling** - Only for critical real-time data (active surgeries)
5. 🔮 **Future: WebSockets** - For real-time updates when needed

**Key Points:**
- REST APIs don't push updates automatically
- Client must request data to get updates
- Use caching to improve UX
- Refresh strategically to balance freshness and performance
- Always provide manual refresh option

