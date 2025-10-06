# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JapanAnimeMaps (JAM) is a cross-platform Flutter application focused on anime pilgrimage in Japan. Users can check-in at anime locations, share posts with photos/videos, and explore content from other users. The app features location-based services, social networking, e-commerce, and multilingual support (Japanese/English).

## Technology Stack

- **Flutter**: 3.22.2
- **Dart**: 3.4.3
- **Firebase**: Full integration (Auth, Firestore, Storage, Functions, Messaging, Analytics)
- **Stripe**: Payment processing
- **Google Maps**: Location services
- **RevenueCat**: In-app purchases
- **AdMob**: Advertisement integration

## Development Commands

### Flutter Commands
```bash
flutter clean                    # Clean build cache
flutter pub get                  # Install dependencies
flutter pub upgrade              # Update dependencies
flutter analyze                  # Run static analysis
flutter build apk               # Build Android APK
flutter build ipa               # Build iOS IPA
flutter run                     # Run in debug mode
flutter run --release           # Run in release mode
```

### Firebase Functions
```bash
cd functions
npm install                      # Install functions dependencies
npm run lint                     # Lint functions code
npm run build                    # Build functions
firebase deploy --only functions # Deploy functions
```

### Testing
The project uses Flutter's standard testing framework. Run tests with:
```bash
flutter test                     # Run unit and widget tests
```

## Project Architecture

### Feature-Based Directory Structure

The codebase follows a feature-based architecture where each major functionality is contained in its own directory under `lib/`:

- **`apps_about/`**: Application information and licensing
- **`badge_ranking/`**: User ranking and badge system
- **`camera/`**: Camera integration for posts
- **`components/`**: Reusable UI components and utilities
- **`event_tab/`**: Event listing and anime event management
- **`help_page/`**: Help system with chat and email support
- **`home_page/`**: Main landing and dashboard screens
- **`login_page/`**: Authentication flow (email, social login, onboarding)
- **`manual_page/`**: User manuals and legal documents (terms, privacy)
- **`map_page/`**: Google Maps integration and location services
- **`point_page/`**: User point system and rewards
- **`post_page/`**: Social posting with timeline and content management
- **`shop/`**: E-commerce functionality with Stripe integration
- **`spot_page/`**: Anime location database and check-in features
- **`src/`**: Core utilities, analytics, and navigation components

### Multilingual Architecture

The app supports Japanese and English through parallel file structure:
- Base files contain Japanese content
- Files with `_en` suffix contain English translations
- Examples: `manual.dart` (Japanese) and `manual_en.dart` (English)

### State Management and Services

- **Services**: Located in feature directories (`service/` subdirectories)
- **Models**: Data models in `models/` subdirectories within features
- **Repositories**: Data access layer (e.g., `analytics_repository.dart`)
- **Navigation**: Central navigation in `bottomnavigationbar.dart`

### Firebase Integration

- **Authentication**: Multi-provider (email, Google, Apple)
- **Firestore**: Primary database for user data and posts
- **Storage**: Media file storage
- **Functions**: Server-side logic in TypeScript (`functions/` directory)
- **FCM**: Push notifications with background message handling
- **Analytics**: User behavior tracking and conversion metrics

## Development Guidelines

### Code Organization
1. **Feature Isolation**: Keep related functionality within the same feature directory
2. **Component Reuse**: Place shared components in `components/` directory
3. **Service Layer**: Use service classes for business logic and API integration
4. **Multilingual**: Create `_en` versions for user-facing content

### Branch Strategy
- Main development branch: `develop`
- Feature branches: Branch from `develop`, merge back to `develop`
- Code reviews: Required for all pull requests with team notification via Slack (`@channel` in `team-mobile_dev`)

### Firebase Configuration
- Project ID: `anime-97d2d`
- Multi-platform configuration in `firebase.json`
- Platform-specific configs in respective directories (iOS, Android, Web)

### Dependencies Management
The project uses extensive Firebase integration and location services. Key dependency categories:
- **Firebase**: Authentication, database, storage, messaging, analytics
- **UI/UX**: Material Design, custom components, animations, ratings
- **Location**: Google Maps, geocoding, location permissions
- **Media**: Image processing, video playback, camera integration
- **Payments**: Stripe, in-app purchases, RevenueCat
- **Social**: Sharing, chat functionality, social authentication

### Platform-Specific Considerations
- **iOS**: Currently released, uses Cocoapods for dependency management
- **Android**: In preparation for release, uses Gradle build system
- **Permissions**: Requires location, camera, and notification permissions