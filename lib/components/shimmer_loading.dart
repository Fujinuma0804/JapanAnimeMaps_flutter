import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading {
  // Base shimmer configuration
  static Widget baseShimmer({
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      child: child,
    );
  }

  // Anime card shimmer
  static Widget animeCardShimmer() {
    return Container(
      margin: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          baseShimmer(
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title placeholder
                baseShimmer(
                  child: Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Subtitle placeholder
                baseShimmer(
                  child: Container(
                    height: 16,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // Rating placeholder
                baseShimmer(
                  child: Container(
                    height: 16,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Grid shimmer for anime list
  static Widget animeGridShimmer({int itemCount = 6}) {
    return GridView.builder(
      padding: EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => animeCardShimmer(),
    );
  }

  // List shimmer for anime list
  static Widget animeListShimmer({int itemCount = 5}) {
    return ListView.builder(
      padding: EdgeInsets.all(8.0),
      itemCount: itemCount,
      itemBuilder: (context, index) => animeCardShimmer(),
    );
  }

  // Image shimmer placeholder
  static Widget imageShimmer({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return baseShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Text shimmer placeholder
  static Widget textShimmer({
    required double width,
    double height = 16,
    BorderRadius? borderRadius,
  }) {
    return baseShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }

  // Button shimmer placeholder
  static Widget buttonShimmer({
    required double width,
    double height = 40,
    BorderRadius? borderRadius,
  }) {
    return baseShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Full screen loading shimmer
  static Widget fullScreenShimmer() {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header shimmer
              baseShimmer(
                child: Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Content shimmer
              animeListShimmer(itemCount: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Custom shimmer for specific use cases
  static Widget customShimmer({
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
    Duration? period,
  }) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      period: period ?? Duration(milliseconds: 1500),
      child: child,
    );
  }
}

// Loading state wrapper
class LoadingWrapper extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? loadingWidget;
  final bool useShimmer;

  const LoadingWrapper({
    Key? key,
    required this.isLoading,
    required this.child,
    this.loadingWidget,
    this.useShimmer = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      if (useShimmer && loadingWidget == null) {
        return ShimmerLoading.fullScreenShimmer();
      }
      return loadingWidget ??
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          );
    }
    return child;
  }
}
