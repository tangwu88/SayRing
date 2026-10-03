import 'widgets/safe_network_image.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/feature_models.dart';
import '../l10n/global_locale_controller.dart';
import '../l10n/ui_labels.dart';
import '../domain/ecg_waveform.dart';
import '../domain/health_interpretation.dart';
import '../domain/health_record_validation.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/device_watch_face_market_service.dart';
import '../services/sleep_health_projection.dart';
import 'health_ui_owner.dart';
import 'app_theme.dart';
import 'ai_content_gate.dart';
import 'brand_assets.dart';
import 'global_auth_page.dart';
import 'global_code_login_page.dart';
import 'global_legal_page.dart';
import 'global_care_page.dart';
import 'health_reports_page.dart';
import 'health_trend_page.dart';
import 'prototype_pages.dart';
import 'shop_pages.dart';
import 'sleep_detail_widgets.dart';
import 'watch_face_market_page.dart';

import 'pages/content.dart';
import 'pages/notifications.dart';
import 'media_url.dart';
import 'widgets/inline_notice.dart';

export 'pages/content.dart';
export 'pages/notifications.dart';

part 'pages/auth.dart';
part 'pages/dashboard.dart';
part 'pages/health.dart';
part 'pages/sports.dart';
part 'pages/ai.dart';
part 'pages/devices.dart';
part 'pages/legacy_care.dart';
part 'pages/profile.dart';
part 'pages/commerce.dart';
part 'pages/settings.dart';
part 'pages/shared.dart';
