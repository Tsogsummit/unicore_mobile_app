import 'package:flutter/cupertino.dart';

import 'package:unicore_mobile_app/widgets/cards.dart';
import 'package:unicore_mobile_app/widgets/tiles.dart';

/// Preview tab summarizing chat, tasks and notification features.
class ChatTasksTab extends StatelessWidget {
  const ChatTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      children: const [
        Text('Ажил, чат, мэдэгдэл', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Дотоод чат'),
              PreviewTile(icon: CupertinoIcons.chat_bubble_2_fill, title: 'Channels', subtitle: 'GET /chat/channels'),
              PreviewTile(icon: CupertinoIcons.person_2_fill, title: 'Online users', subtitle: 'GET /chat/online-users'),
              PreviewTile(icon: CupertinoIcons.search, title: 'Search', subtitle: 'GET /chat/search'),
            ],
          ),
        ),
        SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Tasks / Meetings / Leave'),
              PreviewTile(icon: CupertinoIcons.check_mark_circled_solid, title: 'Tasks', subtitle: 'GET/POST /tasks'),
              PreviewTile(icon: CupertinoIcons.calendar, title: 'Meetings', subtitle: 'GET/POST /meetings'),
              PreviewTile(icon: CupertinoIcons.doc_text_fill, title: 'Leave requests', subtitle: 'GET/POST /leave-requests'),
            ],
          ),
        ),
        SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Notifications'),
              PreviewTile(icon: CupertinoIcons.bell_fill, title: 'Unread count', subtitle: 'GET /notifications/unread-count'),
              PreviewTile(icon: CupertinoIcons.checkmark_alt_circle_fill, title: 'Read all', subtitle: 'POST /notifications/read-all'),
            ],
          ),
        ),
      ],
    );
  }
}
