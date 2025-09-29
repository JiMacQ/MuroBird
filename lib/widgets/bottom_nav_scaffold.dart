import 'package:flutter/material.dart';
import '../core/routes.dart';
import '../core/theme.dart';

class BottomNavScaffold extends StatefulWidget {
  const BottomNavScaffold({
    super.key,
    required this.child,
    this.index, // Home usa null
  });

  final Widget child;
  final int? index;

  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold> {
  void _go(int i) {
    if (widget.index == i) return;
    final routes = [
      Routes.help,
      Routes.recordings,
      Routes.history,
      Routes.settings,
    ];
    Navigator.pushReplacementNamed(context, routes[i]);
  }

  void _goHome() {
    if (ModalRoute.of(context)?.settings.name == Routes.home) return;
    Navigator.pushReplacementNamed(context, Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 380;

    return Scaffold(
      extendBody: true,
      body: widget.child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _goHome,
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.home),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
            child: BottomAppBar(
              color: kNavBg,
              elevation: 0,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: SizedBox(
                height: compact ? 60 : 66,
                child: Row(
                  children: [
                    // LADO IZQUIERDO
                    Expanded(
                      child: _SegmentRow(
                        leftRounded: true,
                        items: [
                          _ItemData(Icons.help_outline, 'Ayuda'),
                          _ItemData(
                            Icons.graphic_eq,
                            compact ? 'Grab.' : 'Grabaciones',
                          ),
                        ],
                        selectedIndex: widget.index == null
                            ? -1
                            : (widget.index! <= 1 ? widget.index! : -1),
                        onTapIndex: (i) => _go(i),
                      ),
                    ),
                    const SizedBox(width: 72), // Notch FAB
                    // LADO DERECHO
                    Expanded(
                      child: _SegmentRow(
                        rightRounded: true,
                        items: [
                          _ItemData(Icons.history, 'Historial'),
                          _ItemData(
                            Icons.settings,
                            compact ? 'Config' : 'Configuración',
                          ),
                        ],
                        baseIndex: 2,
                        selectedIndex: widget.index == null
                            ? -1
                            : (widget.index! >= 2 ? widget.index! : -1),
                        onTapIndex: (i) => _go(i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: kBg,
    );
  }
}

class _ItemData {
  final IconData icon;
  final String label;
  const _ItemData(this.icon, this.label);
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    super.key,
    required this.items,
    required this.onTapIndex,
    this.selectedIndex = -1,
    this.baseIndex = 0,
    this.leftRounded = false,
    this.rightRounded = false,
  });

  final List<_ItemData> items;
  final void Function(int index) onTapIndex;
  final int selectedIndex;
  final int baseIndex; // 0 o 2 (según lado)
  final bool leftRounded;
  final bool rightRounded;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(leftRounded ? 26 : 0),
      bottomLeft: Radius.circular(leftRounded ? 26 : 0),
      topRight: Radius.circular(rightRounded ? 26 : 0),
      bottomRight: Radius.circular(rightRounded ? 26 : 0),
    );

    return Container(
      decoration: BoxDecoration(color: kNavBg, borderRadius: borderRadius),
      child: Row(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Separador vertical
            return Container(
              width: 1,
              height: 36,
              color: Colors.white.withOpacity(.85),
            );
          }
          final item = items[i ~/ 2];
          final idx = baseIndex + (i ~/ 2);
          final selected = selectedIndex == idx;
          final color = selected ? kBrand : Colors.black54;

          return Expanded(
            child: InkWell(
              onTap: () => onTapIndex(idx),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: color, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
