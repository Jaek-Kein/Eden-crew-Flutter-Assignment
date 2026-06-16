import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../theme/app_assets.dart';
import '../../../../theme/app_theme.dart';
import '../layout/search_layout_spec.dart';

class SearchToast extends StatelessWidget {
  const SearchToast({required this.layout, required this.message, super.key});

  final SearchLayoutSpec layout;
  final String message;

  @override
  Widget build(BuildContext context) {
    // Figma: ClipRRect → BackdropFilter(blur) → glass container with purple border/glow
    // 하트 아이콘 우하단에 체크 아이콘을 Stack으로 합성
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: SearchLayoutSpec.toastHeight,
          padding:
              EdgeInsets.symmetric(horizontal: 16 * layout.horizontalScale),
          decoration: BoxDecoration(
            color: AppDerivedColors.searchToastBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppDerivedColors.searchToastBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: AppDerivedColors.searchToastGlow,
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Stack(
                  children: [
                    AppAssetSlotIcon(
                      key: const Key('search-toast-favorite-icon'),
                      assetPath: AppAssets.favoriteHeart,
                      slotWidth: 20,
                      slotHeight: 20,
                      assetWidth: AppAssetSizes.favoriteHeart.width,
                      assetHeight: AppAssetSizes.favoriteHeart.height,
                      color: AppColors.mainAndAccent.up_f93f62,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: AppAssetSlotIcon(
                        key: const Key('search-toast-check-icon'),
                        assetPath: AppAssets.toastCheck,
                        slotWidth: 10,
                        slotHeight: 10,
                        assetWidth: AppAssetSizes.toastCheck.width,
                        assetHeight: AppAssetSizes.toastCheck.height,
                        color: AppColors.text.text_fafafa,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.searchToast,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
