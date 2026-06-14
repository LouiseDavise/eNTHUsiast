import 'package:enthusiast/providers/language_provider.dart';
import 'package:enthusiast/widgets/button_circle_back.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeaderMenuWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? titleZh;
  final String subTitle;
  final String? subTitleZh;
  final bool showActionIcon;
  final IconData actionIcon;
  final VoidCallback? onActionTap;
  final double height;

  const HeaderMenuWidget({
    super.key,
    required this.title,
    this.titleZh,
    required this.subTitle,
    this.subTitleZh,
    this.showActionIcon = false,
    this.actionIcon = Icons.download_rounded,
    this.onActionTap,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    final isChinese = LanguageScope.watch(context).isChinese;
    final displayTitle = (isChinese && titleZh != null) ? titleZh! : title;
    final displaySubTitle =
        (isChinese && subTitleZh != null) ? subTitleZh! : subTitle;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      toolbarHeight: height,
      titleSpacing: 0,
      leadingWidth: 72,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: CircleBackButton(onTap: () => Navigator.pop(context)),
      ),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayTitle,
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displaySubTitle,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black45,
            ),
          ),
        ],
      ),
      actions: showActionIcon
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onActionTap ?? () {},
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      actionIcon,
                      color: const Color(0xFF1F2937),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}