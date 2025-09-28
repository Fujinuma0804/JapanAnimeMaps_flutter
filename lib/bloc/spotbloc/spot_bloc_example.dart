// Example usage of SpotBloc in a widget
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parts/bloc/spotbloc/spotbloc.dart';
import 'package:parts/bloc/spotbloc/spot_event.dart';
import 'package:parts/bloc/spotbloc/spot_state.dart';
import 'package:parts/Dataprovider/model/spot_model.dart';

class SpotListWidget extends StatelessWidget {
  const SpotListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SpotBloc()..add(SpotFetchInitial()),
      child: const SpotListView(),
    );
  }
}

class SpotListView extends StatelessWidget {
  const SpotListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spots'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SpotBloc>().add(SpotRefresh());
            },
          ),
        ],
      ),
      body: BlocBuilder<SpotBloc, SpotState>(
        builder: (context, state) {
          if (state is SpotLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SpotError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SpotBloc>().add(SpotFetchInitial());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SpotLoaded) {
            return ListView.builder(
              itemCount: state.spots.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.spots.length) {
                  // Load more button
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<SpotBloc>().add(SpotFetchMore());
                      },
                      child: const Text('Load More'),
                    ),
                  );
                }

                final spot = state.spots[index];
                return ListTile(
                  title: Text(spot.title),
                  subtitle: Text(spot.text),
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(spot.imagePath),
                  ),
                );
              },
            );
          }

          return const Center(child: Text('No data'));
        },
      ),
    );
  }
}
