import 'package:flutter/material.dart';
import '../models/duplicate_contact.dart';
import '../services/contact_service.dart';
import 'contact_results_screen.dart';

class DuplicateDetectionScreen extends StatefulWidget {
  const DuplicateDetectionScreen({super.key});

  @override
  _DuplicateDetectionScreenState createState() => _DuplicateDetectionScreenState();
}

class _DuplicateDetectionScreenState extends State<DuplicateDetectionScreen>
    with TickerProviderStateMixin {
  final ContactService _contactService = ContactService();
  
  bool _isScanning = false;
  bool _hasScanned = false;
  int _totalContacts = 0;
  int _duplicatesFound = 0;
  String _scanStatus = '';
  double _scanProgress = 0.0;
  
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                Expanded(
                  child: _isScanning ? _buildScanningView() : _buildMainView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.people_alt,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AI Duplicate Removal',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Clean up your contacts with intelligent duplicate detection',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMainView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_hasScanned) ...[
          _buildResultsCard(),
          const SizedBox(height: 32),
        ],
        
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.blue.shade600,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: _startScan,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 48,
                            color: Colors.white,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'SCAN',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 32),
        
        Text(
          'Tap to scan your contacts for duplicates',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildFeaturesList(),
      ],
    );
  }

  Widget _buildScanningView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _scanProgress,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 32,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_scanProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        Text(
          'Scanning Contacts...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            _scanStatus,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue.shade800,
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        LinearProgressIndicator(
          value: _scanProgress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
        ),
      ],
    );
  }

  Widget _buildResultsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.contacts,
                label: 'Total Contacts',
                value: _totalContacts.toString(),
                color: Colors.blue,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade300,
              ),
              _buildStatItem(
                icon: Icons.content_copy,
                label: 'Duplicates Found',
                value: _duplicatesFound.toString(),
                color: Colors.orange,
              ),
            ],
          ),
          
          if (_duplicatesFound > 0) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _viewResults,
                icon: const Icon(Icons.visibility),
                label: const Text('View Duplicates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      'Smart AI matching algorithm',
      'Multiple detection strategies',
      'Safe duplicate removal',
      'Contact data preservation',
    ];

    return Column(
      children: features.map((feature) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                feature,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ).toList(),
    );
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _scanStatus = 'Loading contacts...';
    });

    try {
      // Load contacts
      await _updateProgress(0.2, 'Analyzing contacts...');
      
      // Find duplicates
      await _updateProgress(0.5, 'Detecting duplicates...');
      final duplicates = await _contactService.findDuplicatesAdvanced();
      
      await _updateProgress(0.8, 'Processing results...');
      
      // Calculate stats
      final totalContacts = await _contactService.getAllContacts();
      final duplicateCount = duplicates.fold<int>(
        0, (sum, group) => sum + group.length - 1
      );

      await _updateProgress(1.0, 'Scan complete!');
      
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isScanning = false;
        _hasScanned = true;
        _totalContacts = totalContacts.length;
        _duplicatesFound = duplicateCount;
      });

      // Store results for viewing
      _duplicateGroups = duplicates;

    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning contacts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<List<DuplicateContact>> _duplicateGroups = [];

  Future<void> _updateProgress(double progress, String status) async {
    setState(() {
      _scanProgress = progress;
      _scanStatus = status;
    });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _viewResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactResultsScreen(
          duplicates: _duplicateGroups,
        ),
      ),
    );
  }
}