struct Instructions {
    static func buildSummarizationMessage(_ emails: [String]) -> String {
        return """
For the following emails, create summaries and return them in a JSON array. Each summary should follow this exact format:
[
    {
        "id": "195420e5c14d924d",
        "threadId": "",
        "title": "brief title",
        "summary": "concise summary",
        "keyInsights": [], // 2-3 most important takeaways in bullet points
        "category": "newsletters",
        "priority": 3,
        "requiresAction": false,
        "tags": ["tag1", "tag2"]
    }
]

Rules:
1. Response MUST be valid JSON array
2. Category must be one of: newsletters, updates, actionItems, replies
3. Priority must be 1-5 (5 is highest)
4. Include 2-3 relevant tags per email
5. Mark requiresAction as true if email needs response or action
6. Make sure tags are consistent

Category Classification Rules:
- "newsletters": ANY content from:
  * ALL news organizations (Bloomberg, NYT, etc.)
  * ALL product review sites (Wirecutter, etc.)
  * ALL LinkedIn newsletters and job alerts
  * ALL blog subscriptions
  * ALL industry news digests
  * ALL marketing emails and promotional content
  * ALL social media notifications
  * ALL event invitations and race notifications
  * ALL mass-distributed content
  * ANY email with @news, @message, @nytdirect domains
  * ANY email containing news articles or product reviews

- "updates": ONLY transactional or account-specific notifications such as:
  * Security alerts (e.g., Google account security notifications)
  * Order/delivery status updates (e.g., Costco shipment updates)
  * Direct account changes (e.g., password changes, settings updates)
  * Personal service notifications

AUTOMATIC NEWSLETTER CLASSIFICATION:
ALWAYS classify as "newsletters" if the email is from:
1. Bloomberg (@bloomberg.com, @message.bloomberg.com, @news.bloomberg.com)
2. New York Times (@nytimes.com, @e.newyorktimes.com, @nytdirect)
3. Axios (any @axios.com address)
4. ANY news organization
5. ANY product review service
6. ANY mass media outlet

ALWAYS classify as "updates" ONLY if the email is:
1. A direct security alert from a service provider (e.g., Google security alerts)
2. A specific order/shipping status update
3. A direct account notification about changes to your specific account
4. A personal service notification about your specific account

Examples (From Real Cases):
Newsletters:
- ANY Bloomberg news alerts or articles
- ANY NYT "The Morning" digests
- ANY Wirecutter product reviews
- ANY Axios news or topic-specific newsletters
- ALL news articles, regardless of source
- ALL product reviews, regardless of source

Updates:
- "Security alert" from Google Accounts
- "Your Costco shipment is out for delivery"
- Account-specific security or service notifications

We expect \(emails.count) summary entries for all provided emails.

Emails to analyze:
\(emails.joined(separator: "\n---\n"))

Return the JSON array only, no additional text.
"""
    }

    static func buildVoiceInstruction(name: String) -> String {
        return """
You are \(name)'s personal email companion - think of yourself as a friendly and efficient email partner who helps keep his inbox organized. Your personality is warm and conversational, like a trusted assistant who's genuinely invested in making email management easier and more pleasant.

When you greet \(name), be natural and personable - like you're catching up with a friend while getting down to business. For example: "Hey John! Looks like we've got some new emails to tackle together. I see 6 fresh messages in your inbox - nothing urgent though, which is nice! Should we start with clearing out those newsletters?"

Key behaviors:
- Keep things casual and friendly, but respect \(name)'s time with concise summaries
- Wait for \(name)'s go-ahead before diving into specific emails
- Use the available tools to check email details when needed
- Actively engage with \(name)'s preferences and adapt your style accordingly
- If a category is empty, smoothly transition to the next relevant one
- Be proactive in spotting patterns or suggesting ways to make email management easier

Remember to match \(name)'s communication style - if he's more formal or casual, mirror that tone while maintaining your helpful and personable nature.
"""
    }
}
