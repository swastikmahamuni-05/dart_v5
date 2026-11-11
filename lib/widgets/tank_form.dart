import 'package:flutter/material.dart';
import '../models/tank.dart';

class TankForm extends StatefulWidget {
  final Tank? initialTank;
  final String submitButtonText;
  final Function(Map<String, dynamic> formData) onSave;

  const TankForm({
    Key? key,
    this.initialTank,
    required this.submitButtonText,
    required this.onSave,
  }) : super(key: key);

  @override
  State<TankForm> createState() => _TankFormState();
}

class _TankFormState extends State<TankForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _deviceIdController;
  late TextEditingController _locationController;
  late TextEditingController _capacityController;
  late TextEditingController _heightController;
  late TextEditingController _vrefController;
  late TextEditingController _correctionFactorController;
  late TextEditingController _offsetController;
  late TextEditingController _rangeController;
  late TextEditingController _warningThresholdController;
  late TextEditingController _criticalThresholdController;

  @override
  void initState() {
    super.initState();
    final tank = widget.initialTank;

    _nameController = TextEditingController(text: tank?.tankName ?? '');
    _deviceIdController = TextEditingController(text: tank?.deviceId ?? '');
    _locationController = TextEditingController(text: tank?.location ?? '');
    _capacityController = TextEditingController(text: tank != null ? tank.tankCapacity.toString() : '15000');
    _heightController = TextEditingController(text: tank != null ? tank.tankHeight.toString() : '5000');

    // Sensor parameters (defaults)
    _vrefController = TextEditingController(text: tank != null ? tank.vref.toString() : '3300');
    _correctionFactorController = TextEditingController(text: tank != null ? tank.correctionFactor.toString() : '1.41');
    _offsetController = TextEditingController(text: tank != null ? tank.offset.toString() : '0.0');
    _rangeController = TextEditingController(text: tank != null ? tank.range.toString() : '5000.0');

    // Alert parameters (defaults)
    _warningThresholdController = TextEditingController(text: tank != null ? tank.warningThreshold.toString() : '50');
    _criticalThresholdController = TextEditingController(text: tank != null ? tank.criticalThreshold.toString() : '20');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deviceIdController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _heightController.dispose();
    _vrefController.dispose();
    _correctionFactorController.dispose();
    _offsetController.dispose();
    _rangeController.dispose();
    _warningThresholdController.dispose();
    _criticalThresholdController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final formData = {
        'tankName': _nameController.text.trim(),
        'deviceId': _deviceIdController.text.trim(),
        'location': _locationController.text.trim(),
        'tankCapacity': double.parse(_capacityController.text),
        'tankHeight': double.parse(_heightController.text),
        'vref': double.parse(_vrefController.text),
        'correctionFactor': double.parse(_correctionFactorController.text),
        'offset': double.parse(_offsetController.text),
        'range': double.parse(_rangeController.text),
        'warningThreshold': double.parse(_warningThresholdController.text),
        'criticalThreshold': double.parse(_criticalThresholdController.text),
      };
      widget.onSave(formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            _buildSectionHeader('Basic Information', Icons.info_outline, textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Tank Name',
                      hint: 'e.g. Tank 1, Potable Reservoir',
                      icon: Icons.layers_outlined,
                      validator: Tank.validateName,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _deviceIdController,
                      label: 'Device ID',
                      hint: 'e.g. ESP32-NODE-01',
                      icon: Icons.developer_board_rounded,
                      validator: Tank.validateDeviceId,
                      enabled: widget.initialTank == null, // Lock Device ID on Update
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'e.g. Girls Hostel, Admin Block',
                      icon: Icons.location_on_outlined,
                      validator: Tank.validateLocation,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _capacityController,
                            label: 'Capacity (Litres)',
                            hint: '15000',
                            icon: Icons.local_drink_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validatePositiveDouble(v, 'Capacity'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _heightController,
                            label: 'Height (Millimetres)',
                            hint: '5000',
                            icon: Icons.height,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validatePositiveDouble(v, 'Height'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sensor Configuration Section
            _buildSectionHeader('Sensor Configuration', Icons.sensors_rounded, textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _vrefController,
                            label: 'VREF (mV)',
                            hint: '3300',
                            icon: Icons.bolt,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validatePositiveDouble(v, 'VREF'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _correctionFactorController,
                            label: 'Correction Factor',
                            hint: '1.41',
                            icon: Icons.tune,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validatePositiveDouble(v, 'Correction Factor'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _offsetController,
                            label: 'Offset',
                            hint: '0.0',
                            icon: Icons.compare_arrows,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validateNonNegativeDouble(v, 'Offset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _rangeController,
                            label: 'Range (mm)',
                            hint: '5000.0',
                            icon: Icons.straighten,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validatePositiveDouble(v, 'Range'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Alert Configuration Section
            _buildSectionHeader('Alert Configuration', Icons.warning_amber_rounded, textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _warningThresholdController,
                            label: 'Warning Threshold (%)',
                            hint: '50',
                            icon: Icons.notifications_active_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validatePositiveDouble(v, 'Warning Threshold'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _criticalThresholdController,
                            label: 'Critical Threshold (%)',
                            hint: '20',
                            icon: Icons.error_outline,
                            keyboardType: TextInputType.number,
                            validator: (v) => Tank.validatePositiveDouble(v, 'Critical Threshold'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), // Primary Blue
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF1565C0).withOpacity(0.3),
              ),
              child: Text(
                widget.submitButtonText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMutedColor = isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF64748B);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      style: TextStyle(
        color: enabled 
            ? (isDark ? Colors.white : const Color(0xFF1E293B))
            : textMutedColor,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textMutedColor, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: textMutedColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: enabled 
            ? Colors.transparent 
            : (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF1F5F9)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}
