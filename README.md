# LEVELS — Smart Water Monitoring System (v5)
### MIT ADT University • Enterprise IoT & SCADA Telemetry

LEVELS is an enterprise-grade IoT smart water monitoring and SCADA analytics platform designed for campus-wide infrastructure at **MIT ADT University**.

The mobile application monitors physical telemetry from distributed edge hardware (ESP32 controllers with ultrasonic / pressure sensors) transmitting telemetry via MQTT / AWS IoT Core.

---

## 🏗️ Architecture Overview

```
Edge Nodes (ESP32)  ──>  AWS IoT Core (MQTT)  ──>  Backend Telemetry Engine (REST / WebSocket)
                                                                │
                                    ┌───────────────────────────┴───────────────────────────┐
                                    ▼                                                       ▼
                       Flutter Enterprise App                                  Interactive Web Simulator
                 (Android / iOS / Desktop / Web)                                 (HTML5 / Modern CSS / JS)
```

### Key Modules (`lib/`)

* **`lib/main.dart`**: App entrypoint configuring providers (`TankProvider`, `AuthService`) and Material 3 theme modes.
* **`lib/models/`**:
  * `tank.dart`: Core tank entity with capacity, level percentages, sensor spans, telemetry timestamps, freshness, and status helpers (`isOnline`, `isStale`).
  * `historical_graph_config.dart`: Metric calculations, ranges (1h, 24h, 7d, 30d, 90d, custom), statistical aggregates (min, max, mean, consumption rate).
  * `tank_history.dart` & `tank_telemetry.dart`: Time-series sensor log structures.
  * `alert.dart` & `notification.dart`: Threshold alarms and system notifications.
  * `user_model.dart`: Authentication profiles and RBAC (Admin / Operator).
* **`lib/providers/`**:
  * `tank_provider.dart`: Centralized `ChangeNotifier` managing live tanks state, telemetry polling/auto-refresh lifecycle, filtering, and notification state.
* **`lib/services/`**:
  * `api_config.dart` & `api_service.dart`: REST endpoints and network client.
  * `auth_service.dart`: Authentication, session persistence, role verification.
  * `tank_service.dart`: Tank CRUD, telemetry parsing, and history caching.
  * `mqtt_service.dart`: Real-time telemetry broker integration.
  * `export_service.dart`: CSV and PDF telemetry export generation.
* **`lib/screens/`**:
  * `splash/splash_screen.dart`: Animated launch screen with the crystal droplet logo on pure white background.
  * `login/login_screen.dart`: Authentication screen with secure access controls and operator identity.
  * `dashboard/dashboard_screen.dart`: 4-tab shell (Overview, Alerts, Reports, Settings) with bottom navigation and app lifecycle observer.
  * `dashboard/tank_details/tank_details_screen.dart`: Deep-dive telemetry inspection, pump control status, real-time wave simulation, and historical trends.
  * `dashboard/alerts/alerts_screen.dart`: Live alarm logs categorized by severity (Critical, Warning, Normal, Offline).
  * `dashboard/reports/reports_screen.dart`: Analytical summaries, consumption breakdown, and data export sheets.
  * `dashboard/settings/settings_screen.dart`: Server URL configuration, telemetry poll interval, and theme controls.
  * `add_tank/` & `update_tank/` & `delete_tank/`: Administrative calibration and sensor configuration workflows.
* **`lib/widgets/`**:
  * `animated_tank.dart`: Fluid custom painter with dynamic water wave physics reflecting fill percentages.
  * `tank_card.dart`: Interactive squircle dashboard card displaying real-time level, status chip, and freshness badge.
  * `kpi_card.dart`: High-level SCADA metrics (Total Volume, Campus Capacity, Active Alerts, Operational Tanks).
  * `charts/tank_analytics_graph.dart`: FL Chart powered historical line graph with range switching and statistical overlays.
* **`assets/icon/crystal_drop.png`**: High-resolution 3D multi-faceted crystal droplet logo representing water purity and tiered telemetry metrics.

---

## 🚀 Running the Project

### Prerequisites
* Flutter SDK (3.18.0+)
* Dart SDK (3.12.2+)

### Commands
```bash
# 1. Install dependencies
flutter pub get

# 2. Run analysis
flutter analyze

# 3. Launch on Chrome (Web)
flutter run -d chrome

# 4. Launch on connected Android device / emulator
flutter run
```

---

## 🌐 Web Prototype Simulator
Included in root (`index.html`, `styles.css`, `app.js`) is an in-browser device frame prototype for stakeholder reviews and rapid UI testing without compilation overhead.
