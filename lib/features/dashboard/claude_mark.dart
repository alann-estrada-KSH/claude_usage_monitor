import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Claude Code's icon mark (the little terminal/robot-face glyph), from
/// /home/alann/Descargas/claudecode-color.svg -- viewBox 0 0 24 24, fill
/// #D97757 in the source file. Personal-use-only build (not distributed),
/// so exact reproduction is fine here -- this is still an unofficial,
/// unaffiliated tool.
class ClaudeMark extends StatelessWidget {
  const ClaudeMark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  static const _path =
      'M20.998 10.949H24v3.102h-3v3.028h-1.487V20H18v-2.921h-1.487V20H15v-2.921H9V20H7.488v-2.921H6V20H4.487v-2.921H3V14.05H0V10.95h3V5h17.998v5.949zM6 10.949h1.488V8.102H6v2.847zm10.51 0H18V8.102h-1.49v2.847z';

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<path clip-rule="evenodd" fill-rule="evenodd" d="$_path" fill="#${_hex(tint)}"/>'
        '</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }

  static String _hex(Color c) {
    int channel(double v) => (v * 255).round().clamp(0, 255);
    String byte(double v) => channel(v).toRadixString(16).padLeft(2, '0');
    return '${byte(c.r)}${byte(c.g)}${byte(c.b)}';
  }
}
