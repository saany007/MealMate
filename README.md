Here is a formal, concise overview of the **MealMate** project.

---

# MealMate

MealMate is a Flutter application engineered to facilitate communal meal management. It integrates financial tracking, duty scheduling, and inventory management into a centralized platform for shared households.

## Core Modules

* **Dashboard & Analytics:** Provides real-time visibility into financial balances, meal consumption statistics, and upcoming meal statuses based on attendance data.
* **Shopping Management:** Manages the lifecycle of shopping trips (Pending, Active, Historical) and utilizes fairness algorithms to suggest shopper assignments based on trip frequency and expenditure.
* **Cooking Rotation:** Automates cooking schedules using configurable frequencies (Daily, Weekly) and fairness logic. Supports member availability preferences and manual schedule overrides.
* **Recipe & Meal Planning:** Integrates with the Spoonacular API to enable recipe discovery, filtering by dietary requirements, and direct integration with meal calendars and grocery lists.
* **Financial Settlements:** Generates monthly settlement reports, calculates cost-per-meal metrics, and facilitates debt settlement through transaction tracking.

## Technical Architecture

* **Frontend Framework:** Flutter (Dart).
* **Backend:** Google Firebase (Cloud Firestore) for data persistence and real-time synchronization.
* **State Management:** Provider pattern for efficient state propagation.
* **Integration:** RESTful API integration with Spoonacular for culinary data.

## Configuration

To deploy this application, the following configurations are required:

1. **Firebase:** Configure a project in the Firebase Console and place the `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) in the respective app directories.
2. **API Keys:** Obtain a valid API key from Spoonacular and configure it within `lib/services/recipe_service.dart`.

## Project Structure

The codebase adheres to a Service-Repository pattern:

* `lib/models/`: Data models defining business entities (e.g., `MealSystemModel`, `ExpenseModel`).
* `lib/screens/`: UI implementation for functional modules.
* `lib/services/`: Business logic and data access layers.
* `lib/widgets/`: Reusable interface components.