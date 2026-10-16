import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late bool _arabic;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arabic = Localizations.localeOf(context).languageCode == 'ar';
  }

  @override
  Widget build(BuildContext context) {
    final terms = widget.document == LegalDocument.terms;
    final title = terms
        ? (_arabic ? 'شروط الخدمة' : 'Terms of Service')
        : (_arabic ? 'سياسة الخصوصية' : 'Privacy Policy');
    final sections = terms ? _termsSections : _privacySections;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            _arabic
                ? 'آخر تحديث: 16 أكتوبر 2026'
                : 'Last updated: October 16, 2026',
            style: TextStyle(color: context.textSec, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('English')),
              ButtonSegment<bool>(value: true, label: Text('العربية')),
            ],
            selected: {_arabic},
            onSelectionChanged: (selected) {
              setState(() => _arabic = selected.first);
            },
          ),
          const SizedBox(height: 16),
          Text(
            _arabic
                ? (terms
                      ? 'يرجى قراءة هذه الشروط قبل استخدام EgyptLore.'
                      : 'تشرح هذه السياسة البيانات التي يستخدمها EgyptLore وكيفية التعامل معها.')
                : (terms
                      ? 'Please read these terms before using EgyptLore.'
                      : 'This policy explains what information EgyptLore uses and how it is handled.'),
            style: TextStyle(color: context.textSec, height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 14),
          for (final section in sections)
            _LegalSection(
              title: _arabic ? section.arTitle : section.enTitle,
              body: _arabic ? section.arBody : section.enBody,
            ),
        ],
      ),
    );
  }
}

class _LegalSectionData {
  const _LegalSectionData(this.enTitle, this.arTitle, this.enBody, this.arBody);

  final String enTitle;
  final String arTitle;
  final String enBody;
  final String arBody;
}

