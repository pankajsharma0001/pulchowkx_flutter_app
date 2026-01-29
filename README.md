# Pulchowk X

**Pulchowk X** is a comprehensive campus ecosystem designed specifically for the students and faculty of Pulchowk Campus. It integrates administrative tasks, social interaction, and campus utility into a single, seamless platform.

---

## 🌟 Core Features

### 📍 Interactive Campus Map
Navigate Pulchowk Campus with ease.
- **Advanced Navigation**: Real-time directions using GPS and OSRM routing.
- **Campus-Specific Markers**: Custom icons for labs, departments, parking, and landmarks.
- **Satellite Toggle**: Switch between high-resolution satellite imagery and clean architectural maps.
- **Boundary Mask**: Focuses strictly on the campus area for a cleaner interface.

### 📅 Event Management
Stay updated with all campus club activities.
- **Club Dashboard**: Admins can create and manage events with banners and detailed descriptions.
- **External Registration**: Seamlessly link to external forms (Google Forms, etc.) with smart redirection.
- **Registration Tracking**: Admins can view and export registered student lists.
- **Favorites & Reminders**: Save events for offline viewing and receive alerts.

### 🏫 Digital Classroom
A unified workspace for academics.
- **Assignment Management**: Teachers can post assignments and view student submissions.
- **Subject Hub**: Students can access materials and track their academic progress.
- **Real-time Updates**: Instant notifications for new academic posts.

### 🛒 Campus Marketplace
Safe and simple peer-to-peer trading.
- **Student-Run Bazaar**: Buy and sell books, equipment, and other academic resources.
- **Filters & Search**: Categorized listings for efficient browsing.
- **Secure Integration**: Linked with campus authentication for verified users.

### 🤖 AI-Powered Chatbot
The ultimate campus guide.
- **Intelligent Q&A**: Answers campus-related queries and provides navigation help.
- **Map Integration**: Can plot routes directly on the interactive map based on user requests.
- **Theme Aware**: Seamlessly adapts to the application's aesthetic.

### 🎨 Premium UI/UX
Designed for daily use.
- **Advanced Dark Mode**: A stunning, high-contrast dark theme that reduces eye strain.
- **Offline Reliability**: Robust caching for profile data, event lists, and favorites.
- **Smooth Animations**: High-performance transitions and interactive elements.

---

## 🛠 Tech Stack

### Mobile App (Flutter)
- **Framework**: Flutter with Dart
- **State Management**: Listenable & BuildContext-aware patterns
- **Maps**: Native MapLibre integration with custom symbol layers
- **Local Storage**: Secure local caching for offline support

### Backend
- **Core**: Node.js & TypeScript
- **Database**: PostgreSQL with Drizzle ORM (hosted on Neon)
- **Authentication**: Firebase Auth with Google Sign-in integration
- **File Storage**: Custom image upload service for banners and profiles

---

## 🚀 Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pankajsharma0001/pulchowkx_flutter_app.git
   ```
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the app**:
   ```bash
   flutter run
   ```

---

*Made with ❤️ for Pulchowk Campus.*
