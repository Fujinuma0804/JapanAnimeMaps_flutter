import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parts/Dataprovider/model/spot_model.dart';
import 'package:parts/bloc/spotbloc/spot_event.dart';
import 'package:parts/bloc/spotbloc/spot_state.dart';
import 'package:parts/bloc/spotbloc/spotbloc.dart';

class SpotScreen extends StatefulWidget {
  const SpotScreen({Key? key}) : super(key: key);

  @override
  State<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends State<SpotScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        _scrollController.position.outOfRange == false) {
      context.read<SpotBloc>().add(SpotFetchMore());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SpotBloc()..add(SpotFetchInitial()),
      child: Scaffold(
        appBar: AppBar(
          title: const Icon(
            Icons.check_circle,
            color: Color(0xFF00008b),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '■ チェクイン済みのスポット一覧',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BlocBuilder<SpotBloc, SpotState>(
                  builder: (context, state) {
                    if (state is SpotInitial || state is SpotLoading) {
                      return const Center();
                    }

                    if (state is SpotError) {
                      return Center(child: Text(state.message));
                    }

                    if (state is SpotLoaded) {
                      return _buildSpotGrid(state);
                    }

                    return const Center(child: Text('Unknown state'));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotGrid(SpotLoaded state) {
    if (state.spots.isEmpty) {
      return const Center(
        child: Text(
          'チェックイン済みのスポットがありません',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: state.spots.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.spots.length) {
          return const Center();
        }

        final spot = state.spots[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpotDetailScreen(spot: spot),
              ),
            );
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: spot.imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Container(
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.all(8),
                  color: Colors.black45,
                  child: Text(
                    spot.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// spot_detail_screen.dart
class SpotDetailScreen extends StatelessWidget {
  final Spot spot;

  const SpotDetailScreen({Key? key, required this.spot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          spot.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Image
              Container(
                width: double.infinity,
                height: isPortrait ? screenHeight * 0.3 : screenHeight * 0.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    spot.imagePath,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.03),

              // Title with responsive font size
              Text(
                spot.title,
                style: TextStyle(
                  fontSize: screenWidth < 600 ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: screenHeight * 0.02),

              // Description text with responsive font size
              Text(
                spot.text,
                style: TextStyle(
                  fontSize: screenWidth < 600 ? 16 : 18,
                  height: 1.6,
                ),
                textAlign: TextAlign.justify,
              ),

              // Add some bottom padding for better scrolling
              SizedBox(height: screenHeight * 0.05),
            ],
          ),
        ),
      ),
    );
  }
}
