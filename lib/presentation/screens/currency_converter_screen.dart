import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _egpController = TextEditingController(text: '100');
  String _fromCurrency = 'EGP';
  String _toCurrency = 'USD';

  static const Map<String, double> _ratesToEgp = {
    'EGP': 1.0,
    'USD': 49.5,
    'EUR': 53.7,
    'GBP': 62.8,
    'SAR': 13.2,
    'AED': 13.5,
    'KWD': 161.0,
    'JPY': 0.33,
    'CNY': 6.85,
    'RUB': 0.54,
  };

  final List<String> _currencies = const [
    'EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED', 'KWD', 'JPY', 'CNY', 'RUB',
  ];

  @override
  void dispose() {
    _egpController.dispose();
    super.dispose();
  }

  double _convert(double amount, String from, String to) {
    if (from == to) return amount;
    final fromRate = _ratesToEgp[from] ?? 1.0;
    final toRate = _ratesToEgp[to] ?? 1.0;
    final inEgp = amount * fromRate;
    return inEgp / toRate;
  }

  String _symbol(String code) {
    switch (code) {
      case 'EGP': return 'E£';
      case 'USD': return r'$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'SAR': return '﷼';
      case 'AED': return 'د.إ';
      case 'KWD': return 'د.ك';
      case 'JPY': return '¥';
      case 'CNY': return '¥';
      case 'RUB': return '₽';
      default: return '';
    }
  }

  String _flag(String code) {
    switch (code) {
      case 'EGP': return '🇪🇬';
      case 'USD': return '🇺🇸';
      case 'EUR': return '🇪🇺';
      case 'GBP': return '🇬🇧';
      case 'SAR': return '🇸🇦';
      case 'AED': return '🇦🇪';
      case 'KWD': return '🇰🇼';
      case 'JPY': return '🇯🇵';
      case 'CNY': return '🇨🇳';
      case 'RUB': return '🇷🇺';
      default: return '🌍';
    }
  }

  void _swap() {
    HapticFeedback.lightImpact();
    setState(() {
      final t = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_egpController.text) ?? 0;
    final result = _convert(amount, _fromCurrency, _toCurrency);
    final rate = _convert(1, _fromCurrency, _toCurrency);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Currency Converter'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_symbol(_fromCurrency)} ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_symbol(_toCurrency)} ${result.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1 $_fromCurrency = ${rate.toStringAsFixed(4)} $_toCurrency',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Amount', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          TextField(
            controller: _egpController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter amount',
              filled: true,
              fillColor: AppColors.cardBackground,
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  _symbol(_fromCurrency),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 50),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.textHint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.textHint.withValues(alpha: 0.3)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _CurrencyPicker(
                label: 'From',
                code: _fromCurrency,
                onChanged: (c) => setState(() => _fromCurrency = c),
                currencies: _currencies,
                flag: _flag,
                symbol: _symbol,
              )),
              IconButton(
                onPressed: _swap,
                icon: const Icon(Icons.swap_horiz_rounded, size: 28),
                color: AppColors.primary,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                ),
              ),
              Expanded(child: _CurrencyPicker(
                label: 'To',
                code: _toCurrency,
                onChanged: (c) => setState(() => _toCurrency = c),
                currencies: _currencies,
                flag: _flag,
                symbol: _symbol,
              )),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rates are approximate and based on mid-market averages. Check with your bank or exchange for actual rates.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  final String label;
  final String code;
  final ValueChanged<String> onChanged;
  final List<String> currencies;
  final String Function(String) flag;
  final String Function(String) symbol;

  const _CurrencyPicker({
    required this.label,
    required this.code,
    required this.onChanged,
    required this.currencies,
    required this.flag,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          DropdownButton<String>(
            value: code,
            isExpanded: true,
            underline: const SizedBox(),
            items: currencies
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Text(flag(c), style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(symbol(c), style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          Text(c),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
