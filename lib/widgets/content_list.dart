import 'package:flutter/material.dart';
import 'package:ransh_app/models/ransh_content.dart';
import 'package:ransh_app/models/user_session.dart';
import 'package:ransh_app/screens/home_screen.dart'; // For ContentCard

class ContentList extends StatelessWidget {
  final String title;
  final List<RanshContent> contentList;
  final Function(RanshContent) onContentTap;
  final bool isTV;
  final UserSession? userSession;

  const ContentList({
    super.key,
    required this.title,
    required this.contentList,
    required this.onContentTap,
    this.isTV = false,
    this.userSession,
  });

  @override
  Widget build(BuildContext context) {
    if (contentList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTV ? 48 : 16,
            vertical: 8,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTV ? 24 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: isTV ? 220 : 180, // Height for card + title
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: isTV ? 48 : 16),
            scrollDirection: Axis.horizontal,
            itemCount: contentList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final content = contentList[index];
              return SizedBox(
                width: isTV ? 300 : 200, // 16:9 ratio width based on height
                child: ContentCard(
                  content: content,
                  onTap: () => onContentTap(content),
                  userSession: userSession,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
