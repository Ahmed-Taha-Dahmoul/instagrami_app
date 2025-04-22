import 'package:flutter/material.dart';

// Define colors used in SignupPage for consistency (optional, but good practice)
const Color darkGreyText = Color(0xFF262626);

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        // AppBar automatically adds a back button when pushed onto the stack
        backgroundColor: Colors.white, // Match signup theme
        foregroundColor: darkGreyText, // Match signup theme
        elevation: 1.0, // Subtle shadow
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: darkGreyText,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last Updated: [Insert Date Here]', // <-- IMPORTANT: Update this date
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // --- IMPORTANT: REPLACE ALL THE TEXT BELOW WITH YOUR ACTUAL TERMS ---
            _buildSectionTitle(context, '1. Acceptance of Terms'),
            _buildParagraph(
              'By accessing or using the Instagram Tracker application ("Service"), you agree to be bound by these Terms of Service ("Terms"). If you disagree with any part of the terms, then you may not access the Service.',
            ),

            _buildSectionTitle(context, '2. Use License'),
            _buildParagraph(
              'Permission is granted to temporarily download one copy of the materials (information or software) on the Service for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title, and under this license you may not:',
            ),
            _buildListItem('modify or copy the materials;'),
            _buildListItem(
                'use the materials for any commercial purpose, or for any public display (commercial or non-commercial);'),
            _buildListItem(
                'attempt to decompile or reverse engineer any software contained on the Service;'),
            _buildListItem(
                'remove any copyright or other proprietary notations from the materials; or'),
            _buildListItem(
                'transfer the materials to another person or "mirror" the materials on any other server.'),
            _buildParagraph(
              'This license shall automatically terminate if you violate any of these restrictions and may be terminated by the Service provider at any time.',
            ),

            _buildSectionTitle(context, '3. Disclaimer'),
            _buildParagraph(
              'The materials on the Service are provided on an \'as is\' basis. The Service provider makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights.',
            ),

            _buildSectionTitle(context, '4. Limitations'),
            _buildParagraph(
              'In no event shall the Service provider or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the materials on the Service, even if the Service provider or a Service provider authorized representative has been notified orally or in writing of the possibility of such damage.',
            ),

            _buildSectionTitle(context, '5. Modifications to Terms'),
            _buildParagraph(
              'The Service provider may revise these Terms of Service at any time without notice. By using this Service you are agreeing to be bound by the then current version of these Terms of Service.',
            ),

            _buildSectionTitle(context, '6. Governing Law'),
            _buildParagraph(
              'These terms and conditions are governed by and construed in accordance with the laws of [Insert Your Jurisdiction Here] and you irrevocably submit to the exclusive jurisdiction of the courts in that State or location.', // <-- IMPORTANT: Update Jurisdiction
            ),
            // --- END OF PLACEHOLDER TEXT ---

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper widgets for consistent styling
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: darkGreyText,
            ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 15, height: 1.5, color: Color(0xFF444444)),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 15, height: 1.5)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }
}
