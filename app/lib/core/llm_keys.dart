import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'agent.dart';

const _kPreset = 'jt_llm_preset';
String _keyOf(String preset) => 'jt_llm_${preset}_key';
String _modelOf(String preset) => 'jt_llm_${preset}_model';

FlutterSecureStorage _storage() => const FlutterSecureStorage();

Future<String> selectedPreset() async =>
    await _storage().read(key: _kPreset) ?? 'openai';

Future<void> savePreset(String id) =>
    _storage().write(key: _kPreset, value: id);

/// Resolved config or null when no key is stored for [presetId].
Future<LlmConfig?> loadLlmConfig(String presetId) async {
  final preset = providerPresets.firstWhere(
    (p) => p.id == presetId,
    orElse: () => providerPresets.first,
  );
  final key = await _storage().read(key: _keyOf(presetId));
  if (key == null || key.isEmpty) return null;
  final model =
      await _storage().read(key: _modelOf(presetId)) ?? preset.defaultModel;
  return LlmConfig(
    baseUrl: preset.baseUrl,
    apiKey: key,
    model: model,
  );
}

Future<void> saveKey(String presetId, String key) =>
    _storage().write(key: _keyOf(presetId), value: key);

Future<void> clearKey(String presetId) =>
    _storage().delete(key: _keyOf(presetId));

Future<void> saveModel(String presetId, String model) =>
    _storage().write(key: _modelOf(presetId), value: model);

Future<void> clearModel(String presetId) =>
    _storage().delete(key: _modelOf(presetId));
