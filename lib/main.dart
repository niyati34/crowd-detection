import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(BusCrowdApp());
}

class BusCrowdApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Crowd Monitor',
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        primaryColor: Color(0xFF1E88E5),
        colorScheme: ColorScheme.light(
          primary: Color(0xFF1E88E5),
          secondary: Color(0xFF03A9F4),
          surface: Colors.white,
          background: Color(0xFFF5F7FA),
        ),
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: BusMonitorScreen(),
    );
  }
}

class BusMonitorScreen extends StatefulWidget {
  @override
  _BusMonitorScreenState createState() => _BusMonitorScreenState();
}

class _BusMonitorScreenState extends State<BusMonitorScreen> with SingleTickerProviderStateMixin {
  final String channelID = "2868765";
  final String readAPIKey = "ZYGG0CQM8PGZI15B";
  final TextEditingController searchController = TextEditingController();
  Map<String, int> busData = {};
  Timer? timer;
  bool isLoading = true;
  DateTime lastUpdated = DateTime.now();
  late TabController _tabController;
  List<String> categories = ['All Buses', 'Available', 'Crowded', 'Overcrowded'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    fetchData();
    timer = Timer.periodic(Duration(seconds: 15), (Timer t) => fetchData());
  }

  @override
  void dispose() {
    timer?.cancel();
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse(
          "https://api.thingspeak.com/channels/$channelID/feeds.json?api_key=$readAPIKey&results=20");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Map<String, int> tempData = {};

        for (var feed in data['feeds']) {
          if (feed['field1'] != null && feed['field2'] != null) {
            String busId = feed['field2'].toString();
            int count = int.tryParse(feed['field1'].toString()) ?? 0;
            tempData[busId] = count;
          }
        }

        setState(() {
          busData = tempData;
          lastUpdated = DateTime.now();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  BusCrowdStatus _getBusStatus(int count) {
    if (count < 15) return BusCrowdStatus.available;
    if (count < 30) return BusCrowdStatus.crowded;
    return BusCrowdStatus.overcrowded;
  }

  List<MapEntry<String, int>> _getFilteredBuses() {
    final filteredBuses = busData.entries.where((entry) {
      final matchesSearch = searchController.text.isEmpty ||
          entry.key.toLowerCase().contains(searchController.text.toLowerCase());

      if (!matchesSearch) return false;

      final status = _getBusStatus(entry.value);

      switch (_tabController.index) {
        case 0: return true; // All buses
        case 1: return status == BusCrowdStatus.available;
        case 2: return status == BusCrowdStatus.crowded;
        case 3: return status == BusCrowdStatus.overcrowded;
        default: return true;
      }
    }).toList();

    filteredBuses.sort((a, b) => a.key.compareTo(b.key));
    return filteredBuses;
  }

  @override
  Widget build(BuildContext context) {
    final filteredBuses = _getFilteredBuses();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchSection(),
              _buildCategoryTabs(),
              _buildBusListSection(filteredBuses),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            fetchData();
          },
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(Icons.refresh, color: Colors.white),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final greeting = _getGreeting();
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Niyati",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  size: 30,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  "Last updated: ${DateFormat('HH:mm').format(lastUpdated)}",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isLoading) ...[
                  Spacer(),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: "Search bus by number...",
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      height: 50,
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {});
        },
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColor,
        ),
        tabs: [
          _buildTab("All Buses", busData.length),
          _buildTab(
            "Available",
            busData.values.where((count) => count < 15).length,
            Colors.green,
          ),
          _buildTab(
            "Crowded",
            busData.values.where((count) => count >= 15 && count < 30).length,
            Colors.orange,
          ),
          _buildTab(
            "Overcrowded",
            busData.values.where((count) => count >= 30).length,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int count, [Color? dotColor]) {
    return Tab(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text),
            SizedBox(width: 5),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: dotColor != null
                    ? dotColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: dotColor ?? Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusListSection(List<MapEntry<String, int>> filteredBuses) {
    if (isLoading && busData.isEmpty) {
      return Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (filteredBuses.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_bus_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              SizedBox(height: 16),
              Text(
                "No buses found",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Try a different search term",
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: filteredBuses.length,
        itemBuilder: (context, index) {
          final entry = filteredBuses[index];
          final status = _getBusStatus(entry.value);
          return _buildBusCard(entry.key, entry.value, status);
        },
      ),
    );
  }

  Widget _buildBusCard(String busId, int count, BusCrowdStatus status) {
    final statusData = getBusStatusData(status);

    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: statusData.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bus status indicator
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: statusData.color,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusData.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    statusData.icon,
                    color: statusData.color,
                    size: 32,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Bus $busId",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusData.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusData.label,
                              style: TextStyle(
                                color: statusData.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            "$count passengers",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildCapacityIndicator(count, status),
        ],
      ),
    );
  }

  Widget _buildCapacityIndicator(int count, BusCrowdStatus status) {
    final statusData = getBusStatusData(status);
    final double percentage = count / 45 * 100; // Assuming max capacity of 45
    final cappedPercentage = percentage > 100 ? 100 : percentage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Capacity",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                "${cappedPercentage.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusData.color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: cappedPercentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusData.color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  BusStatusData getBusStatusData(BusCrowdStatus status) {
    switch (status) {
      case BusCrowdStatus.available:
        return BusStatusData(
          color: Colors.green,
          shadowColor: Colors.green.withOpacity(0.15),
          icon: Icons.directions_bus_outlined,
          label: 'Available',
        );
      case BusCrowdStatus.crowded:
        return BusStatusData(
          color: Colors.orange,
          shadowColor: Colors.orange.withOpacity(0.15),
          icon: Icons.directions_bus,
          label: 'Crowded',
        );
      case BusCrowdStatus.overcrowded:
        return BusStatusData(
          color: Colors.red,
          shadowColor: Colors.red.withOpacity(0.15),
          icon: Icons.bus_alert,
          label: 'Overcrowded',
        );
    }
  }
}

enum BusCrowdStatus {
  available,
  crowded,
  overcrowded,
}

class BusStatusData {
  final Color color;
  final Color shadowColor;
  final IconData icon;
  final String label;

  BusStatusData({
    required this.color,
    required this.shadowColor,
    required this.icon,
    required this.label,
  });
}