const _termsSections = <_LegalSectionData>[
  _LegalSectionData(
    '1. About EgyptLore and acceptance',
    '١. عن EgyptLore والموافقة',
    'EgyptLore helps people discover places, cultural stories, tours, and travel features. By creating an account or using the app, you agree to these Terms. If you do not agree, do not use the service. You must meet the minimum age required by the laws where you live.',
    'يساعد EgyptLore المستخدمين على اكتشاف الأماكن والحكايات الثقافية والجولات وميزات السفر. بإنشاء حساب أو استخدام التطبيق، فإنك توافق على هذه الشروط. إذا لم توافق، فلا تستخدم الخدمة. يجب أن تستوفي الحد الأدنى للعمر الذي تفرضه القوانين في مكان إقامتك.',
  ),
  _LegalSectionData(
    '2. Accounts and account deletion',
    '٢. الحسابات وحذف الحساب',
    'Keep your sign-in details secure and provide accurate information. You are responsible for activity performed through your account. You can request deletion using Delete Account in Profile settings. After confirmation, we submit the request to remove your account and associated personal data, subject to limited retention required by law, security, or accounting obligations. Deleting your EgyptLore account does not cancel an Apple or Google subscription; cancel it separately in the relevant store settings.',
    'حافظ على بيانات تسجيل الدخول آمنة وقدّم معلومات دقيقة. أنت مسؤول عن النشاط الذي يتم عبر حسابك. يمكنك طلب الحذف من خيار «حذف الحساب» في إعدادات الملف الشخصي. بعد التأكيد، نرسل طلب إزالة حسابك وبياناتك الشخصية المرتبطة به، مع مراعاة الاحتفاظ المحدود الذي تفرضه القوانين أو متطلبات الأمان أو المحاسبة. حذف حساب EgyptLore لا يلغي اشتراك Apple أو Google؛ ألغِه بشكل منفصل من إعدادات المتجر المعني.',
  ),
  _LegalSectionData(
    '3. Location and safety',
    '٣. الموقع والسلامة',
    'If you grant permission, the app may use your location to show nearby places, directions, check-ins, and location-based alerts. Background location is used only when you enable nearby alerts and can be disabled in device settings or in the app. Location may be approximate or unavailable. Maps, routes, opening hours, and recommendations can be incomplete or out of date. Use your own judgment, obey local rules, and do not rely on the app for emergency services or safety-critical directions.',
    'إذا منحت الإذن، قد يستخدم التطبيق موقعك لعرض الأماكن القريبة والاتجاهات وتسجيلات الوصول والتنبيهات المرتبطة بالموقع. يُستخدم الموقع في الخلفية فقط عند تفعيل التنبيهات القريبة، ويمكن إيقافه من إعدادات الجهاز أو التطبيق. قد يكون الموقع تقريبيًا أو غير متاح. قد تكون الخرائط والمسارات وساعات العمل والتوصيات غير مكتملة أو قديمة. استخدم تقديرك، واتبع القوانين المحلية، ولا تعتمد على التطبيق لخدمات الطوارئ أو التوجيهات الحرجة للسلامة.',
  ),
  _LegalSectionData(
    '4. Check-ins, photos, and other user content',
    '٤. تسجيلات الوصول والصور ومحتوى المستخدم',
    'You retain ownership of content you submit, including check-ins, photos, reviews, and place suggestions. You give EgyptLore a non-exclusive, worldwide, royalty-free license to host, display, and distribute that content as needed to operate and improve social features. Only upload content you have the right to share; do not post unlawful, private, misleading, abusive, or infringing material. Do not upload another person’s image or personal information without permission. You can remove content where the app provides that control. We may review, restrict, or remove content that violates these Terms or applicable law.',
    'تحتفظ بملكية المحتوى الذي ترسله، بما في ذلك تسجيلات الوصول والصور والمراجعات واقتراحات الأماكن. تمنح EgyptLore ترخيصًا غير حصري وعالميًا وخاليًا من الإتاوات لاستضافة هذا المحتوى وعرضه وتوزيعه بالقدر اللازم لتشغيل الميزات الاجتماعية وتحسينها. لا ترسل إلا محتوى يحق لك مشاركته؛ ولا تنشر مواد غير قانونية أو خاصة أو مضللة أو مسيئة أو منتهكة للحقوق. لا ترفع صورة شخص آخر أو معلوماته الشخصية دون إذنه. يمكنك إزالة المحتوى حيث يوفر التطبيق ذلك. يجوز لنا مراجعة المحتوى المخالف لهذه الشروط أو للقانون المعمول به أو تقييده أو إزالته.',
  ),
  _LegalSectionData(
    '5. AI tour guide and travel information',
    '٥. دليل الجولات بالذكاء الاصطناعي ومعلومات السفر',
    'AI-generated tour-guide responses are informational suggestions, may contain errors, and are not professional, legal, medical, or safety advice. Place descriptions and travel information are provided for general discovery, not as a guarantee of accuracy, availability, access, price, or safety. Verify important details with the venue or an authoritative source before acting.',
    'إجابات دليل الجولات المُنشأة بالذكاء الاصطناعي هي اقتراحات معلوماتية وقد تتضمن أخطاء، ولا تُعد نصيحة مهنية أو قانونية أو طبية أو متعلقة بالسلامة. تُقدّم أوصاف الأماكن ومعلومات السفر لأغراض الاكتشاف العام، ولا تمثل ضمانًا للدقة أو التوفر أو إمكانية الدخول أو السعر أو السلامة. تحقق من التفاصيل المهمة لدى المكان أو مصدر موثوق قبل التصرف.',
  ),
  _LegalSectionData(
    '6. Subscriptions, availability, and changes',
    '٦. الاشتراكات والتوفر والتغييرات',
    'Some features may require a paid subscription. Purchase, renewal, cancellation, and refund terms are controlled by the store through which you subscribe. EgyptLore is provided on an “as available” basis; features may change or be interrupted. To the extent permitted by law, EgyptLore is not liable for indirect losses resulting from use of the service. Nothing in these Terms limits rights that cannot legally be limited.',
    'قد تتطلب بعض الميزات اشتراكًا مدفوعًا. تخضع شروط الشراء والتجديد والإلغاء والاسترداد للمتجر الذي اشتركت من خلاله. يُقدّم EgyptLore حسب التوفر، وقد تتغير الميزات أو تتوقف. بالقدر الذي يسمح به القانون، لا تتحمل EgyptLore مسؤولية الخسائر غير المباشرة الناتجة عن استخدام الخدمة. لا تحد هذه الشروط من أي حقوق لا يجوز قانونًا تقييدها.',
  ),
  _LegalSectionData(
    '7. Contact',
    '٧. التواصل',
    'For questions or requests about these Terms, account deletion, or the service, contact the EgyptLore team through the support options provided in the app.',
    'للاستفسارات أو الطلبات المتعلقة بهذه الشروط أو حذف الحساب أو الخدمة، تواصل مع فريق EgyptLore عبر خيارات الدعم المتاحة في التطبيق.',
  ),
];

