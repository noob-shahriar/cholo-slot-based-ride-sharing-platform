import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

class VerificationRequestsListPage extends StatefulWidget {
  const VerificationRequestsListPage({Key? key}) : super(key: key);

  @override
  State<VerificationRequestsListPage> createState() =>
      _VerificationRequestsListPageState();
}

class _VerificationRequestsListPageState
    extends State<VerificationRequestsListPage> {
  List<Map<String, dynamic>> verificationRequests = [];
  bool isLoading = false;
  String filterStatus = 'PENDING'; // PENDING, APPROVED, REJECTED, ALL
  String? rejectionReason;
  int? selectedRequestId;

  final Color brandOrange = const Color(0xFFF98825);
  final Color darkText = const Color(0xFF2C323A);

  @override
  void initState() {
    super.initState();
    _fetchVerificationRequests();
  }

  Future<void> _fetchVerificationRequests() async {
    setState(() => isLoading = true);

    try {
      String url = '$backendUrl/api/verification/all';
      if (filterStatus != 'ALL') {
        url += '?status=$filterStatus';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          verificationRequests = List<Map<String, dynamic>>.from(data['data']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch verification requests'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _approveRequest(int requestId) async {
    try {
      final response = await http.put(
        Uri.parse('$backendUrl/api/verification/$requestId/approve'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification request approved!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchVerificationRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectRequest(int requestId, String? reason) async {
    try {
      final response = await http.put(
        Uri.parse('$backendUrl/api/verification/$requestId/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rejectionReason': reason ?? 'Document does not meet requirements',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification request rejected!'),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchVerificationRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRejectionReasonDialog(int requestId) {
    rejectionReason = null;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          onChanged: (value) => rejectionReason = value,
          decoration: InputDecoration(
            hintText: 'Enter rejection reason',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectRequest(requestId, rejectionReason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: brandOrange,
        title: const Text(
          'Verification Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Buttons
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['PENDING', 'APPROVED', 'REJECTED', 'ALL']
                      .map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(status),
                            selected: filterStatus == status,
                            onSelected: (selected) {
                              setState(() => filterStatus = status);
                              _fetchVerificationRequests();
                            },
                            selectedColor: brandOrange,
                            labelStyle: TextStyle(
                              color: filterStatus == status
                                  ? Colors.white
                                  : darkText,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

            // List of Requests
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : verificationRequests.isEmpty
                  ? Center(
                      child: Text(
                        'No verification requests',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: verificationRequests.length,
                      itemBuilder: (context, index) {
                        final request = verificationRequests[index];
                        final status = request['status'];
                        final statusColor = _getStatusColor(status);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User Info
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            request['user']['name'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: darkText,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            request['user']['email'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Role: ${request['user']['role']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Document Info
                                Row(
                                  children: [
                                    Icon(
                                      Icons.description,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Document: ${request['documentType'].replaceAll('_', ' ')}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Document Image (clickable)
                                GestureDetector(
                                  onTap: request['documentPath'] != null
                                      ? () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DocumentPreviewPage(
                                                    imageUrl:
                                                        '$backendUrl/api/verification/documents/${request['documentPath']}',
                                                  ),
                                            ),
                                          );
                                        }
                                      : null,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.image,
                                        size: 16,
                                        color: request['documentPath'] != null
                                            ? brandOrange
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          request['documentPath'] != null
                                              ? 'View Document Image'
                                              : 'No document uploaded',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                request['documentPath'] != null
                                                ? brandOrange
                                                : Colors.grey.shade600,
                                            decoration:
                                                request['documentPath'] != null
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Extracted Data
                                if (request['extractedData'] != null &&
                                    request['extractedData']['extractedFields'] !=
                                        null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Extracted Information:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: darkText,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ..._buildExtractedFields(
                                          request['extractedData']['extractedFields'],
                                          request['documentType'],
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),

                                // Date Info
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Submitted: ${DateTime.parse(request['createdAt']).toLocal().toString().split('.')[0]}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),

                                // Rejection Reason (if rejected)
                                if (status == 'REJECTED' &&
                                    request['rejectionReason'] != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rejection Reason:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          request['rejectionReason'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Action Buttons (only for pending)
                                if (status == 'PENDING') ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _approveRequest(request['id']),
                                          icon: const Icon(Icons.check),
                                          label: const Text('Approve'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _showRejectionReasonDialog(
                                                request['id'],
                                              ),
                                          icon: const Icon(Icons.close),
                                          label: const Text('Reject'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExtractedFields(
    Map<String, dynamic> fields,
    String documentType,
  ) {
    List<Widget> widgets = [];

    if (documentType == 'NID') {
      if (fields['nidNumber'] != null) {
        widgets.add(_buildFieldRow('NID Number', fields['nidNumber']));
      }
      if (fields['fullName'] != null) {
        widgets.add(_buildFieldRow('Full Name', fields['fullName']));
      }
      if (fields['dateOfBirth'] != null) {
        widgets.add(_buildFieldRow('Date of Birth', fields['dateOfBirth']));
      }
      if (fields['address'] != null) {
        widgets.add(_buildFieldRow('Address', fields['address']));
      }
    } else if (documentType == 'DRIVERS_LICENSE') {
      if (fields['licenseNumber'] != null) {
        widgets.add(_buildFieldRow('License Number', fields['licenseNumber']));
      }
      if (fields['fullName'] != null) {
        widgets.add(_buildFieldRow('Full Name', fields['fullName']));
      }
      if (fields['dateOfBirth'] != null) {
        widgets.add(_buildFieldRow('Date of Birth', fields['dateOfBirth']));
      }
      if (fields['expiryDate'] != null) {
        widgets.add(_buildFieldRow('Expiry Date', fields['expiryDate']));
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        Text(
          'No information could be extracted from the document.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 11, color: darkText)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class DocumentPreviewPage extends StatelessWidget {
  final String imageUrl;

  const DocumentPreviewPage({Key? key, required this.imageUrl})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF98825),
        title: const Text('Document Preview'),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.error_outline, size: 60, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Unable to load document image.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
