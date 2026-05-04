import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/cupertino_date_picker.dart';

class AdvancedFilters extends StatefulWidget {
  final String? selectedCategory;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? amountMin;
  final double? amountMax;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final ValueChanged<double?> onAmountMinChanged;
  final ValueChanged<double?> onAmountMaxChanged;
  final VoidCallback onReset;

  const AdvancedFilters({
    super.key,
    this.selectedCategory,
    this.dateFrom,
    this.dateTo,
    this.amountMin,
    this.amountMax,
    required this.onCategoryChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onAmountMinChanged,
    required this.onAmountMaxChanged,
    required this.onReset,
  });

  @override
  State<AdvancedFilters> createState() => _AdvancedFiltersState();
}

class _AdvancedFiltersState extends State<AdvancedFilters> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Filtry zaawansowane',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed: widget.onReset,
                    child: const Text('Resetuj', style: TextStyle(fontSize: 12)),
                  ),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildFilters(context),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  bool get _hasActiveFilters =>
      widget.selectedCategory != null ||
      widget.dateFrom != null ||
      widget.dateTo != null ||
      widget.amountMin != null ||
      widget.amountMax != null;

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips
          const Text('Kategoria',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Wszystkie'),
                selected: widget.selectedCategory == null,
                onSelected: (_) => widget.onCategoryChanged(null),
              ),
              ...AppConstants.receiptCategories.map(
                (cat) => ChoiceChip(
                  label: Text(cat),
                  selected: widget.selectedCategory == cat,
                  onSelected: (_) => widget.onCategoryChanged(cat),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date range
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Od daty',
                  value: widget.dateFrom,
                  onChanged: widget.onDateFromChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Do daty',
                  value: widget.dateTo,
                  onChanged: widget.onDateToChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Amount range
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Kwota min',
                    prefixText: 'zł ',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      widget.onAmountMinChanged(double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Kwota max',
                    prefixText: 'zł ',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      widget.onAmountMaxChanged(double.tryParse(v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showCupertinoDateDialog(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
        ),
        child: Text(
          value != null
              ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}'
              : '',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
