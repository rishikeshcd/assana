import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';

class MedicalReportViewerPage extends StatefulWidget {
  const MedicalReportViewerPage({super.key, required this.reportUrl});

  final String reportUrl;

  @override
  State<MedicalReportViewerPage> createState() =>
      _MedicalReportViewerPageState();
}

class _MedicalReportViewerPageState extends State<MedicalReportViewerPage> {
  bool _isImage = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkFileType();
  }

  void _checkFileType() {
    final url = widget.reportUrl.toLowerCase();
    _isImage =
        url.endsWith('.png') ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.gif') ||
        url.endsWith('.webp');

    if (!_isImage) {
      // For non-image files (PDFs), open in browser
      _openInBrowser();
    } else {
      // For images, show in app
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.reportUrl);
      print('🌐 Opening medical report URL in browser: ${widget.reportUrl}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Close this page after opening in browser
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // If canLaunchUrl returns false, try launching anyway
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            Navigator.of(context).pop();
          }
        } catch (e) {
          print('Error launching URL: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Could not open medical report';
            });
          }
        }
      }
    } catch (e) {
      print('Error in _openInBrowser: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error opening report: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImage) {
      // Show loading or error for non-image files
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Medical Report'),
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Opening medical report in browser...',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Could not open report',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
      );
    }

    // Show image in app
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Medical Report'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Open in Browser',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            widget.reportUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _openInBrowser,
                      child: const Text('Open in Browser'),
                    ),
                  ],
                ),
              );
            },
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
