import 'package:flutter/material.dart';

/// Timezone Selection Screen
/// Allows users to select their timezone or use device default
/// Can also be auto-populated from Google Calendar settings
class TimezoneScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool isOnboarding;
  final String? currentTimezone;
  final Function(String?) onTimezoneSelected;

  const TimezoneScreen({
    super.key,
    required this.onContinue,
    required this.onTimezoneSelected,
    this.onBack,
    this.onSkip,
    this.isOnboarding = true,
    this.currentTimezone,
  });

  @override
  State<TimezoneScreen> createState() => _TimezoneScreenState();
}

class _TimezoneScreenState extends State<TimezoneScreen> {
  String? _selectedTimezone;
  bool _useDeviceTimezone = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Common timezones grouped by region
  static const Map<String, List<_TimezoneOption>> _timezonesByRegion = {
    'Americas': [
      _TimezoneOption('America/New_York', 'Eastern Time', 'EST/EDT'),
      _TimezoneOption('America/Chicago', 'Central Time', 'CST/CDT'),
      _TimezoneOption('America/Denver', 'Mountain Time', 'MST/MDT'),
      _TimezoneOption('America/Los_Angeles', 'Pacific Time', 'PST/PDT'),
      _TimezoneOption('America/Phoenix', 'Arizona', 'MST'),
      _TimezoneOption('America/Anchorage', 'Alaska', 'AKST/AKDT'),
      _TimezoneOption('Pacific/Honolulu', 'Hawaii', 'HST'),
      _TimezoneOption('America/Toronto', 'Toronto', 'EST/EDT'),
      _TimezoneOption('America/Vancouver', 'Vancouver', 'PST/PDT'),
      _TimezoneOption('America/Mexico_City', 'Mexico City', 'CST/CDT'),
      _TimezoneOption('America/Sao_Paulo', 'São Paulo', 'BRT'),
      _TimezoneOption('America/Buenos_Aires', 'Buenos Aires', 'ART'),
    ],
    'Europe': [
      _TimezoneOption('Europe/London', 'London', 'GMT/BST'),
      _TimezoneOption('Europe/Paris', 'Paris', 'CET/CEST'),
      _TimezoneOption('Europe/Berlin', 'Berlin', 'CET/CEST'),
      _TimezoneOption('Europe/Amsterdam', 'Amsterdam', 'CET/CEST'),
      _TimezoneOption('Europe/Rome', 'Rome', 'CET/CEST'),
      _TimezoneOption('Europe/Madrid', 'Madrid', 'CET/CEST'),
      _TimezoneOption('Europe/Moscow', 'Moscow', 'MSK'),
      _TimezoneOption('Europe/Istanbul', 'Istanbul', 'TRT'),
    ],
    'Asia & Pacific': [
      _TimezoneOption('Asia/Tokyo', 'Tokyo', 'JST'),
      _TimezoneOption('Asia/Shanghai', 'Shanghai', 'CST'),
      _TimezoneOption('Asia/Hong_Kong', 'Hong Kong', 'HKT'),
      _TimezoneOption('Asia/Singapore', 'Singapore', 'SGT'),
      _TimezoneOption('Asia/Seoul', 'Seoul', 'KST'),
      _TimezoneOption('Asia/Kolkata', 'India', 'IST'),
      _TimezoneOption('Asia/Dubai', 'Dubai', 'GST'),
      _TimezoneOption('Australia/Sydney', 'Sydney', 'AEST/AEDT'),
      _TimezoneOption('Australia/Melbourne', 'Melbourne', 'AEST/AEDT'),
      _TimezoneOption('Pacific/Auckland', 'Auckland', 'NZST/NZDT'),
    ],
    'Africa': [
      _TimezoneOption('Africa/Cairo', 'Cairo', 'EET'),
      _TimezoneOption('Africa/Johannesburg', 'Johannesburg', 'SAST'),
      _TimezoneOption('Africa/Lagos', 'Lagos', 'WAT'),
      _TimezoneOption('Africa/Nairobi', 'Nairobi', 'EAT'),
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedTimezone = widget.currentTimezone;
    _useDeviceTimezone = widget.currentTimezone == null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_TimezoneOption> get _filteredTimezones {
    final allTimezones = <_TimezoneOption>[];
    for (final region in _timezonesByRegion.values) {
      allTimezones.addAll(region);
    }

    if (_searchQuery.isEmpty) {
      return allTimezones;
    }

    final query = _searchQuery.toLowerCase();
    return allTimezones.where((tz) {
      return tz.id.toLowerCase().contains(query) ||
          tz.name.toLowerCase().contains(query) ||
          tz.abbreviation.toLowerCase().contains(query);
    }).toList();
  }

  void _selectTimezone(String? timezoneId) {
    setState(() {
      if (timezoneId == null) {
        _useDeviceTimezone = true;
        _selectedTimezone = null;
      } else {
        _useDeviceTimezone = false;
        _selectedTimezone = timezoneId;
      }
    });
  }

  void _saveAndContinue() {
    widget.onTimezoneSelected(_useDeviceTimezone ? null : _selectedTimezone);
    widget.onContinue();
  }

  String get _deviceTimezone {
    return DateTime.now().timeZoneName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Your Timezone',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We\'ll use this to show times correctly and sync with your calendar.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Device timezone option
                    _buildDeviceTimezoneOption(),

                    const SizedBox(height: 24),

                    // Divider with "or"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or select manually',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Search
                    _buildSearchField(),

                    const SizedBox(height: 24),

                    // Timezone list
                    if (_searchQuery.isNotEmpty)
                      _buildSearchResults()
                    else
                      _buildGroupedTimezones(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Continue button
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 48),
          if (widget.isOnboarding)
            Text(
              'Step 3 of 4',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(
                'Skip',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildDeviceTimezoneOption() {
    final isSelected = _useDeviceTimezone;

    return InkWell(
      onTap: () => _selectTimezone(null),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.smartphone,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Device Timezone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Currently: $_deviceTimezone',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white)
            else
              Icon(Icons.circle_outlined, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search timezones...',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _filteredTimezones;

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No timezones found',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return Column(
      children: results.map((tz) => _buildTimezoneItem(tz)).toList(),
    );
  }

  Widget _buildGroupedTimezones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _timezonesByRegion.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...entry.value.map((tz) => _buildTimezoneItem(tz)),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTimezoneItem(_TimezoneOption timezone) {
    final isSelected = !_useDeviceTimezone && _selectedTimezone == timezone.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _selectTimezone(timezone.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timezone.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timezone.id,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  timezone.abbreviation,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 12),
                const Icon(Icons.check, color: Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _saveAndContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Continue',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Timezone option for display
class _TimezoneOption {
  final String id;
  final String name;
  final String abbreviation;

  const _TimezoneOption(this.id, this.name, this.abbreviation);
}
