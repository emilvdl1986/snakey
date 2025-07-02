import 'package:flutter/material.dart';

/// Notification for swipe direction
class SwipeDirectionNotification extends Notification {
  final String direction;
  SwipeDirectionNotification(this.direction);
}

/// A reusable widget for swipe controls (mobile & web)

class SwipeController extends StatelessWidget {
  final BuildContext notificationContext;
  const SwipeController({super.key, required this.notificationContext});

  void _handleHorizontalDrag(DragEndDetails details) {
    debugPrint('Horizontal drag end: primaryVelocity=${details.primaryVelocity}');
    if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
      debugPrint('Swipe LEFT');
      SwipeDirectionNotification('left').dispatch(notificationContext);
    } else if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
      debugPrint('Swipe RIGHT');
      SwipeDirectionNotification('right').dispatch(notificationContext);
    }
  }

  void _handleVerticalDrag(DragEndDetails details) {
    debugPrint('Vertical drag end: primaryVelocity=${details.primaryVelocity}');
    if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
      debugPrint('Swipe UP');
      SwipeDirectionNotification('up').dispatch(notificationContext);
    } else if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
      debugPrint('Swipe DOWN');
      SwipeDirectionNotification('down').dispatch(notificationContext);
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta != null && details.primaryDelta! < -2) {
      SwipeDirectionNotification('left').dispatch(notificationContext);
    } else if (details.primaryDelta != null && details.primaryDelta! > 2) {
      SwipeDirectionNotification('right').dispatch(notificationContext);
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta != null && details.primaryDelta! < -2) {
      SwipeDirectionNotification('up').dispatch(notificationContext);
    } else if (details.primaryDelta != null && details.primaryDelta! > 2) {
      SwipeDirectionNotification('down').dispatch(notificationContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.25,
      width: MediaQuery.of(context).size.width * 0.95,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue, width: 4),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onHorizontalDragEnd: _handleHorizontalDrag,
        onVerticalDragEnd: _handleVerticalDrag,
        child: const Center(
          child: Text(
            'Swipe to direct',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
