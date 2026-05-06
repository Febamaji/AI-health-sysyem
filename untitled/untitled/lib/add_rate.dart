import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class AppRatingPage extends StatefulWidget {
  const AppRatingPage({
    super.key,
  });

  @override
  State<AppRatingPage> createState() => _AppRatingPageState();
}

class _AppRatingPageState extends State<AppRatingPage> {
  List<dynamic> _appRatings = [];
  bool _isLoading = true;
  bool _hasError = false;
  double _overallRating = 0.0;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _loadAppRatings();
  }

  Future<void> _loadAppRatings() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String lid = prefs.getString("lid") ?? "";

    if (url.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$url/view_app_ratings/?lid=$lid'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _appRatings = data['data'];
            _calculateOverallStats();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print("Error loading app ratings: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _calculateOverallStats() {
    if (_appRatings.isEmpty) {
      _overallRating = 0.0;
      _totalRatings = 0;
      return;
    }

    double total = 0;
    for (var rating in _appRatings) {
      total += double.parse(rating['rating'].toString());
    }
    _overallRating = total / _appRatings.length;
    _totalRatings = _appRatings.length;
  }

  Future<bool> _hasUserRated() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String lid = prefs.getString("lid") ?? "";
    return _appRatings.any((rating) => rating['patient_id'] == lid);
  }

  void _showAddRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAppRatingDialog(
        onRatingSubmitted: _loadAppRatings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FDF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1B5E20),
        elevation: 2,
        title: Text(
          'Rate Our App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _loadAppRatings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading ratings...',
              style: TextStyle(
                color: Color(0xFF1B5E20),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load ratings',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadAppRatings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // App Header Section
          _buildAppHeader(),
          SizedBox(height: 24),

          // Overall Rating Section
          _buildOverallRating(),
          SizedBox(height: 24),

          // Rate App Button
          _buildRateAppButton(),
          SizedBox(height: 24),

          // App Store Buttons
          // _buildStoreButtons(),
          SizedBox(height: 24),

          // Reviews Section
          _buildReviewsSection(),
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.medical_services_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MindCare Connect',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your Health Companion App',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallRating() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Overall Rating',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _overallRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStarRating(_overallRating, 28),
                    SizedBox(height: 8),
                    Text(
                      '$_totalRatings ${_totalRatings == 1 ? 'Rating' : 'Ratings'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            // Rating Distribution
            _buildRatingDistribution(),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDistribution() {
    Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var rating in _appRatings) {
      int star = int.parse(rating['rating'].toString());
      ratingCounts[star] = (ratingCounts[star] ?? 0) + 1;
    }

    return Column(
      children: List.generate(5, (index) {
        int star = 5 - index;
        int count = ratingCounts[star] ?? 0;
        double percentage = _totalRatings > 0 ? (count / _totalRatings) * 100 : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                '$star',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRateAppButton() {
    return FutureBuilder<bool>(
      future: _hasUserRated(),
      builder: (context, snapshot) {
        bool hasRated = snapshot.data ?? false;

        return Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _showAddRatingDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, size: 24),
                SizedBox(width: 12),
                Text(
                  hasRated ? 'UPDATE YOUR RATING' : 'RATE OUR APP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget _buildStoreButtons() {
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(16),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(20),
  //       child: Column(
  //         children: [
  //           // Text(
  //           //   'Rate us on app stores',
  //           //   style: TextStyle(
  //           //     fontSize: 18,
  //           //     fontWeight: FontWeight.bold,
  //           //     color: Color(0xFF1B5E20),
  //           //   ),
  //           // ),
  //           SizedBox(height: 16),
  //           // Row(
  //           //   children: [
  //           //     Expanded(
  //           //       child: OutlinedButton.icon(
  //           //         onPressed: () => _launchAppStore(),
  //           //         style: OutlinedButton.styleFrom(
  //           //           foregroundColor: Colors.black,
  //           //           side: BorderSide(color: Colors.grey),
  //           //           shape: RoundedRectangleBorder(
  //           //             borderRadius: BorderRadius.circular(12),
  //           //           ),
  //           //           padding: EdgeInsets.symmetric(vertical: 12),
  //           //         ),
  //           //         icon: Icon(Icons.apple_rounded),
  //           //         label: Text('App Store'),
  //           //       ),
  //           //     ),
  //           //     SizedBox(width: 12),
  //           //     Expanded(
  //           //       child: OutlinedButton.icon(
  //           //         onPressed: () => _launchPlayStore(),
  //           //         style: OutlinedButton.styleFrom(
  //           //           foregroundColor: Colors.black,
  //           //           side: BorderSide(color: Colors.grey),
  //           //           shape: RoundedRectangleBorder(
  //           //             borderRadius: BorderRadius.circular(12),
  //           //           ),
  //           //           padding: EdgeInsets.symmetric(vertical: 12),
  //           //         ),
  //           //         icon: Icon(Icons.android_rounded),
  //           //         label: Text('Play Store'),
  //           //       ),
  //           //     ),
  //           //   ],
  //           // ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildReviewsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.reviews_rounded, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'User Reviews',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Spacer(),
                Text(
                  '$_totalRatings reviews',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            if (_appRatings.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.reviews_outlined, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No Reviews Yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Be the first to rate our app!',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _appRatings.take(10).map((rating) => _buildReviewItem(rating)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> rating) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStarRating(double.parse(rating['rating'].toString()), 16),
              Spacer(),
              Text(
                _formatDate(rating['created_at']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (rating['review'] != null && rating['review'].isNotEmpty)
            Text(
              rating['review'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          SizedBox(height: 8),
          Text(
            'User ${rating['patient_name']}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star_rounded :
          (index < rating.ceil() ? Icons.star_half_rounded : Icons.star_border_rounded),
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _launchAppStore() async {
    const url = 'https://apps.apple.com/app/your-app-id';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      Fluttertoast.showToast(
        msg: 'Could not launch App Store',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _launchPlayStore() async {
    const url = 'https://play.google.com/store/apps/details?id=your.package.name';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      Fluttertoast.showToast(
        msg: 'Could not launch Play Store',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }
}

// Add App Rating Dialog
class AddAppRatingDialog extends StatefulWidget {
  final VoidCallback onRatingSubmitted;

  const AddAppRatingDialog({
    super.key,
    required this.onRatingSubmitted,
  });

  @override
  State<AddAppRatingDialog> createState() => _AddAppRatingDialogState();
}

class _AddAppRatingDialogState extends State<AddAppRatingDialog> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400), // Add max width constraint
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber, size: 28), // Increased icon size
                  SizedBox(width: 12),
                  Expanded( // Wrap text in Expanded to prevent overflow
                    child: Text(
                      'Rate MindCare Connect',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'How would you rate your experience with our app?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 20),

              // Star Rating - Fixed size
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 50, // Fixed height for star row
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            onPressed: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                            icon: Icon(
                              index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 30, // Increased star size
                            ),
                            padding: EdgeInsets.all(8), // Added padding
                            constraints: BoxConstraints(
                              minWidth: 48, // Minimum tap area
                              minHeight: 48,
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _rating == 0 ? 'Tap to rate' : '$_rating out of 5 stars',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Review Text
              TextFormField(
                controller: _reviewController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Your Review (Optional)',
                  hintText: 'Tell us what you like about the app or how we can improve...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF2E7D32),
                        side: BorderSide(color: Color(0xFF2E7D32)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14), // Increased padding
                      ),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting || _rating == 0 ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14), // Increased padding
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        'SUBMIT RATING',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmitting = true;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String lid = prefs.getString("lid") ?? "";

    try {
      final response = await http.post(
        Uri.parse('$url/add_app_rating/'),
        body: {
          'patient_id': lid,
          'rating': _rating.toString(),
          'review': _reviewController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          Fluttertoast.showToast(
            msg: 'Thank you for your rating!',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          widget.onRatingSubmitted();
          Navigator.pop(context);
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to submit rating',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error submitting rating',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}