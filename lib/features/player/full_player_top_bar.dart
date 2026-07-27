import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FullPlayerTopBar extends StatelessWidget {
  const FullPlayerTopBar({
    required this.onCollapse,
    required this.onShowOutput,
    required this.onShowQueue,
    this.isCastConnecting = false,
    this.remoteRouteName,
    this.isBluetoothActive = false,
    this.bluetoothName,
    this.showCloudStream = false,
    super.key,
  });

  final VoidCallback onCollapse;
  final VoidCallback onShowOutput;
  final VoidCallback onShowQueue;
  final bool isCastConnecting;
  final String? remoteRouteName;
  final bool isBluetoothActive;
  final String? bluetoothName;
  final bool showCloudStream;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final buttonBackground = colors.onPrimary.withValues(alpha: .7);
    final showCastLabel = isCastConnecting || remoteRouteName != null;

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 42,
            child: Align(
              alignment: Alignment.centerRight,
              child: _TopBarButton(
                width: 42,
                background: buttonBackground,
                foreground: colors.primary,
                borderRadius: BorderRadius.circular(50),
                icon: Icons.keyboard_arrow_down_rounded,
                label: 'Collapse player',
                onTap: onCollapse,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Now Playing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontVariations: const [
                          ui.FontVariation('ROND', 100),
                        ],
                      ),
                    ),
                  ),
                  if (showCloudStream) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.cloud_rounded,
                      size: 16,
                      color: colors.onPrimaryContainer.withValues(alpha: .6),
                      semanticLabel: 'Cloud stream',
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  height: 42,
                  constraints: BoxConstraints(
                    minWidth: 50,
                    maxWidth: showCastLabel ? 190 : 58,
                  ),
                  decoration: BoxDecoration(
                    color: buttonBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(50),
                      bottomLeft: const Radius.circular(50),
                      topRight: Radius.circular(showCastLabel ? 50 : 6),
                      bottomRight: Radius.circular(showCastLabel ? 50 : 6),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onShowOutput,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 14,
                          right: showCastLabel ? 16 : 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: bluetoothName == null
                                  ? 'Audio output'
                                  : 'Audio output: $bluetoothName',
                              child: ExcludeSemantics(
                                child:
                                    remoteRouteName != null || isCastConnecting
                                    ? Icon(
                                        Icons.cast_rounded,
                                        size: 24,
                                        color: colors.primary,
                                      )
                                    : isBluetoothActive
                                    ? Icon(
                                        Icons.bluetooth_rounded,
                                        size: 24,
                                        color: colors.primary,
                                      )
                                    : SvgPicture.asset(
                                        'assets/icons/mobile_speaker.svg',
                                        width: 24,
                                        height: 24,
                                        colorFilter: ColorFilter.mode(
                                          colors.primary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                              ),
                            ),
                            if (showCastLabel) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  isCastConnecting
                                      ? 'Connecting'
                                      : remoteRouteName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: colors.primary),
                                ),
                              ),
                              if (isCastConnecting) ...[
                                const SizedBox(width: 12),
                                SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _TopBarButton(
                  width: 50,
                  background: buttonBackground,
                  foreground: colors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                    topRight: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                  icon: Icons.queue_music_rounded,
                  label: 'Open queue',
                  onTap: onShowQueue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.width,
    required this.background,
    required this.foreground,
    required this.borderRadius,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double width;
  final Color background;
  final Color foreground;
  final BorderRadius borderRadius;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 42,
      child: Material(
        color: background,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, color: foreground, semanticLabel: label),
        ),
      ),
    );
  }
}
