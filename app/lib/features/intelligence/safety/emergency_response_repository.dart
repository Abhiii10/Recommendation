import '../models/language_detection_result.dart';

class EmergencyResponseRepository {
  const EmergencyResponseRepository();

  EmergencyResponse responseFor(LanguageDetectionResult language) {
    final nepali = language.languageCode == 'ne';
    return EmergencyResponse(
      text: nepali ? _nepaliText : _englishText,
      contacts: const [
        EmergencyContact(
            type: 'police', number: '100', name: 'Police Emergency'),
        EmergencyContact(
            type: 'ambulance', number: '102', name: 'Ambulance Service'),
        EmergencyContact(type: 'fire', number: '101', name: 'Fire Brigade'),
        EmergencyContact(
            type: 'tourist_police', number: '1144', name: 'Tourist Police'),
        EmergencyContact(
          type: 'mountain_rescue',
          number: '01-4003635',
          name: 'CIWEC Hospital / Mountain Rescue',
        ),
      ],
    );
  }

  static const _englishText = '''
EMERGENCY CONTACTS - NEPAL

Police: 100
Ambulance: 102
Fire Brigade: 101
Tourist Police: 1144
Mountain Rescue: 01-4003635

Instructions:
- Stay calm and assess the situation.
- If safe, stay where you are and wait for help.
- Inform your homestay host or nearest local person.
- Use the offline Map tab to share your saved location.
- Keep your phone charged and visible.
''';

  static const _nepaliText = '''
आपतकालीन सम्पर्क - नेपाल

प्रहरी: 100
एम्बुलेन्स: 102
दमकल: 101
पर्यटक प्रहरी: 1144
माउन्टेन रेस्क्यु: 01-4003635

निर्देशन:
- शान्त रहनुहोस् र स्थिति मूल्याङ्कन गर्नुहोस्।
- सुरक्षित भए जहाँ हुनुहुन्छ त्यहीँ बस्नुहोस्।
- होमस्टे होस्ट वा नजिकैको स्थानीयलाई जानकारी दिनुहोस्।
- सेभ गरिएको स्थान साझा गर्न अफलाइन नक्सा प्रयोग गर्नुहोस्।
- फोन चार्ज राख्नुहोस्।
''';
}

class EmergencyResponse {
  final String text;
  final List<EmergencyContact> contacts;

  const EmergencyResponse({
    required this.text,
    required this.contacts,
  });
}

class EmergencyContact {
  final String type;
  final String number;
  final String name;

  const EmergencyContact({
    required this.type,
    required this.number,
    required this.name,
  });
}
