import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

part 'userinfo_event.dart';
part 'userinfo_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<DocumentSnapshot> _userStream;

  UserBloc() : super(UserInitial()) {
    on<InitializeUser>(_onInitializeUser);
    on<UpdateUserLanguage>(_onUpdateUserLanguage);
    on<UpdateWelcomeStatus>(_onUpdateWelcomeStatus);
    on<UpdateCorrectCount>(_onUpdateCorrectCount);
  }

  Future<void> _onInitializeUser(
    InitializeUser event,
    Emitter<UserState> emit,
  ) async {
    try {
      emit(UserLoading());

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(UserError('No user logged in'));
        return;
      }

      // Setup user stream
      _userStream = _firestore.collection('users').doc(user.uid).snapshots();

      // Get initial user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        emit(
          UserDataLoaded(
            user: user,
            language: userData['language'] ?? 'English',
            hasSeenWelcome: userData['hasSeenWelcome'] ?? false,
          ),
        );
      } else {
        // Create user document if it doesn't exist
        await _firestore.collection('users').doc(user.uid).set({
          'language': 'English',
          'hasSeenWelcome': false,
          'correctCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        emit(
          UserDataLoaded(
            user: user,
            language: 'English',
            hasSeenWelcome: false,
          ),
        );
      }

      // Update correct count
      add(UpdateCorrectCount(userId: user.uid));
    } catch (e) {
      emit(UserError('Failed to initialize user: $e'));
    }
  }

  Future<void> _onUpdateUserLanguage(
    UpdateUserLanguage event,
    Emitter<UserState> emit,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'language': event.language,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update state
      if (state is UserDataLoaded) {
        final currentState = state as UserDataLoaded;
        emit(currentState.copyWith(language: event.language));
      } else if (state is UserInitialized) {
        final currentState = state as UserInitialized;
        emit(
          UserDataLoaded(
            user: currentState.user,
            language: event.language,
            hasSeenWelcome: false,
          ),
        );
      }
    } catch (e) {
      print('Error updating user language: $e');
      emit(UserError('Failed to update language: $e'));
    }
  }

  Future<void> _onUpdateWelcomeStatus(
    UpdateWelcomeStatus event,
    Emitter<UserState> emit,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'hasSeenWelcome': event.hasSeenWelcome,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update state
      if (state is UserDataLoaded) {
        final currentState = state as UserDataLoaded;
        emit(currentState.copyWith(hasSeenWelcome: event.hasSeenWelcome));
      } else if (state is UserInitialized) {
        final currentState = state as UserInitialized;
        emit(
          UserDataLoaded(
            user: currentState.user,
            language: 'English',
            hasSeenWelcome: event.hasSeenWelcome,
          ),
        );
      }
    } catch (e) {
      print('Error updating welcome status: $e');
      emit(UserError('Failed to update welcome status: $e'));
    }
  }

  Future<void> _onUpdateCorrectCount(
    UpdateCorrectCount event,
    Emitter<UserState> emit,
  ) async {
    try {
      int correctCount = 0;

      // Count correct check-ins
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(event.userId)
          .collection('check_ins')
          .where('isCorrect', isEqualTo: true)
          .get();

      correctCount = snapshot.docs.length;

      // Update user document with correct count
      await _firestore.collection('users').doc(event.userId).update({
        'correctCount': correctCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('Correct count updated: $correctCount');
    } catch (e) {
      print('Error updating correct count: $e');
      // Don't emit error state for this as it's not critical
    }
  }

  // Public method to get user stream for other parts of the app
  Stream<DocumentSnapshot> get userStream => _userStream;

  @override
  Future<void> close() {
    // Clean up resources if needed
    return super.close();
  }
}
