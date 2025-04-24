import 'package:flutter/material.dart';

// Define colors used in SignupPage for consistency (optional)
const Color darkGreyText = Color(0xFF262626);

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.white,
        foregroundColor: darkGreyText,
        elevation: 1.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
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

            // --- IMPORTANT: REPLACE ALL THE TEXT BELOW WITH YOUR ACTUAL POLICY ---
            _buildParagraph(
              'Your privacy is important to us. It is the Instagram Tracker application\'s policy to respect your privacy regarding any information we may collect from you through our app.',
            ),

            _buildSectionTitle(context, 'Information We Collect'),
            _buildParagraph(
              'We only ask for personal information when we truly need it to provide a service to you. We collect it by fair and lawful means, with your knowledge and consent. We also let you know why we’re collecting it and how it will be used.',
            ),
            _buildParagraph(
              'Information collected may include:',
            ),
            _buildListItem(
                'Log data (e.g., IP address, device type, operating system)'),
            _buildListItem(
                'Usage data (e.g., features accessed, time spent in app)'),
            _buildListItem(
                'Information you provide directly (e.g., email address upon signup - if applicable)'),

            _buildSectionTitle(context, 'How We Use Information'),
            _buildParagraph(
              'We use the collected information to operate, maintain, and improve our Service, to understand how you use the Service, and to communicate with you (if necessary).',
            ),

            _buildSectionTitle(context, 'Data Retention'),
            _buildParagraph(
              'We only retain collected information for as long as necessary to provide you with your requested service. What data we store, we’ll protect within commercially acceptable means to prevent loss and theft, as well as unauthorized access, disclosure, copying, use or modification.',
            ),

            _buildSectionTitle(context, 'Sharing Information'),
            _buildParagraph(
              'We do not share any personally identifying information publicly or with third-parties, except when required to by law.',
            ),

            _buildSectionTitle(context, 'Third-Party Services'),
            _buildParagraph(
              'Our Service may link to external sites that are not operated by us. Please be aware that we have no control over the content and practices of these sites, and cannot accept responsibility or liability for their respective privacy policies.',
            ),

            _buildSectionTitle(context, 'Your Choices'),
            _buildParagraph(
              'You are free to refuse our request for your personal information, with the understanding that we may be unable to provide you with some of your desired services.',
            ),

            _buildSectionTitle(context, 'Changes to This Policy'),
            _buildParagraph(
              'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page. You are advised to review this Privacy Policy periodically for any changes.',
            ),

            _buildSectionTitle(context, 'Contact Us'),
            _buildParagraph(
              'If you have any questions about this Privacy Policy, please contact us at: [Insert Your Contact Email or Method Here]', // <-- IMPORTANT: Update Contact Info
            ),
            // --- END OF PLACEHOLDER TEXT ---

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Use the same helper widgets as Terms page for consistency
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
