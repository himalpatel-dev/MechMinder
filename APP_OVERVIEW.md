# MechMinder Application Overview

MechMinder is a comprehensive Flutter-based mobile application designed to assist vehicle owners in managing and maintaining their vehicles. It allows users to track services, manage documents, monitor expenses, and receive timely reminders for maintenance and renewals.

## Key Features

### 1. Vehicle Management
- **Add & Manage Vehicles**: Users can add multiple vehicles to the app, storing details such as make, model, year, and registration number.
- **Vehicle Profiles**: Each vehicle has a dedicated profile (`VehicleDetailScreen`) displaying its status, history, and upcoming needs.
- **Detailed Specification**: Store detailed vehicle specifications including engine details, fuel type, and tank capacity.

### 2. Service & Maintenance Tracking
- **Service Logging**: Record maintenance activities (`AddServiceScreen`) including date, odometer reading, cost, and specific tasks performed (e.g., oil change, brake pad replacement).
- **Service History**: View a timeline of all past services (`ServiceHistoryTab`) to track the vehicle's maintenance lifecycle.
- **Service Templates**: Create and manage templates (`ServiceTemplatesScreen`) for common service packages to speed up data entry.

### 3. Reminders & Notifications
- **Automated Reminders**: Set up reminders (`UpcomingRemindersTab`, `AllRemindersScreen`) for:
    - periodic services (based on time or mileage).
    - insurance renewals.
    - registration/PUC usage.
- **Local Notifications**: Receive push notifications on the device to ensure important dates aren't missed.

### 4. Expense Management
- **Cost Tracking**: Log all vehicle-related expenses including fuel, services, repairs, and parts (`ExpensesTab`).
- **Statistics & Analysis**: Visualize spending habits and cost breakdown using charts (`StatsTab`, powered by `fl_chart`), helping users identify high-cost areas.

### 5. Document Management
- **Digital Glovebox**: Store digital copies of essential documents (`DocumentsScreen`, `VehiclePapersScreen`) such as:
    - Driving License
    - Insurance Policy
    - Registration Certificate (RC)
    - Pollution Under Control (PUC) certificate
- **Image/File Attachments**: Upload photos or PDFs of documents using the camera or file picker.

### 6. Vendor Management
- **Mechanic/Shop Directory**: Keep a list of preferred vendors, mechanics, and service centers (`VendorListScreen`) for quick access when needed.

### 7. Settings & Customization
- **Theme Customization**: Personalize the app's look and feel with light/dark modes and custom color schemes (`AppSettingsScreen`, `flutter_colorpicker`).
- **Data Management**: options to manage app data (`sqflite` for local storage).

## Technical Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Local Database**: SQFlite
- **UI Components**:
    - `flutter_staggered_animations` for smooth list transitions.
    - `carousel_slider` for image galleries.
    - `photo_view` for zooming into document images.
- **Utilities**:
    - `workmanager` for background tasks (reminders).
    - `excel` for potentially exporting reports.
    - `share_plus` for sharing vehicle details or logs.

## Use Cases
- A car owner wanting to keep track of when the next oil change is due.
- A fleet manager needing to monitor the service history and expenses of multiple vehicles.
- A user wanting to have digital backups of their vehicle papers handy at all times.