const _privacySections = <_LegalSectionData>[
  _LegalSectionData(
    '1. Information we use',
    '١. المعلومات التي نستخدمها',
    'Depending on the features you use, EgyptLore processes account details such as your email, username, and profile name; places you save; check-ins, reviews, photos, and suggestions you submit; preferences; and technical diagnostic information needed to operate and secure the app. We do not ask for information that is not needed for the relevant feature.',
    'بحسب الميزات التي تستخدمها، يعالج EgyptLore بيانات الحساب مثل بريدك الإلكتروني واسم المستخدم واسم الملف الشخصي؛ والأماكن التي تحفظها؛ وتسجيلات الوصول والمراجعات والصور والاقتراحات التي ترسلها؛ والتفضيلات؛ والمعلومات التقنية والتشخيصية اللازمة لتشغيل التطبيق وتأمينه. لا نطلب معلومات لا تحتاج إليها الميزة المعنية.',
  ),
  _LegalSectionData(
    '2. Location use and controls',
    '٢. استخدام الموقع والتحكم فيه',
    'With your permission, location is used to provide nearby recommendations, map directions, check-in features, and other location-aware functions. If you enable nearby alerts, location may be processed in the background to detect proximity to selected landmarks and deliver alerts, including while the app is not open. You can disable location or background access at any time in device settings and turn off nearby alerts in the app. If permission is denied, related features may not work.',
    'بإذنك، يُستخدم الموقع لتقديم توصيات قريبة واتجاهات الخرائط وميزات تسجيل الوصول وغيرها من الوظائف المعتمدة على الموقع. إذا فعّلت التنبيهات القريبة، فقد تتم معالجة الموقع في الخلفية لاكتشاف الاقتراب من المعالم المحددة وإرسال التنبيهات، حتى عندما لا يكون التطبيق مفتوحًا. يمكنك إيقاف الموقع أو الوصول في الخلفية في أي وقت من إعدادات الجهاز، وإيقاف التنبيهات القريبة من التطبيق. عند رفض الإذن، قد لا تعمل الميزات ذات الصلة.',
  ),
  _LegalSectionData(
    '3. User-generated content and social features',
    '٣. محتوى المستخدم والميزات الاجتماعية',
    'Check-ins, profile names, reviews, submitted photos, place suggestions, and social activity may be shown to other users according to the feature’s design. Do not include sensitive personal details in public content. Photos may include image metadata supplied by your device; review your device or photo settings if you wish to remove it before upload. You can request account deletion from Profile settings.',
    'قد تظهر تسجيلات الوصول وأسماء الملفات الشخصية والمراجعات والصور والاقتراحات ونشاطك الاجتماعي لمستخدمين آخرين وفقًا لتصميم الميزة. لا تدرج معلومات شخصية حساسة في المحتوى العام. قد تتضمن الصور بيانات وصفية يوفرها جهازك؛ راجع إعدادات الجهاز أو الصور لإزالتها قبل الرفع إذا رغبت. يمكنك طلب حذف الحساب من إعدادات الملف الشخصي.',
  ),
  _LegalSectionData(
    '4. How information is used and shared',
    '٤. كيفية استخدام المعلومات ومشاركتها',
    'We use information to provide maps, discovery, accounts, social features, support, and app security; to troubleshoot and improve the service; and to comply with legal obligations. Information may be processed by service providers that support hosting, authentication, diagnostics, maps, and subscriptions, under their applicable terms. We do not sell your precise location. Public or social content is shared as described above and is not made private by deleting the app from your device.',
    'نستخدم المعلومات لتقديم الخرائط والاكتشاف والحسابات والميزات الاجتماعية والدعم وأمان التطبيق؛ واستكشاف الأعطال وتحسين الخدمة؛ والامتثال للالتزامات القانونية. قد يعالج المعلومات مزودو خدمات يدعمون الاستضافة والمصادقة والتشخيص والخرائط والاشتراكات وفق شروطهم المعمول بها. لا نبيع موقعك الدقيق. تتم مشاركة المحتوى العام أو الاجتماعي كما هو موضح أعلاه، ولا يصبح خاصًا بمجرد حذف التطبيق من جهازك.',
  ),
  _LegalSectionData(
    '5. Retention and account deletion',
    '٥. الاحتفاظ بالبيانات وحذف الحساب',
    'We retain information for as long as needed to provide the service and meet legal, security, and accounting obligations. Use Delete Account in Profile settings to request deletion of your account and associated personal data. Some information may remain for a limited period where required by law, to resolve disputes, or to prevent abuse. Store-managed subscriptions must be cancelled separately with Apple or Google; deleting your account does not cancel billing.',
    'نحتفظ بالمعلومات ما دامت لازمة لتقديم الخدمة والوفاء بالالتزامات القانونية والأمنية والمحاسبية. استخدم «حذف الحساب» في إعدادات الملف الشخصي لطلب حذف حسابك وبياناتك الشخصية المرتبطة به. قد تبقى بعض المعلومات لفترة محدودة إذا تطلب القانون ذلك، أو لحل النزاعات، أو لمنع إساءة الاستخدام. يجب إلغاء الاشتراكات التي يديرها المتجر بشكل منفصل عبر Apple أو Google؛ فحذف الحساب لا يلغي الفوترة.',
  ),
  _LegalSectionData(
    '6. Your choices and security',
    '٦. خياراتك وأمانك',
    'You can manage location permissions, notification preferences, and nearby alerts through your device or app settings. You may request access, correction, or deletion of personal information where applicable law provides those rights. We use reasonable safeguards, but no online service can guarantee absolute security.',
    'يمكنك إدارة أذونات الموقع وتفضيلات الإشعارات والتنبيهات القريبة من إعدادات الجهاز أو التطبيق. يمكنك طلب الوصول إلى معلوماتك الشخصية أو تصحيحها أو حذفها حيث يمنحك القانون المعمول به هذه الحقوق. نتخذ تدابير حماية معقولة، لكن لا يمكن لأي خدمة عبر الإنترنت ضمان الأمان المطلق.',
  ),
  _LegalSectionData(
    '7. Children and policy updates',
    '٧. الأطفال وتحديثات السياسة',
    'EgyptLore is not intended for children below the minimum age required by local law. We do not knowingly collect their personal information. We may update this policy as the app changes; the latest version and date will be available in the app.',
    'لا يستهدف EgyptLore الأطفال دون الحد الأدنى للعمر الذي يحدده القانون المحلي. لا نجمع معلوماتهم الشخصية عن علم. قد نحدّث هذه السياسة عند تغير التطبيق؛ وستتوفر أحدث نسخة وتاريخها في التطبيق.',
  ),
  _LegalSectionData(
    '8. Contact',
    '٨. التواصل',
    'For privacy questions, data requests, or account-deletion support, contact the EgyptLore team through the support options provided in the app.',
    'للاستفسارات المتعلقة بالخصوصية أو طلبات البيانات أو المساعدة في حذف الحساب، تواصل مع فريق EgyptLore عبر خيارات الدعم المتاحة في التطبيق.',
  ),
];

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.hintColor.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(color: context.textSec, fontSize: 14, height: 1.65),
        ),
      ],
    ),
  );
}
