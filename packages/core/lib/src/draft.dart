import 'package:job_tracker_core/job_tracker_core.dart';

/// Text-only follow-up draft grounded in real context. Shared by the server
/// MCP tool and the app agent (single template, no drift). The human sends.
String buildDraft({
  required Application app,
  required List<Interaction> recent,
  String? tone,
}) {
  final last = recent.isEmpty ? null : recent.first.summary;
  final buf = StringBuffer()
    ..writeln('draft — nothing was sent.')
    ..writeln('To: <hiring contact at ${app.company}>')
    ..writeln('Re: ${app.role} application (${app.stage.name})')
    ..writeln()
    ..writeln(
      'Hi, following up on my ${app.role} application at ${app.company}.',
    );
  if (last != null) buf.writeln('Last touch: $last.');
  buf
    ..writeln('Still very interested — happy to share anything that helps.')
    ..writeln('Best regards')
    ..writeln()
    ..writeln('(tone requested: ${tone ?? 'neutral'})');
  return buf.toString();
}
