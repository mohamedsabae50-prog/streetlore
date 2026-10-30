import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Translation key: about_app
  ///
  /// In en, this message translates to:
  /// **'About EgyptLore'**
  String get about_app;

  /// Translation key: attributions_title
  ///
  /// In en, this message translates to:
  /// **'Attributions'**
  String get attributions_title;

  /// Translation key: attribution_osm
  ///
  /// In en, this message translates to:
  /// **'Map tiles © OpenStreetMap contributors — open data under the Open Database License (ODbL).'**
  String get attribution_osm;

  /// Translation key: attribution_wikimedia
  ///
  /// In en, this message translates to:
  /// **'Place photos courtesy of Wikimedia Commons, used under each file\'s stated free-license terms.'**
  String get attribution_wikimedia;

  /// Translation key: about_place
  ///
  /// In en, this message translates to:
  /// **'About this place'**
  String get about_place;

  /// Translation key: add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Translation key: add_photo_btn
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get add_photo_btn;

  /// Translation key: add_photo_title
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get add_photo_title;

  /// Translation key: image_upload_error
  ///
  /// In en, this message translates to:
  /// **'Could not upload the image. Please try again.'**
  String get image_upload_error;

  /// Translation key: image_upload_success
  ///
  /// In en, this message translates to:
  /// **'Image uploaded successfully.'**
  String get image_upload_success;

  /// Translation key: image_uploading
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get image_uploading;

  /// Translation key: suggest_place_success
  ///
  /// In en, this message translates to:
  /// **'Your place suggestion was submitted.'**
  String get suggest_place_success;

  /// Translation key: ai_daily_limit_body
  ///
  /// In en, this message translates to:
  /// **'Your free messages reset at midnight UTC. Upgrade to Pro for higher AI limits.'**
  String get ai_daily_limit_body;

  /// Translation key: ai_daily_limit_title
  ///
  /// In en, this message translates to:
  /// **'You’ve reached today’s free AI message limit'**
  String get ai_daily_limit_title;

  /// Translation key: ai_upgrade_pro
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get ai_upgrade_pro;

  /// Translation key: ai_quota_reset_utc
  ///
  /// In en, this message translates to:
  /// **'Resets at midnight UTC'**
  String get ai_quota_reset_utc;

  /// Translation key: all_places
  ///
  /// In en, this message translates to:
  /// **'All Places'**
  String get all_places;

  /// Translation key: badges_title
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges_title;

  /// Translation key: browse_tours
  ///
  /// In en, this message translates to:
  /// **'Browse Tours'**
  String get browse_tours;

  /// Translation key: bt_label_decent_now
  ///
  /// In en, this message translates to:
  /// **'Decent now'**
  String get bt_label_decent_now;

  /// Translation key: bt_label_go_now
  ///
  /// In en, this message translates to:
  /// **'Go now'**
  String get bt_label_go_now;

  /// Translation key: bt_label_wait
  ///
  /// In en, this message translates to:
  /// **'Wait for a better window'**
  String get bt_label_wait;

  /// Translation key: bt_reason_best_photos
  ///
  /// In en, this message translates to:
  /// **'Best for photos'**
  String get bt_reason_best_photos;

  /// Translation key: bt_reason_breakfast
  ///
  /// In en, this message translates to:
  /// **'Breakfast spots'**
  String get bt_reason_breakfast;

  /// Translation key: bt_reason_closed
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get bt_reason_closed;

  /// Translation key: bt_reason_closed_unsafe
  ///
  /// In en, this message translates to:
  /// **'Closed, unsafe'**
  String get bt_reason_closed_unsafe;

  /// Translation key: bt_reason_cool_empty
  ///
  /// In en, this message translates to:
  /// **'Cool & empty'**
  String get bt_reason_cool_empty;

  /// Translation key: bt_reason_cool_photo
  ///
  /// In en, this message translates to:
  /// **'Cool, photogenic'**
  String get bt_reason_cool_photo;

  /// Translation key: bt_reason_dinner
  ///
  /// In en, this message translates to:
  /// **'Dinner vibes'**
  String get bt_reason_dinner;

  /// Translation key: bt_reason_golden_hour
  ///
  /// In en, this message translates to:
  /// **'Golden hour magic'**
  String get bt_reason_golden_hour;

  /// Translation key: bt_reason_hot_crowd
  ///
  /// In en, this message translates to:
  /// **'Hot & crowded'**
  String get bt_reason_hot_crowd;

  /// Translation key: bt_reason_hot_shaded
  ///
  /// In en, this message translates to:
  /// **'Hot but shaded'**
  String get bt_reason_hot_shaded;

  /// Translation key: bt_reason_lunch
  ///
  /// In en, this message translates to:
  /// **'Lunch rush'**
  String get bt_reason_lunch;

  /// Translation key: bt_reason_often_closing
  ///
  /// In en, this message translates to:
  /// **'Often closing'**
  String get bt_reason_often_closing;

  /// Translation key: bt_reason_quietest
  ///
  /// In en, this message translates to:
  /// **'Quietest, best light'**
  String get bt_reason_quietest;

  /// Translation key: bt_reason_admin_set
  ///
  /// In en, this message translates to:
  /// **'Set by admin'**
  String get bt_reason_admin_set;

  /// Translation key: bt_reason_soft_light
  ///
  /// In en, this message translates to:
  /// **'Soft light'**
  String get bt_reason_soft_light;

  /// Translation key: bt_reason_too_early
  ///
  /// In en, this message translates to:
  /// **'Too early'**
  String get bt_reason_too_early;

  /// Translation key: bt_reason_warm_ok
  ///
  /// In en, this message translates to:
  /// **'Warm but ok'**
  String get bt_reason_warm_ok;

  /// Translation key: budget_friendly
  ///
  /// In en, this message translates to:
  /// **'Budget-friendly'**
  String get budget_friendly;

  /// Translation key: cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Translation key: cat_all
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get cat_all;

  /// Translation key: cat_churches
  ///
  /// In en, this message translates to:
  /// **'Churches'**
  String get cat_churches;

  /// Translation key: cat_culture
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get cat_culture;

  /// Translation key: cat_food
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get cat_food;

  /// Translation key: cat_cafe
  ///
  /// In en, this message translates to:
  /// **'Cafes'**
  String get cat_cafe;

  /// Translation key: cat_cafes
  ///
  /// In en, this message translates to:
  /// **'Cafes'**
  String get cat_cafes;

  /// Translation key: cat_historical
  ///
  /// In en, this message translates to:
  /// **'Historical'**
  String get cat_historical;

  /// Translation key: cat_hotels
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get cat_hotels;

  /// Translation key: cat_mosques
  ///
  /// In en, this message translates to:
  /// **'Mosques'**
  String get cat_mosques;

  /// Translation key: cat_nature
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get cat_nature;

  /// Translation key: cat_shopping
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get cat_shopping;

  /// Translation key: chat_empty
  ///
  /// In en, this message translates to:
  /// **'Be the first to say hi'**
  String get chat_empty;

  /// Translation key: chat_hint
  ///
  /// In en, this message translates to:
  /// **'Say something to fellow travellers...'**
  String get chat_hint;

  /// Translation key: chat_live
  ///
  /// In en, this message translates to:
  /// **'Live chat'**
  String get chat_live;

  /// Translation key: chat_now
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get chat_now;

  /// Translation key: checked_in_streak
  ///
  /// In en, this message translates to:
  /// **'Checked in! Streak: {n}'**
  String checked_in_streak(String n);

  /// Translation key: checkin
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkin;

  /// Translation key: checkin_removed
  ///
  /// In en, this message translates to:
  /// **'Check-in removed'**
  String get checkin_removed;

  /// Translation key: unvisit_title
  ///
  /// In en, this message translates to:
  /// **'Remove check-in?'**
  String get unvisit_title;

  /// Translation key: unvisit_body
  ///
  /// In en, this message translates to:
  /// **'This will remove your check-in, deduct the points, and revoke any badges that were unlocked by it.'**
  String get unvisit_body;

  /// Translation key: unvisit_confirm
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get unvisit_confirm;

  /// Translation key: choose_gallery
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get choose_gallery;

  /// Translation key: clear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Translation key: clear_all_title
  ///
  /// In en, this message translates to:
  /// **'Clear All Saved Places?'**
  String get clear_all_title;

  /// Translation key: clear_all_warning
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove all saved places. This cannot be undone.'**
  String get clear_all_warning;

  /// Translation key: closed
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// Translation key: community_chat
  ///
  /// In en, this message translates to:
  /// **'Community Chat'**
  String get community_chat;

  /// Translation key: community_chat_sub
  ///
  /// In en, this message translates to:
  /// **'Ask travelers about this place'**
  String get community_chat_sub;

  /// Translation key: community_reviews
  ///
  /// In en, this message translates to:
  /// **'Community Reviews'**
  String get community_reviews;

  /// Translation key: cur_amount
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get cur_amount;

  /// Translation key: cur_disclaimer
  ///
  /// In en, this message translates to:
  /// **'Rates are approximate and based on mid-market averages. Check with your bank or exchange for actual rates.'**
  String get cur_disclaimer;

  /// Translation key: cur_enter_amount
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get cur_enter_amount;

  /// Translation key: cur_from
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get cur_from;

  /// Translation key: cur_to
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get cur_to;

  /// Translation key: currency_converter
  ///
  /// In en, this message translates to:
  /// **'Currency Converter'**
  String get currency_converter;

  /// Translation key: currency_converter_sub
  ///
  /// In en, this message translates to:
  /// **'EGP ↔ USD, EUR, GBP, SAR + more'**
  String get currency_converter_sub;

  /// Translation key: dark_mode
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// Translation key: dark_theme_on
  ///
  /// In en, this message translates to:
  /// **'Dark theme enabled'**
  String get dark_theme_on;

  /// Translation key: delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Translation key: delete_photo_q
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get delete_photo_q;

  /// Translation key: delete_review_q
  ///
  /// In en, this message translates to:
  /// **'Delete this review?'**
  String get delete_review_q;

  /// Translation key: discover
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// Translation key: discover_places
  ///
  /// In en, this message translates to:
  /// **'Discover Places'**
  String get discover_places;

  /// Translation key: edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Translation key: edit_name
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get edit_name;

  /// Translation key: edit_name_dialog_title
  ///
  /// In en, this message translates to:
  /// **'Change your display name'**
  String get edit_name_dialog_title;

  /// Translation key: egyptians
  ///
  /// In en, this message translates to:
  /// **'Egyptians'**
  String get egyptians;

  /// Translation key: email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Translation key: emergency_info
  ///
  /// In en, this message translates to:
  /// **'Emergency Info'**
  String get emergency_info;

  /// Translation key: emergency_info_sub
  ///
  /// In en, this message translates to:
  /// **'Hospitals, embassies, hotlines'**
  String get emergency_info_sub;

  /// Translation key: emg_call_failed
  ///
  /// In en, this message translates to:
  /// **'Cannot place call to {n}'**
  String emg_call_failed(String n);

  /// Translation key: emg_embassies
  ///
  /// In en, this message translates to:
  /// **'Embassies & Consulates'**
  String get emg_embassies;

  /// Translation key: emg_hero_sub
  ///
  /// In en, this message translates to:
  /// **'Tap any number to call. Save this page for quick access.'**
  String get emg_hero_sub;

  /// Translation key: emg_hero_title
  ///
  /// In en, this message translates to:
  /// **'Stay safe in Alexandria'**
  String get emg_hero_title;

  /// Translation key: emg_hospitals
  ///
  /// In en, this message translates to:
  /// **'Hospitals'**
  String get emg_hospitals;

  /// Translation key: emg_numbers
  ///
  /// In en, this message translates to:
  /// **'Emergency Numbers'**
  String get emg_numbers;

  /// Translation key: emg_pharmacies
  ///
  /// In en, this message translates to:
  /// **'24h Pharmacies'**
  String get emg_pharmacies;

  /// Translation key: emg_title
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emg_title;

  /// Translation key: admin_title
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get admin_title;

  /// Translation key: admin_forbidden
  ///
  /// In en, this message translates to:
  /// **'Admin only'**
  String get admin_forbidden;

  /// Translation key: admin_forbidden_sub
  ///
  /// In en, this message translates to:
  /// **'Your account is not authorised to add places.'**
  String get admin_forbidden_sub;

  /// Translation key: admin_add_new
  ///
  /// In en, this message translates to:
  /// **'Add new place'**
  String get admin_add_new;

  /// Translation key: admin_view_list
  ///
  /// In en, this message translates to:
  /// **'View places list'**
  String get admin_view_list;

  /// Translation key: admin_field_name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get admin_field_name;

  /// Translation key: admin_field_category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get admin_field_category;

  /// Translation key: admin_field_address
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get admin_field_address;

  /// Translation key: admin_field_description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get admin_field_description;

  /// Translation key: admin_field_image
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get admin_field_image;

  /// Translation key: admin_field_hours
  ///
  /// In en, this message translates to:
  /// **'Open hours'**
  String get admin_field_hours;

  /// Translation key: admin_field_rating
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get admin_field_rating;

  /// Translation key: admin_err_name
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get admin_err_name;

  /// Translation key: admin_err_category
  ///
  /// In en, this message translates to:
  /// **'Category is required (e.g. ATM, Hotel, Cafe)'**
  String get admin_err_category;

  /// Translation key: admin_submit
  ///
  /// In en, this message translates to:
  /// **'Add to map'**
  String get admin_submit;

  /// Translation key: admin_added
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get admin_added;

  /// Translation key: admin_failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get admin_failed;

  /// Translation key: admin_location_search
  ///
  /// In en, this message translates to:
  /// **'Location search (Nominatim / OpenStreetMap)'**
  String get admin_location_search;

  /// Translation key: admin_location_search_hint
  ///
  /// In en, this message translates to:
  /// **'Type a place name or address (e.g. \"Bibliotheca Alexandrina\")'**
  String get admin_location_search_hint;

  /// Translation key: admin_location_no_results
  ///
  /// In en, this message translates to:
  /// **'No results. Try a more specific query.'**
  String get admin_location_no_results;

  /// Translation key: admin_err_location
  ///
  /// In en, this message translates to:
  /// **'Pick a location from the search results first.'**
  String get admin_err_location;

  /// Translation key: emg_transport
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get emg_transport;

  /// Translation key: empty_saved_places_sub
  ///
  /// In en, this message translates to:
  /// **'Start exploring and tap the bookmark icon on any place to save it here for easy access.'**
  String get empty_saved_places_sub;

  /// Translation key: empty_saved_tours_sub
  ///
  /// In en, this message translates to:
  /// **'Tap the download icon on any tour to save it here for offline access.'**
  String get empty_saved_tours_sub;

  /// Translation key: featured
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// Translation key: filter_free
  ///
  /// In en, this message translates to:
  /// **'Free only'**
  String get filter_free;

  /// Translation key: filter_hidden_gems
  ///
  /// In en, this message translates to:
  /// **'Hidden Gems'**
  String get filter_hidden_gems;

  /// Translation key: first_photo
  ///
  /// In en, this message translates to:
  /// **'Be the first to share a photo'**
  String get first_photo;

  /// Translation key: foreigners
  ///
  /// In en, this message translates to:
  /// **'Foreigners'**
  String get foreigners;

  /// Translation key: passion_banner_title
  ///
  /// In en, this message translates to:
  /// **'A compass for every story worth telling'**
  String get passion_banner_title;

  /// Translation key: passion_banner_sub
  ///
  /// In en, this message translates to:
  /// **'Your guide to the deepest stories behind every city. Free, ad-free, and made with care. Every recommendation here is written by someone who knows the place up close.'**
  String get passion_banner_sub;

  /// Translation key: free_entry
  ///
  /// In en, this message translates to:
  /// **'Free entry'**
  String get free_entry;

  /// Translation key: geo_choose_places
  ///
  /// In en, this message translates to:
  /// **'Choose places'**
  String get geo_choose_places;

  /// Translation key: geo_distance
  ///
  /// In en, this message translates to:
  /// **'{d} km from city center'**
  String geo_distance(String d);

  /// Translation key: geo_hero_sub
  ///
  /// In en, this message translates to:
  /// **'Choose the places you want alerts for - within 500m by default.'**
  String get geo_hero_sub;

  /// Translation key: geo_hero_title
  ///
  /// In en, this message translates to:
  /// **'Get notified nearby'**
  String get geo_hero_title;

  /// Translation key: geo_monitoring_off
  ///
  /// In en, this message translates to:
  /// **'Monitoring paused'**
  String get geo_monitoring_off;

  /// Translation key: geo_monitoring_on
  ///
  /// In en, this message translates to:
  /// **'Monitoring your location for nearby places'**
  String get geo_monitoring_on;

  /// Translation key: geo_title
  ///
  /// In en, this message translates to:
  /// **'Geofencing Alerts'**
  String get geo_title;

  /// Translation key: go
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// Translation key: got_it
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get got_it;

  /// Translation key: greet_afternoon
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get greet_afternoon;

  /// Translation key: greet_evening
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get greet_evening;

  /// Translation key: greet_morning
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get greet_morning;

  /// Translation key: help_center
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get help_center;

  /// Translation key: help_center_sub
  ///
  /// In en, this message translates to:
  /// **'FAQs and support'**
  String get help_center_sub;

  /// Translation key: help_contact
  ///
  /// In en, this message translates to:
  /// **'For support, contact us at:\\nmohamedsabe50@gmail.com\\n\\nWe reply within 24 hours.'**
  String get help_contact;

  /// Translation key: journal_add_first
  ///
  /// In en, this message translates to:
  /// **'Add first memory'**
  String get journal_add_first;

  /// Translation key: journal_add_memory
  ///
  /// In en, this message translates to:
  /// **'Add memory'**
  String get journal_add_memory;

  /// Translation key: journal_days_ago
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String journal_days_ago(String n);

  /// Translation key: journal_edit_memory
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get journal_edit_memory;

  /// Translation key: journal_empty_sub
  ///
  /// In en, this message translates to:
  /// **'Save memories, photos, and notes for every place you visit.'**
  String get journal_empty_sub;

  /// Translation key: journal_empty_title
  ///
  /// In en, this message translates to:
  /// **'Your travel journal is empty'**
  String get journal_empty_title;

  /// Translation key: journal_new_memory
  ///
  /// In en, this message translates to:
  /// **'New memory'**
  String get journal_new_memory;

  /// Translation key: journal_note_hint
  ///
  /// In en, this message translates to:
  /// **'What did you think? What did you do? Tips for other travelers?'**
  String get journal_note_hint;

  /// Translation key: journal_notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get journal_notes;

  /// Translation key: journal_pick_place
  ///
  /// In en, this message translates to:
  /// **'Pick a place'**
  String get journal_pick_place;

  /// Translation key: journal_save_memory
  ///
  /// In en, this message translates to:
  /// **'Save memory'**
  String get journal_save_memory;

  /// Translation key: journal_search_hint
  ///
  /// In en, this message translates to:
  /// **'Search places...'**
  String get journal_search_hint;

  /// Translation key: journal_today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get journal_today;

  /// Translation key: journal_update_memory
  ///
  /// In en, this message translates to:
  /// **'Update memory'**
  String get journal_update_memory;

  /// Translation key: journal_yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get journal_yesterday;

  /// Translation key: language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Translation key: lb_empty
  ///
  /// In en, this message translates to:
  /// **'No leaderboard data yet'**
  String get lb_empty;

  /// Translation key: lb_points_level
  ///
  /// In en, this message translates to:
  /// **'{p} points · {l}'**
  String lb_points_level(String p, String l);

  /// Translation key: lb_title
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get lb_title;

  /// Translation key: lb_your_rank
  ///
  /// In en, this message translates to:
  /// **'YOUR RANK'**
  String get lb_your_rank;

  /// Translation key: level_cartographer
  ///
  /// In en, this message translates to:
  /// **'Cartographer'**
  String get level_cartographer;

  /// Translation key: level_explorer
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get level_explorer;

  /// Translation key: level_lorekeeper
  ///
  /// In en, this message translates to:
  /// **'Lorekeeper'**
  String get level_lorekeeper;

  /// Translation key: level_wanderer
  ///
  /// In en, this message translates to:
  /// **'Wanderer'**
  String get level_wanderer;

  /// Translation key: light_theme_on
  ///
  /// In en, this message translates to:
  /// **'Light theme active'**
  String get light_theme_on;

  /// Translation key: loading_tours
  ///
  /// In en, this message translates to:
  /// **'Loading tours...'**
  String get loading_tours;

  /// Translation key: loc_perm_blocked
  ///
  /// In en, this message translates to:
  /// **'Location is blocked. Enable it in Settings to get nearby alerts.'**
  String get loc_perm_blocked;

  /// Translation key: loc_service_off
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Turn them on to see what is around you.'**
  String get loc_service_off;

  /// Translation key: location_services
  ///
  /// In en, this message translates to:
  /// **'Location Services'**
  String get location_services;

  /// Translation key: location_services_sub
  ///
  /// In en, this message translates to:
  /// **'Used for nearby recommendations'**
  String get location_services_sub;

  /// Translation key: login_email
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get login_email;

  /// Translation key: login_email_hint
  ///
  /// In en, this message translates to:
  /// **'e.g. ahmed@example.com'**
  String get login_email_hint;

  /// Translation key: login_err_email
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get login_err_email;

  /// Translation key: login_err_email_invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get login_err_email_invalid;

  /// Translation key: login_err_name
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get login_err_name;

  /// Translation key: login_err_password_short
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get login_err_password_short;

  /// Translation key: login_err_account_exists
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Try signing in.'**
  String get login_err_account_exists;

  /// Translation key: login_err_no_account
  ///
  /// In en, this message translates to:
  /// **'No account found with this email. Tap Sign Up to create one.'**
  String get login_err_no_account;

  /// Translation key: login_err_wrong_password
  ///
  /// In en, this message translates to:
  /// **'Wrong password. Please try again.'**
  String get login_err_wrong_password;

  /// Translation key: login_err_unknown
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get login_err_unknown;

  /// Translation key: login_password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get login_password;

  /// Translation key: login_password_hint
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get login_password_hint;

  /// Translation key: login_password_hint_signup
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get login_password_hint_signup;

  /// Translation key: login_full_name
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get login_full_name;

  /// Translation key: login_google
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get login_google;

  /// Translation key: login_google_unavailable
  ///
  /// In en, this message translates to:
  /// **'Google sign-in unavailable. Use email or continue as guest.'**
  String get login_google_unavailable;

  /// Translation key: login_google_timeout
  ///
  /// In en, this message translates to:
  /// **'Google sign-in took too long. Try again or use email.'**
  String get login_google_timeout;

  /// Translation key: login_google_failed
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Check your Supabase redirect URL settings.'**
  String get login_google_failed;

  /// Translation key: login_have_account
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get login_have_account;

  /// Translation key: login_username
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get login_username;

  /// Translation key: login_username_hint
  ///
  /// In en, this message translates to:
  /// **'3-20 chars: letters, digits, . _ -'**
  String get login_username_hint;

  /// Translation key: login_err_username_empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get login_err_username_empty;

  /// Translation key: login_err_username_length
  ///
  /// In en, this message translates to:
  /// **'Username must be 3-20 characters'**
  String get login_err_username_length;

  /// Translation key: login_err_username_chars
  ///
  /// In en, this message translates to:
  /// **'Only letters, digits, dot, underscore and dash'**
  String get login_err_username_chars;

  /// Translation key: username_invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid username (3-20 chars, letters/digits/._-)'**
  String get username_invalid;

  /// Translation key: login_no_account
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get login_no_account;

  /// Translation key: login_sign_up
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get login_sign_up;

  /// Translation key: login_or
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get login_or;

  /// Translation key: login_sign_in
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get login_sign_in;

  /// Translation key: login_subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your favorite places and access exclusive tours.'**
  String get login_subtitle;

  /// Translation key: login_welcome
  ///
  /// In en, this message translates to:
  /// **'Welcome to\\nEgyptLore'**
  String get login_welcome;

  /// Translation key: map_close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get map_close;

  /// Translation key: map_my_location
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get map_my_location;

  /// Translation key: map_open_details
  ///
  /// In en, this message translates to:
  /// **'Open details'**
  String get map_open_details;

  /// Translation key: map_title
  ///
  /// In en, this message translates to:
  /// **'Map · {n} places'**
  String map_title(String n);

  /// Translation key: map_view
  ///
  /// In en, this message translates to:
  /// **'Map View'**
  String get map_view;

  /// Translation key: message
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// Translation key: nav_explore
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get nav_explore;

  /// Translation key: nav_profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get nav_profile;

  /// Translation key: nav_tours
  ///
  /// In en, this message translates to:
  /// **'Tours'**
  String get nav_tours;

  /// Translation key: nearby_places
  ///
  /// In en, this message translates to:
  /// **'Nearby Places'**
  String get nearby_places;

  /// Translation key: trip_visited
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get trip_visited;

  /// Translation key: trip_visited_badge
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get trip_visited_badge;

  /// Translation key: trip_tab_saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get trip_tab_saved;

  /// Translation key: trip_tab_visited
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get trip_tab_visited;

  /// Translation key: trip_tab_saved_empty_title
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get trip_tab_saved_empty_title;

  /// Translation key: trip_tab_saved_empty_body
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark on any place to save it here for later.'**
  String get trip_tab_saved_empty_body;

  /// Translation key: trip_tab_visited_empty_title
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get trip_tab_visited_empty_title;

  /// Translation key: trip_tab_visited_empty_body
  ///
  /// In en, this message translates to:
  /// **'Tap the flag on any place to check in — your visits show up here.'**
  String get trip_tab_visited_empty_body;

  /// Translation key: no_badges
  ///
  /// In en, this message translates to:
  /// **'Check in at places to earn badges'**
  String get no_badges;

  /// Translation key: no_places
  ///
  /// In en, this message translates to:
  /// **'No places found'**
  String get no_places;

  /// Translation key: no_results_for
  ///
  /// In en, this message translates to:
  /// **'No results for \"{q}\"'**
  String no_results_for(String q);

  /// Translation key: no_reviews
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Be the first to share your story!'**
  String get no_reviews;

  /// Translation key: no_saved_places
  ///
  /// In en, this message translates to:
  /// **'No Saved Places'**
  String get no_saved_places;

  /// Translation key: no_saved_tours
  ///
  /// In en, this message translates to:
  /// **'No Saved Tours'**
  String get no_saved_tours;

  /// Translation key: no_tours
  ///
  /// In en, this message translates to:
  /// **'No tours yet'**
  String get no_tours;

  /// Translation key: ob_get_started
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get ob_get_started;

  /// Translation key: ob_next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get ob_next;

  /// Translation key: ob_skip
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get ob_skip;

  /// Translation key: ob_sub_1
  ///
  /// In en, this message translates to:
  /// **'Uncover 30+ hidden gems and landmarks of Alexandria that most tourists never find.'**
  String get ob_sub_1;

  /// Translation key: ob_sub_2
  ///
  /// In en, this message translates to:
  /// **'Choose from expertly curated tours. Navigate with ease and explore at your own pace.'**
  String get ob_sub_2;

  /// Translation key: ob_sub_3
  ///
  /// In en, this message translates to:
  /// **'Build your personal travel collection. Save your favorite places and access them anytime.'**
  String get ob_sub_3;

  /// Translation key: ob_title_1
  ///
  /// In en, this message translates to:
  /// **'Discover the Unseen'**
  String get ob_title_1;

  /// Translation key: ob_title_2
  ///
  /// In en, this message translates to:
  /// **'Plan Your Journey'**
  String get ob_title_2;

  /// Translation key: ob_title_3
  ///
  /// In en, this message translates to:
  /// **'Save & Revisit'**
  String get ob_title_3;

  /// Translation key: open_now
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get open_now;

  /// Translation key: open_settings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get open_settings;

  /// Translation key: photos
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// Translation key: places_count
  ///
  /// In en, this message translates to:
  /// **'{n} places'**
  String places_count(String n);

  /// Translation key: post_review
  ///
  /// In en, this message translates to:
  /// **'Post Review'**
  String get post_review;

  /// Translation key: prayer_asr
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayer_asr;

  /// Translation key: prayer_dhuhr
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayer_dhuhr;

  /// Translation key: prayer_fajr
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayer_fajr;

  /// Translation key: prayer_isha
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayer_isha;

  /// Translation key: prayer_load_failed
  ///
  /// In en, this message translates to:
  /// **'Failed to load prayer times'**
  String get prayer_load_failed;

  /// Translation key: prayer_maghrib
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayer_maghrib;

  /// Translation key: prayer_sunrise
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayer_sunrise;

  /// Translation key: prayer_times
  ///
  /// In en, this message translates to:
  /// **'Prayer Times'**
  String get prayer_times;

  /// Translation key: prayer_times_sub
  ///
  /// In en, this message translates to:
  /// **'Daily prayer schedule for Alexandria'**
  String get prayer_times_sub;

  /// Translation key: premium_experience
  ///
  /// In en, this message translates to:
  /// **'Premium experience'**
  String get premium_experience;

  /// Translation key: prof_explored
  ///
  /// In en, this message translates to:
  /// **'Explored'**
  String get prof_explored;

  /// Translation key: prof_saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get prof_saved;

  /// Translation key: prof_tours
  ///
  /// In en, this message translates to:
  /// **'Tours'**
  String get prof_tours;

  /// Translation key: push_notif
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get push_notif;

  /// Translation key: push_notif_sub
  ///
  /// In en, this message translates to:
  /// **'Get tips and discoveries'**
  String get push_notif_sub;

  /// Translation key: quick_badges
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get quick_badges;

  /// Translation key: quick_best_time
  ///
  /// In en, this message translates to:
  /// **'Best Time'**
  String get quick_best_time;

  /// Translation key: best_time_admin_hint
  ///
  /// In en, this message translates to:
  /// **'Set by the editorial team'**
  String get best_time_admin_hint;

  /// Translation key: quick_map
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get quick_map;

  /// Translation key: quick_ranking
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get quick_ranking;

  /// Translation key: quick_routes
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get quick_routes;

  /// Translation key: rate_app
  ///
  /// In en, this message translates to:
  /// **'Rate EgyptLore'**
  String get rate_app;

  /// Translation key: rate_app_sub
  ///
  /// In en, this message translates to:
  /// **'Share your experience'**
  String get rate_app_sub;

  /// Translation key: rate_thanks
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support! '**
  String get rate_thanks;

  /// Translation key: rating_label
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating_label;

  /// Translation key: refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Translation key: remove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Translation key: removed_from_saved
  ///
  /// In en, this message translates to:
  /// **'{name} removed from saved places'**
  String removed_from_saved(String name);

  /// Translation key: results_for
  ///
  /// In en, this message translates to:
  /// **'{n} results for \"{q}\"'**
  String results_for(String n, String q);

  /// Translation key: review_empty_warn
  ///
  /// In en, this message translates to:
  /// **'Please write a comment first'**
  String get review_empty_warn;

  /// Translation key: review_failed
  ///
  /// In en, this message translates to:
  /// **'Could not post review'**
  String get review_failed;

  /// Translation key: review_hint
  ///
  /// In en, this message translates to:
  /// **'Share your experience...'**
  String get review_hint;

  /// Translation key: save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Translation key: saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Translation key: saved_cleared
  ///
  /// In en, this message translates to:
  /// **'All saved places cleared.'**
  String get saved_cleared;

  /// Translation key: saved_collection
  ///
  /// In en, this message translates to:
  /// **'Your collection'**
  String get saved_collection;

  /// Translation key: saved_count
  ///
  /// In en, this message translates to:
  /// **'{n} saved'**
  String saved_count(String n);

  /// Translation key: saved_title
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved_title;

  /// Translation key: search_hint
  ///
  /// In en, this message translates to:
  /// **'Search places, landmarks...'**
  String get search_hint;

  /// Translation key: section_about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get section_about;

  /// Translation key: section_app_settings
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get section_app_settings;

  /// Translation key: share_app
  ///
  /// In en, this message translates to:
  /// **'Share EgyptLore'**
  String get share_app;

  /// Translation key: sign_in_continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sign_in_continue;

  /// Translation key: sign_out
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sign_out;

  /// Translation key: sign_out_q
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get sign_out_q;

  /// Translation key: sign_out_sub
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? Your saved places will be preserved.'**
  String get sign_out_sub;

  /// Translation key: standard_ticket
  ///
  /// In en, this message translates to:
  /// **'Standard ticket'**
  String get standard_ticket;

  /// Translation key: stat_reviews
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get stat_reviews;

  /// Translation key: stat_visited
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get stat_visited;

  /// Translation key: streak_begin
  ///
  /// In en, this message translates to:
  /// **'Check in at any place to begin'**
  String get streak_begin;

  /// Translation key: streak_best
  ///
  /// In en, this message translates to:
  /// **'Best: {b} · {t} day{s} total'**
  String streak_best(String b, String t, String s);

  /// Translation key: streak_days
  ///
  /// In en, this message translates to:
  /// **'{n} visits streak'**
  String streak_days(String n);

  /// Translation key: streak_start
  ///
  /// In en, this message translates to:
  /// **'Start your streak'**
  String get streak_start;

  /// Translation key: swipe_remove_hint
  ///
  /// In en, this message translates to:
  /// **'<- Swipe left to remove'**
  String get swipe_remove_hint;

  /// Translation key: switch_explore
  ///
  /// In en, this message translates to:
  /// **'Switch to the Explore tab to discover places!'**
  String get switch_explore;

  /// Translation key: switch_tours
  ///
  /// In en, this message translates to:
  /// **'Switch to the Tours tab to discover tours!'**
  String get switch_tours;

  /// Translation key: tab_places
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get tab_places;

  /// Translation key: tab_tours
  ///
  /// In en, this message translates to:
  /// **'Tours'**
  String get tab_tours;

  /// Translation key: take_photo
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get take_photo;

  /// Translation key: tour_about
  ///
  /// In en, this message translates to:
  /// **'About this Tour'**
  String get tour_about;

  /// Translation key: tour_access
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get tour_access;

  /// Translation key: tour_duration
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get tour_duration;

  /// Translation key: tour_guide_hint
  ///
  /// In en, this message translates to:
  /// **'Ask about {name}...'**
  String tour_guide_hint(String name);

  /// Translation key: tour_itinerary
  ///
  /// In en, this message translates to:
  /// **'Tour Itinerary'**
  String get tour_itinerary;

  /// Translation key: tour_locations_count
  ///
  /// In en, this message translates to:
  /// **'{n} locations'**
  String tour_locations_count(String n);

  /// Translation key: tour_no_locations
  ///
  /// In en, this message translates to:
  /// **'No locations available for this tour.'**
  String get tour_no_locations;

  /// Translation key: tour_removed_offline
  ///
  /// In en, this message translates to:
  /// **'Tour removed from offline access'**
  String get tour_removed_offline;

  /// Translation key: download_offline
  ///
  /// In en, this message translates to:
  /// **'Download for Offline'**
  String get download_offline;

  /// Translation key: removed_offline
  ///
  /// In en, this message translates to:
  /// **'Removed from offline'**
  String get removed_offline;

  /// Translation key: tour_saved_offline
  ///
  /// In en, this message translates to:
  /// **'Tour saved for offline access!'**
  String get tour_saved_offline;

  /// Translation key: tour_start_nav
  ///
  /// In en, this message translates to:
  /// **'Start Navigation'**
  String get tour_start_nav;

  /// Translation key: tour_stops
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get tour_stops;

  /// Translation key: tour_stops_along
  ///
  /// In en, this message translates to:
  /// **'{n} stops along the way'**
  String tour_stops_along(String n);

  /// Translation key: tour_stops_count
  ///
  /// In en, this message translates to:
  /// **'{n} stops'**
  String tour_stops_count(String n);

  /// Translation key: tours_available
  ///
  /// In en, this message translates to:
  /// **'{n} tours available - all free'**
  String tours_available(String n);

  /// Translation key: tours_subtitle
  ///
  /// In en, this message translates to:
  /// **'Curated for you'**
  String get tours_subtitle;

  /// Translation key: tours_title
  ///
  /// In en, this message translates to:
  /// **'Guided Tours'**
  String get tours_title;

  /// Translation key: travel_journal
  ///
  /// In en, this message translates to:
  /// **'Travel Journal'**
  String get travel_journal;

  /// Translation key: travel_journal_sub
  ///
  /// In en, this message translates to:
  /// **'Save memories, notes & photos'**
  String get travel_journal_sub;

  /// Translation key: trip_title
  ///
  /// In en, this message translates to:
  /// **'My Trip Planner'**
  String get trip_title;

  /// Translation key: try_different
  ///
  /// In en, this message translates to:
  /// **'Try a different name or category'**
  String get try_different;

  /// Translation key: undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Translation key: version
  ///
  /// In en, this message translates to:
  /// **'Version 2.0.0'**
  String get version;

  /// Translation key: visited
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get visited;

  /// Translation key: weather_feels
  ///
  /// In en, this message translates to:
  /// **'feels {t}  · {h}% humidity'**
  String weather_feels(String t, String h);

  /// Translation key: weather_my_location
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get weather_my_location;

  /// Translation key: write_review
  ///
  /// In en, this message translates to:
  /// **'Write Review'**
  String get write_review;

  /// Translation key: ach_first_steps_name
  ///
  /// In en, this message translates to:
  /// **'First Steps'**
  String get ach_first_steps_name;

  /// Translation key: ach_first_steps_desc
  ///
  /// In en, this message translates to:
  /// **'Check in at your first place'**
  String get ach_first_steps_desc;

  /// Translation key: ach_explorer_5_name
  ///
  /// In en, this message translates to:
  /// **'Curious'**
  String get ach_explorer_5_name;

  /// Translation key: ach_explorer_5_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 5 different places'**
  String get ach_explorer_5_desc;

  /// Translation key: ach_explorer_10_name
  ///
  /// In en, this message translates to:
  /// **'Adventurer'**
  String get ach_explorer_10_name;

  /// Translation key: ach_explorer_10_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 10 different places'**
  String get ach_explorer_10_desc;

  /// Translation key: ach_explorer_25_name
  ///
  /// In en, this message translates to:
  /// **'Pathfinder'**
  String get ach_explorer_25_name;

  /// Translation key: ach_explorer_25_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 25 different places'**
  String get ach_explorer_25_desc;

  /// Translation key: ach_lorekeeper_name
  ///
  /// In en, this message translates to:
  /// **'Lorekeeper'**
  String get ach_lorekeeper_name;

  /// Translation key: ach_lorekeeper_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 42 places — the answer to everything'**
  String get ach_lorekeeper_desc;

  /// Translation key: ach_culture_buff_name
  ///
  /// In en, this message translates to:
  /// **'Culture Buff'**
  String get ach_culture_buff_name;

  /// Translation key: ach_culture_buff_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 5 cultural spots'**
  String get ach_culture_buff_desc;

  /// Translation key: ach_history_nerd_name
  ///
  /// In en, this message translates to:
  /// **'History Nerd'**
  String get ach_history_nerd_name;

  /// Translation key: ach_history_nerd_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 10 historical spots'**
  String get ach_history_nerd_desc;

  /// Translation key: ach_foodie_name
  ///
  /// In en, this message translates to:
  /// **'Foodie'**
  String get ach_foodie_name;

  /// Translation key: ach_foodie_desc
  ///
  /// In en, this message translates to:
  /// **'Check in at 3 food spots'**
  String get ach_foodie_desc;

  /// Translation key: ach_gourmet_name
  ///
  /// In en, this message translates to:
  /// **'Gourmet'**
  String get ach_gourmet_name;

  /// Translation key: ach_gourmet_desc
  ///
  /// In en, this message translates to:
  /// **'Check in at 8 food spots'**
  String get ach_gourmet_desc;

  /// Translation key: ach_shopaholic_name
  ///
  /// In en, this message translates to:
  /// **'Shopaholic'**
  String get ach_shopaholic_name;

  /// Translation key: ach_shopaholic_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 3 shopping spots'**
  String get ach_shopaholic_desc;

  /// Translation key: ach_spiritual_seeker_name
  ///
  /// In en, this message translates to:
  /// **'Spiritual Seeker'**
  String get ach_spiritual_seeker_name;

  /// Translation key: ach_spiritual_seeker_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 2 mosques'**
  String get ach_spiritual_seeker_desc;

  /// Translation key: ach_pilgrim_name
  ///
  /// In en, this message translates to:
  /// **'Pilgrim'**
  String get ach_pilgrim_name;

  /// Translation key: ach_pilgrim_desc
  ///
  /// In en, this message translates to:
  /// **'Visit 2 churches or holy sites'**
  String get ach_pilgrim_desc;

  /// Translation key: ach_streak_3_name
  ///
  /// In en, this message translates to:
  /// **'Warming Up'**
  String get ach_streak_3_name;

  /// Translation key: ach_streak_3_desc
  ///
  /// In en, this message translates to:
  /// **'3-day check-in streak'**
  String get ach_streak_3_desc;

  /// Translation key: ach_streak_7_name
  ///
  /// In en, this message translates to:
  /// **'On a Roll'**
  String get ach_streak_7_name;

  /// Translation key: ach_streak_7_desc
  ///
  /// In en, this message translates to:
  /// **'7-day check-in streak'**
  String get ach_streak_7_desc;

  /// Translation key: ach_streak_30_name
  ///
  /// In en, this message translates to:
  /// **'Devoted'**
  String get ach_streak_30_name;

  /// Translation key: ach_streak_30_desc
  ///
  /// In en, this message translates to:
  /// **'30-day check-in streak'**
  String get ach_streak_30_desc;

  /// Translation key: ach_streak_100_name
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get ach_streak_100_name;

  /// Translation key: ach_streak_100_desc
  ///
  /// In en, this message translates to:
  /// **'100-day check-in streak'**
  String get ach_streak_100_desc;

  /// Translation key: ach_hidden_gem_hunter_name
  ///
  /// In en, this message translates to:
  /// **'Hidden Gem Hunter'**
  String get ach_hidden_gem_hunter_name;

  /// Translation key: ach_hidden_gem_hunter_desc
  ///
  /// In en, this message translates to:
  /// **'Discover 3 hidden gems'**
  String get ach_hidden_gem_hunter_desc;

  /// Translation key: ach_reviewer_name
  ///
  /// In en, this message translates to:
  /// **'Reviewer'**
  String get ach_reviewer_name;

  /// Translation key: ach_reviewer_desc
  ///
  /// In en, this message translates to:
  /// **'Post 3 reviews'**
  String get ach_reviewer_desc;

  /// Translation key: ach_critic_name
  ///
  /// In en, this message translates to:
  /// **'Critic'**
  String get ach_critic_name;

  /// Translation key: ach_critic_desc
  ///
  /// In en, this message translates to:
  /// **'Post 10 reviews'**
  String get ach_critic_desc;

  /// Translation key: ach_photographer_name
  ///
  /// In en, this message translates to:
  /// **'Photographer'**
  String get ach_photographer_name;

  /// Translation key: ach_photographer_desc
  ///
  /// In en, this message translates to:
  /// **'Upload 5 photos'**
  String get ach_photographer_desc;

  /// Translation key: ach_influencer_name
  ///
  /// In en, this message translates to:
  /// **'Influencer'**
  String get ach_influencer_name;

  /// Translation key: ach_influencer_desc
  ///
  /// In en, this message translates to:
  /// **'Upload 20 photos'**
  String get ach_influencer_desc;

  /// Translation key: ach_early_bird_name
  ///
  /// In en, this message translates to:
  /// **'Early Bird'**
  String get ach_early_bird_name;

  /// Translation key: ach_early_bird_desc
  ///
  /// In en, this message translates to:
  /// **'Check in at 5 places before 9 AM'**
  String get ach_early_bird_desc;

  /// Translation key: ach_night_owl_name
  ///
  /// In en, this message translates to:
  /// **'Night Owl'**
  String get ach_night_owl_name;

  /// Translation key: ach_night_owl_desc
  ///
  /// In en, this message translates to:
  /// **'Check in at 5 places after 9 PM'**
  String get ach_night_owl_desc;

  /// Translation key: ach_completionist_name
  ///
  /// In en, this message translates to:
  /// **'Completionist'**
  String get ach_completionist_name;

  /// Translation key: ach_completionist_desc
  ///
  /// In en, this message translates to:
  /// **'Unlock 20 different achievements'**
  String get ach_completionist_desc;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @downloading_offline.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading_offline;

  /// No description provided for @download_failed.
  ///
  /// In en, this message translates to:
  /// **'Offline download failed. Please try again.'**
  String get download_failed;

  /// No description provided for @downloading_tour_offline.
  ///
  /// In en, this message translates to:
  /// **'Downloading tour for offline use…'**
  String get downloading_tour_offline;

  /// No description provided for @no_internet_title.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get no_internet_title;

  /// No description provided for @no_internet_message.
  ///
  /// In en, this message translates to:
  /// **'Please reconnect to the internet to load the latest places and stories.'**
  String get no_internet_message;

  /// No description provided for @no_internet_retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get no_internet_retry;

  /// No description provided for @offline_mode_notice.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode: Your saved places are available.'**
  String get offline_mode_notice;

  /// No description provided for @ai_tour_guide.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore AI'**
  String get ai_tour_guide;

  /// No description provided for @ai_guide_general_title.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore AI'**
  String get ai_guide_general_title;

  /// No description provided for @ai_guide_welcome_en.
  ///
  /// In en, this message translates to:
  /// **'Hi! I\'m EgyptLore AI. Ask me anything about places to '**
  String get ai_guide_welcome_en;

  /// No description provided for @ai_guide_thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get ai_guide_thinking;

  /// No description provided for @ai_guide_hint.
  ///
  /// In en, this message translates to:
  /// **'Ask about places, food, history…'**
  String get ai_guide_hint;

  /// No description provided for @ai_quota_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading AI quota…'**
  String get ai_quota_loading;

  /// No description provided for @ai_quota_unavailable.
  ///
  /// In en, this message translates to:
  /// **'AI quota unavailable'**
  String get ai_quota_unavailable;

  /// Translation key: ai_quota_remaining
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {limit} AI calls remaining'**
  String ai_quota_remaining(String remaining, String limit);

  /// No description provided for @ai_quota_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ai_quota_retry;

  /// No description provided for @admin_ai_chat_logs.
  ///
  /// In en, this message translates to:
  /// **'AI Chat Logs'**
  String get admin_ai_chat_logs;

  /// Translation key: admin_ai_chat_exchange
  ///
  /// In en, this message translates to:
  /// **'{count} AI exchange'**
  String admin_ai_chat_exchange(String count);

  /// Translation key: admin_ai_chat_exchanges
  ///
  /// In en, this message translates to:
  /// **'{count} AI exchanges'**
  String admin_ai_chat_exchanges(String count);

  /// No description provided for @admin_ai_chat_user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get admin_ai_chat_user;

  /// No description provided for @admin_ai_chat_assistant.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get admin_ai_chat_assistant;

  /// No description provided for @admin_ai_chat_empty.
  ///
  /// In en, this message translates to:
  /// **'No AI chat sessions yet'**
  String get admin_ai_chat_empty;

  /// Translation key: admin_ai_chat_retry_error
  ///
  /// In en, this message translates to:
  /// **'Could not load more chat threads: {error}'**
  String admin_ai_chat_retry_error(String error);

  /// No description provided for @max_route_places.
  ///
  /// In en, this message translates to:
  /// **'Max 5 places per route'**
  String get max_route_places;

  /// No description provided for @weather_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Current weather is unavailable. Check your location and connection.'**
  String get weather_unavailable;

  /// No description provided for @pro_monthly_reward_title.
  ///
  /// In en, this message translates to:
  /// **'Finish #1 Top Visitor of the Month and earn 1 Month of Pro FREE!'**
  String get pro_monthly_reward_title;

  /// Translation key: pro_monthly_reward_countdown
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h left this month'**
  String pro_monthly_reward_countdown(String days, String hours);

  /// No description provided for @pro_monthly_reward_cta.
  ///
  /// In en, this message translates to:
  /// **'Suggest a Hidden Gem'**
  String get pro_monthly_reward_cta;

  /// No description provided for @pro_hidden_gem_reward.
  ///
  /// In en, this message translates to:
  /// **'If our team approves your Hidden Gem, we’ll automatically add 30 days of Pro to your account for FREE.'**
  String get pro_hidden_gem_reward;

  /// No description provided for @share_place.
  ///
  /// In en, this message translates to:
  /// **'Share this place'**
  String get share_place;

  /// No description provided for @weather_clear_sky.
  ///
  /// In en, this message translates to:
  /// **'Clear sky'**
  String get weather_clear_sky;

  /// No description provided for @weather_mainly_clear.
  ///
  /// In en, this message translates to:
  /// **'Mainly clear'**
  String get weather_mainly_clear;

  /// No description provided for @weather_partly_cloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weather_partly_cloudy;

  /// No description provided for @weather_overcast.
  ///
  /// In en, this message translates to:
  /// **'Overcast'**
  String get weather_overcast;

  /// No description provided for @weather_rain_possible.
  ///
  /// In en, this message translates to:
  /// **'Rain possible'**
  String get weather_rain_possible;

  /// No description provided for @weather_rain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weather_rain;

  /// No description provided for @weather_drizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weather_drizzle;

  /// No description provided for @weather_thunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weather_thunderstorm;

  /// No description provided for @weather_snow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weather_snow;

  /// No description provided for @weather_fog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weather_fog;

  /// No description provided for @weather_unknown.
  ///
  /// In en, this message translates to:
  /// **'Current conditions'**
  String get weather_unknown;

  /// No description provided for @lb_city_title.
  ///
  /// In en, this message translates to:
  /// **'King of Alexandria'**
  String get lb_city_title;

  /// No description provided for @lb_period_week.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get lb_period_week;

  /// No description provided for @lb_period_month.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get lb_period_month;

  /// No description provided for @lb_period_all_time.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get lb_period_all_time;

  /// No description provided for @lb_metric_checkins.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get lb_metric_checkins;

  /// No description provided for @lb_metric_streak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get lb_metric_streak;

  /// No description provided for @lb_metric_gems.
  ///
  /// In en, this message translates to:
  /// **'Hidden gems'**
  String get lb_metric_gems;

  /// No description provided for @lb_stat_checkins.
  ///
  /// In en, this message translates to:
  /// **'check-ins'**
  String get lb_stat_checkins;

  /// No description provided for @lb_stat_streak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get lb_stat_streak;

  /// No description provided for @lb_stat_gems.
  ///
  /// In en, this message translates to:
  /// **'hidden gems'**
  String get lb_stat_gems;

  /// Translation key: lb_badge_rank
  ///
  /// In en, this message translates to:
  /// **'{level} rank'**
  String lb_badge_rank(String level);

  /// No description provided for @lb_try_again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get lb_try_again;

  /// No description provided for @username_title.
  ///
  /// In en, this message translates to:
  /// **'Choose your username'**
  String get username_title;

  /// No description provided for @username_subtitle.
  ///
  /// In en, this message translates to:
  /// **'This unique name helps other explorers find and follow you.'**
  String get username_subtitle;

  /// No description provided for @username_label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username_label;

  /// No description provided for @username_requirements.
  ///
  /// In en, this message translates to:
  /// **'Use 3-20 letters, numbers, dots, underscores, or hyphens. Start with a letter or number.'**
  String get username_requirements;

  /// No description provided for @username_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get username_continue;

  /// No description provided for @username_taken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken. Try another.'**
  String get username_taken;

  /// No description provided for @username_save_failed.
  ///
  /// In en, this message translates to:
  /// **'We could not save your username. Please try again.'**
  String get username_save_failed;

  /// No description provided for @username_check_failed.
  ///
  /// In en, this message translates to:
  /// **'We could not verify your account profile. Check your connection and try again.'**
  String get username_check_failed;

  /// No description provided for @users_search_title.
  ///
  /// In en, this message translates to:
  /// **'Search Users'**
  String get users_search_title;

  /// No description provided for @users_suggested_title.
  ///
  /// In en, this message translates to:
  /// **'Suggested explorers'**
  String get users_suggested_title;

  /// No description provided for @users_suggestions_empty.
  ///
  /// In en, this message translates to:
  /// **'No explorers are available yet.'**
  String get users_suggestions_empty;

  /// No description provided for @suggest_hidden_gem.
  ///
  /// In en, this message translates to:
  /// **'Suggest a Hidden Gem'**
  String get suggest_hidden_gem;

  /// No description provided for @suggest_hidden_gem_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Share a special place with our team'**
  String get suggest_hidden_gem_subtitle;

  /// No description provided for @users_search_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Find explorers and manage your friend requests'**
  String get users_search_subtitle;

  /// No description provided for @users_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search usernames'**
  String get users_search_hint;

  /// No description provided for @users_search_min_length.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two characters to search.'**
  String get users_search_min_length;

  /// No description provided for @users_search_failed.
  ///
  /// In en, this message translates to:
  /// **'User search failed. Please try again.'**
  String get users_search_failed;

  /// No description provided for @users_search_empty.
  ///
  /// In en, this message translates to:
  /// **'No users found. Try another username.'**
  String get users_search_empty;

  /// No description provided for @users_search_results.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get users_search_results;

  /// No description provided for @users_sign_in_required.
  ///
  /// In en, this message translates to:
  /// **'Sign in to find and add other explorers as friends.'**
  String get users_sign_in_required;

  /// No description provided for @user_profile_title.
  ///
  /// In en, this message translates to:
  /// **'Explorer Profile'**
  String get user_profile_title;

  /// No description provided for @profile_visited_places.
  ///
  /// In en, this message translates to:
  /// **'Places visited'**
  String get profile_visited_places;

  /// No description provided for @profile_no_visits.
  ///
  /// In en, this message translates to:
  /// **'No shared visits to show yet.'**
  String get profile_no_visits;

  /// No description provided for @profile_visits_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load visited places. Please try again.'**
  String get profile_visits_failed;

  /// No description provided for @send_friend_request.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get send_friend_request;

  /// No description provided for @incoming_request.
  ///
  /// In en, this message translates to:
  /// **'Incoming request'**
  String get incoming_request;

  /// No description provided for @friend_request_pending.
  ///
  /// In en, this message translates to:
  /// **'Request pending'**
  String get friend_request_pending;

  /// No description provided for @cancel_friend_request.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancel_friend_request;

  /// No description provided for @incoming_friend_requests.
  ///
  /// In en, this message translates to:
  /// **'Incoming Friend Requests'**
  String get incoming_friend_requests;

  /// No description provided for @sent_friend_requests.
  ///
  /// In en, this message translates to:
  /// **'Sent Requests'**
  String get sent_friend_requests;

  /// No description provided for @friends_list_title.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends_list_title;

  /// No description provided for @accept_friend_request.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept_friend_request;

  /// No description provided for @decline_friend_request.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline_friend_request;

  /// No description provided for @remove_friend.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get remove_friend;

  /// No description provided for @remove_friend_title.
  ///
  /// In en, this message translates to:
  /// **'Remove this friend?'**
  String get remove_friend_title;

  /// No description provided for @remove_friend_confirmation.
  ///
  /// In en, this message translates to:
  /// **'You will no longer share friend activity with each other.'**
  String get remove_friend_confirmation;

  /// No description provided for @friend_location_activity_sharing.
  ///
  /// In en, this message translates to:
  /// **'Share my location and activity with this friend'**
  String get friend_location_activity_sharing;

  /// No description provided for @friends_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load friends and requests.'**
  String get friends_load_failed;

  /// No description provided for @friend_action_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not update this friend request. Please try again.'**
  String get friend_action_failed;

  /// No description provided for @follow_action_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not update follow status. Please try again.'**
  String get follow_action_failed;

  /// No description provided for @share_location_activity.
  ///
  /// In en, this message translates to:
  /// **'Share my location & activity with friends'**
  String get share_location_activity;

  /// No description provided for @share_location_activity_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Friends can see visited places and activity only while this is on.'**
  String get share_location_activity_subtitle;

  /// No description provided for @privacy_settings_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load privacy settings.'**
  String get privacy_settings_failed;

  /// No description provided for @privacy_settings_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save privacy settings. Please try again.'**
  String get privacy_settings_save_failed;

  /// No description provided for @avatar_upload_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload your profile picture. Please try again.'**
  String get avatar_upload_failed;

  /// No description provided for @profile_friends.
  ///
  /// In en, this message translates to:
  /// **'friends'**
  String get profile_friends;

  /// No description provided for @profile_no_public_badges.
  ///
  /// In en, this message translates to:
  /// **'No badges earned yet'**
  String get profile_no_public_badges;

  /// No description provided for @badge_earned_fallback.
  ///
  /// In en, this message translates to:
  /// **'Explorer badge'**
  String get badge_earned_fallback;

  /// No description provided for @feed_title.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get feed_title;

  /// No description provided for @feed_header_subtitle.
  ///
  /// In en, this message translates to:
  /// **'See what your community is exploring'**
  String get feed_header_subtitle;

  /// No description provided for @feed_header_title.
  ///
  /// In en, this message translates to:
  /// **'Your community'**
  String get feed_header_title;

  /// No description provided for @feed_updates.
  ///
  /// In en, this message translates to:
  /// **'updates'**
  String get feed_updates;

  /// No description provided for @feed_filter_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get feed_filter_all;

  /// No description provided for @feed_filter_checkin.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get feed_filter_checkin;

  /// No description provided for @feed_filter_badge.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get feed_filter_badge;

  /// No description provided for @feed_filter_suggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get feed_filter_suggestion;

  /// No description provided for @feed_filter_empty.
  ///
  /// In en, this message translates to:
  /// **'No activity in this category yet.'**
  String get feed_filter_empty;

  /// No description provided for @feed_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get feed_today;

  /// No description provided for @feed_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get feed_yesterday;

  /// No description provided for @feed_empty.
  ///
  /// In en, this message translates to:
  /// **'No recent activity yet. Add friends to see their check-ins, badges, and approved place suggestions.'**
  String get feed_empty;

  /// No description provided for @feed_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the activity feed. Please try again.'**
  String get feed_load_failed;

  /// No description provided for @feed_action_checkin.
  ///
  /// In en, this message translates to:
  /// **'visited'**
  String get feed_action_checkin;

  /// No description provided for @feed_action_badge.
  ///
  /// In en, this message translates to:
  /// **'unlocked a badge'**
  String get feed_action_badge;

  /// No description provided for @feed_action_suggestion.
  ///
  /// In en, this message translates to:
  /// **'suggested a place'**
  String get feed_action_suggestion;

  /// No description provided for @report_title.
  ///
  /// In en, this message translates to:
  /// **'Report content'**
  String get report_title;

  /// No description provided for @report_photo_title.
  ///
  /// In en, this message translates to:
  /// **'Report Photo'**
  String get report_photo_title;

  /// No description provided for @photo_report_reason_inappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get photo_report_reason_inappropriate;

  /// No description provided for @photo_report_reason_unrelated.
  ///
  /// In en, this message translates to:
  /// **'Not related to this place'**
  String get photo_report_reason_unrelated;

  /// No description provided for @photo_report_reason_offensive.
  ///
  /// In en, this message translates to:
  /// **'Offensive/Abuse'**
  String get photo_report_reason_offensive;

  /// No description provided for @photo_report_reason_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get photo_report_reason_other;

  /// No description provided for @photo_report_submitted.
  ///
  /// In en, this message translates to:
  /// **'Photo reported. It has been hidden from your gallery.'**
  String get photo_report_submitted;

  /// No description provided for @photo_report_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not report this photo. Please try again.'**
  String get photo_report_failed;

  /// No description provided for @report_reason_prompt.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get report_reason_prompt;

  /// No description provided for @report_reason_inappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get report_reason_inappropriate;

  /// No description provided for @report_reason_spam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get report_reason_spam;

  /// No description provided for @report_reason_harassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get report_reason_harassment;

  /// No description provided for @report_reason_false_info.
  ///
  /// In en, this message translates to:
  /// **'False information'**
  String get report_reason_false_info;

  /// No description provided for @report_reason_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get report_reason_other;

  /// No description provided for @report_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get report_submit;

  /// No description provided for @report_submitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Your report was submitted for review.'**
  String get report_submitted;

  /// No description provided for @report_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit your report. Please try again.'**
  String get report_failed;

  /// No description provided for @block_user.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get block_user;

  /// No description provided for @unblock_user.
  ///
  /// In en, this message translates to:
  /// **'Unblock user'**
  String get unblock_user;

  /// No description provided for @block_user_title.
  ///
  /// In en, this message translates to:
  /// **'Block this user?'**
  String get block_user_title;

  /// No description provided for @block_user_confirmation.
  ///
  /// In en, this message translates to:
  /// **'Their community photos and activity will be hidden from you.'**
  String get block_user_confirmation;

  /// No description provided for @user_blocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked. Their content is now hidden.'**
  String get user_blocked;

  /// No description provided for @block_user_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the block list. Please try again.'**
  String get block_user_failed;

  /// No description provided for @blocked_profile_hidden.
  ///
  /// In en, this message translates to:
  /// **'This user is blocked. Unblock them to view their profile and activity.'**
  String get blocked_profile_hidden;

  /// No description provided for @smart_alerts_title.
  ///
  /// In en, this message translates to:
  /// **'Smart Location Alerts'**
  String get smart_alerts_title;

  /// No description provided for @smart_alerts_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified within 150 m of a hidden gem'**
  String get smart_alerts_subtitle;

  /// No description provided for @smart_alerts_consent.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore uses background location to alert you when you are within 150 m of a hidden gem. You can turn this off at any time.'**
  String get smart_alerts_consent;

  /// No description provided for @smart_alerts_no_gems.
  ///
  /// In en, this message translates to:
  /// **'No hidden gems are available to monitor right now.'**
  String get smart_alerts_no_gems;

  /// No description provided for @no_visited_places.
  ///
  /// In en, this message translates to:
  /// **'No Visited Places'**
  String get no_visited_places;

  /// No description provided for @empty_visited_places_sub.
  ///
  /// In en, this message translates to:
  /// **'Places you check in at will appear here.'**
  String get empty_visited_places_sub;

  /// No description provided for @no_visited_tours.
  ///
  /// In en, this message translates to:
  /// **'No Visited Tours'**
  String get no_visited_tours;

  /// No description provided for @empty_visited_tours_sub.
  ///
  /// In en, this message translates to:
  /// **'Tours you complete will appear here.'**
  String get empty_visited_tours_sub;

  /// No description provided for @ach_squad_explorer_name.
  ///
  /// In en, this message translates to:
  /// **'Squad Explorer'**
  String get ach_squad_explorer_name;

  /// No description provided for @ach_squad_explorer_desc.
  ///
  /// In en, this message translates to:
  /// **'Check in while exploring with an active squad'**
  String get ach_squad_explorer_desc;

  /// No description provided for @squad_title.
  ///
  /// In en, this message translates to:
  /// **'Co-op Exploration'**
  String get squad_title;

  /// No description provided for @squad_active_title.
  ///
  /// In en, this message translates to:
  /// **'Your active squad'**
  String get squad_active_title;

  /// No description provided for @squad_invite_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends and explore together'**
  String get squad_invite_subtitle;

  /// No description provided for @squad_start_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create or join a squad with a short code'**
  String get squad_start_subtitle;

  /// No description provided for @squad_create.
  ///
  /// In en, this message translates to:
  /// **'Create a squad'**
  String get squad_create;

  /// No description provided for @squad_join.
  ///
  /// In en, this message translates to:
  /// **'Join squad'**
  String get squad_join;

  /// No description provided for @squad_code_label.
  ///
  /// In en, this message translates to:
  /// **'4-6 digit squad code'**
  String get squad_code_label;

  /// No description provided for @squad_copy_code.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get squad_copy_code;

  /// No description provided for @squad_leave.
  ///
  /// In en, this message translates to:
  /// **'Leave squad'**
  String get squad_leave;

  /// Translation key: squad_members
  ///
  /// In en, this message translates to:
  /// **'{n} members'**
  String squad_members(String n);

  /// No description provided for @squad_roster.
  ///
  /// In en, this message translates to:
  /// **'Squad members'**
  String get squad_roster;

  /// No description provided for @squad_leader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get squad_leader;

  /// No description provided for @squad_you_leader.
  ///
  /// In en, this message translates to:
  /// **'Leader · You'**
  String get squad_you_leader;

  /// No description provided for @squad_you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get squad_you;

  /// No description provided for @squad_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create or join a squad.'**
  String get squad_sign_in;

  /// No description provided for @share_tour.
  ///
  /// In en, this message translates to:
  /// **'Share completed tour'**
  String get share_tour;

  /// No description provided for @share_completed_tour.
  ///
  /// In en, this message translates to:
  /// **'Tour completed'**
  String get share_completed_tour;

  /// Translation key: share_tour_details
  ///
  /// In en, this message translates to:
  /// **'{places} places · {duration}'**
  String share_tour_details(String places, String duration);

  /// No description provided for @share_photo.
  ///
  /// In en, this message translates to:
  /// **'Share photo'**
  String get share_photo;

  /// No description provided for @share_place_photo.
  ///
  /// In en, this message translates to:
  /// **'A moment from this place'**
  String get share_place_photo;

  /// No description provided for @share_card_footer.
  ///
  /// In en, this message translates to:
  /// **'Discover the story behind every place'**
  String get share_card_footer;

  /// No description provided for @share_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare this share image. Please try again.'**
  String get share_failed;

  /// No description provided for @geo_select_first.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one place before enabling nearby alerts.'**
  String get geo_select_first;

  /// No description provided for @geo_background_title.
  ///
  /// In en, this message translates to:
  /// **'Allow background location?'**
  String get geo_background_title;

  /// No description provided for @geo_background_explanation.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore collects location data in the background to enable '**
  String get geo_background_explanation;

  /// No description provided for @privacy_policy_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy_title;

  /// No description provided for @delete_account_public.
  ///
  /// In en, this message translates to:
  /// **'Account deletion instructions'**
  String get delete_account_public;

  /// No description provided for @public_link_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the page. Please try again later.'**
  String get public_link_failed;

  /// No description provided for @subscription_disclosure.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Payment is charged to your Google Play account at confirmation. Manage or cancel anytime in Google Play > Payments & subscriptions. Deleting your EgyptLore account does not cancel an active subscription.'**
  String get subscription_disclosure;

  /// No description provided for @terms_of_service_title.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms_of_service_title;

  /// No description provided for @profile_legal_title.
  ///
  /// In en, this message translates to:
  /// **'Settings & Legal'**
  String get profile_legal_title;

  /// No description provided for @delete_account_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account_title;

  /// No description provided for @delete_account_warning.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, personal data, saved items, and check-ins. Your EgyptLore Pro access will be lost. Deleting the account does not cancel or refund billing managed by Apple or Google; cancel any active subscription in your store settings first. This action cannot be undone.'**
  String get delete_account_warning;

  /// No description provided for @delete_account_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get delete_account_confirm;

  /// No description provided for @delete_account_failed.
  ///
  /// In en, this message translates to:
  /// **'Your account could not be deleted. Please try again.'**
  String get delete_account_failed;

  /// No description provided for @geo_enable.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get geo_enable;

  /// No description provided for @geo_read_privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Read the Privacy Policy'**
  String get geo_read_privacy_policy;

  /// No description provided for @geo_background_denied.
  ///
  /// In en, this message translates to:
  /// **'Background location was not allowed. You can enable it in Settings.'**
  String get geo_background_denied;

  /// No description provided for @geo_notifications_denied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled. Enable them in Settings to receive nearby alerts.'**
  String get geo_notifications_denied;

  /// No description provided for @geo_unsupported.
  ///
  /// In en, this message translates to:
  /// **'Nearby alerts are not supported on this device.'**
  String get geo_unsupported;

  /// No description provided for @geo_start_failed.
  ///
  /// In en, this message translates to:
  /// **'Nearby alerts could not be started. Please try again.'**
  String get geo_start_failed;

  /// No description provided for @checkin_too_far.
  ///
  /// In en, this message translates to:
  /// **'Move closer to this place to check in. The allowed distance varies by place.'**
  String get checkin_too_far;

  /// Shown when proximity automatically checks in a place
  ///
  /// In en, this message translates to:
  /// **'🎉 Auto checked in at {place}!'**
  String auto_checkin_success(String place);

  /// No description provided for @checkin_location_permission.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to verify your check-in.'**
  String get checkin_location_permission;

  /// No description provided for @checkin_location_disabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to check in.'**
  String get checkin_location_disabled;

  /// No description provided for @checkin_location_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Your location could not be verified. Please try again.'**
  String get checkin_location_unavailable;

  /// No description provided for @checkin_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Check-in could not be saved'**
  String get checkin_save_failed;

  /// Translation key: tour_progress
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} places visited'**
  String tour_progress(String done, String total);

  /// No description provided for @chat_send_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your message. Please try again.'**
  String get chat_send_failed;

  /// No description provided for @chat_sign_in_required.
  ///
  /// In en, this message translates to:
  /// **'Sign in with an account to join the chat.'**
  String get chat_sign_in_required;

  /// No description provided for @map_offline_fallback.
  ///
  /// In en, this message translates to:
  /// **'Offline guidance: showing a straight-line route to your destination.'**
  String get map_offline_fallback;

  /// No description provided for @map_cached_road_route.
  ///
  /// In en, this message translates to:
  /// **'Offline map: showing the cached road route to your destination.'**
  String get map_cached_road_route;

  /// Translation key: map_straight_line_distance
  ///
  /// In en, this message translates to:
  /// **'{distance} away · bearing {bearing}°'**
  String map_straight_line_distance(String distance, String bearing);

  /// No description provided for @tour_pro.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore Pro'**
  String get tour_pro;

  /// No description provided for @tour_pro_locked.
  ///
  /// In en, this message translates to:
  /// **'This tour is part of EgyptLore Pro. Hidden Gems and Premium Tours are for Pro members.'**
  String get tour_pro_locked;

  /// No description provided for @pro_title.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore Pro'**
  String get pro_title;

  /// No description provided for @pro_detected_offerings.
  ///
  /// In en, this message translates to:
  /// **'Detected offerings:'**
  String get pro_detected_offerings;

  /// No description provided for @pro_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover more of the stories behind your city.'**
  String get pro_subtitle;

  /// No description provided for @pro_benefit_hidden_gems.
  ///
  /// In en, this message translates to:
  /// **'Hidden Gems and Premium Tours'**
  String get pro_benefit_hidden_gems;

  /// No description provided for @pro_benefit_premium_tours.
  ///
  /// In en, this message translates to:
  /// **'Curated Premium Tours from local experts'**
  String get pro_benefit_premium_tours;

  /// No description provided for @pro_benefit_ai.
  ///
  /// In en, this message translates to:
  /// **'50 AI Questions daily'**
  String get pro_benefit_ai;

  /// No description provided for @pro_benefit_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline Downloads'**
  String get pro_benefit_offline;

  /// No description provided for @pro_benefit_badges.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Pro Badges'**
  String get pro_benefit_badges;

  /// No description provided for @pro_weekly.
  ///
  /// In en, this message translates to:
  /// **'Explorer Pass'**
  String get pro_weekly;

  /// No description provided for @pro_weekly_description.
  ///
  /// In en, this message translates to:
  /// **'Pro access for one week'**
  String get pro_weekly_description;

  /// No description provided for @pro_weekly_badge.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY PLAN'**
  String get pro_weekly_badge;

  /// No description provided for @pro_weekly_price.
  ///
  /// In en, this message translates to:
  /// **'49 EGP / week'**
  String get pro_weekly_price;

  /// No description provided for @pro_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly Pro Plan'**
  String get pro_monthly;

  /// No description provided for @pro_monthly_description.
  ///
  /// In en, this message translates to:
  /// **'Perfect for short trips'**
  String get pro_monthly_description;

  /// No description provided for @pro_monthly_badge.
  ///
  /// In en, this message translates to:
  /// **'MOST POPULAR'**
  String get pro_monthly_badge;

  /// No description provided for @pro_monthly_price.
  ///
  /// In en, this message translates to:
  /// **'99 EGP / month'**
  String get pro_monthly_price;

  /// No description provided for @pro_annual.
  ///
  /// In en, this message translates to:
  /// **'Annual Pro Plan'**
  String get pro_annual;

  /// No description provided for @pro_annual_description.
  ///
  /// In en, this message translates to:
  /// **'One year of complete Pro access'**
  String get pro_annual_description;

  /// No description provided for @pro_annual_badge.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE · SAVE 40%'**
  String get pro_annual_badge;

  /// No description provided for @pro_annual_price.
  ///
  /// In en, this message translates to:
  /// **'699 EGP / year'**
  String get pro_annual_price;

  /// No description provided for @pro_annual_monthly_equivalent.
  ///
  /// In en, this message translates to:
  /// **'Equivalent to ~58 EGP / month'**
  String get pro_annual_monthly_equivalent;

  /// Translation key: pro_billing_period
  ///
  /// In en, this message translates to:
  /// **'Billed every {period}'**
  String pro_billing_period(String period);

  /// No description provided for @pro_period_day.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get pro_period_day;

  /// Translation key: pro_period_days
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String pro_period_days(String count);

  /// No description provided for @pro_period_week.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get pro_period_week;

  /// Translation key: pro_period_weeks
  ///
  /// In en, this message translates to:
  /// **'{count} weeks'**
  String pro_period_weeks(String count);

  /// No description provided for @pro_period_month.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get pro_period_month;

  /// Translation key: pro_period_months
  ///
  /// In en, this message translates to:
  /// **'{count} months'**
  String pro_period_months(String count);

  /// No description provided for @pro_period_year.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get pro_period_year;

  /// Translation key: pro_period_years
  ///
  /// In en, this message translates to:
  /// **'{count} years'**
  String pro_period_years(String count);

  /// No description provided for @pro_includes_free.
  ///
  /// In en, this message translates to:
  /// **'Everything in Free, plus:'**
  String get pro_includes_free;

  /// No description provided for @pro_subscribe.
  ///
  /// In en, this message translates to:
  /// **'Choose this plan'**
  String get pro_subscribe;

  /// No description provided for @pro_store_note.
  ///
  /// In en, this message translates to:
  /// **'Secure purchase through the App Store or Google Play.'**
  String get pro_store_note;

  /// No description provided for @pro_setup_note.
  ///
  /// In en, this message translates to:
  /// **'Pro subscriptions are coming soon. Stay tuned for the official launch!'**
  String get pro_setup_note;

  /// No description provided for @pro_coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get pro_coming_soon;

  /// No description provided for @pro_setup_required.
  ///
  /// In en, this message translates to:
  /// **'Purchases are not configured yet. Add the RevenueCat public SDK keys to enable them.'**
  String get pro_setup_required;

  /// No description provided for @pro_sign_in_required.
  ///
  /// In en, this message translates to:
  /// **'Sign in to subscribe to EgyptLore Pro.'**
  String get pro_sign_in_required;

  /// No description provided for @pro_offering_unavailable.
  ///
  /// In en, this message translates to:
  /// **'This purchase option is not available right now.'**
  String get pro_offering_unavailable;

  /// No description provided for @pro_purchase_success.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore Pro is active. Enjoy exploring!'**
  String get pro_purchase_success;

  /// No description provided for @pro_purchase_pending.
  ///
  /// In en, this message translates to:
  /// **'Purchase received. Pro access will activate after verification.'**
  String get pro_purchase_pending;

  /// No description provided for @pro_purchase_failed.
  ///
  /// In en, this message translates to:
  /// **'The purchase could not be completed. Please try again.'**
  String get pro_purchase_failed;

  /// No description provided for @pro_member.
  ///
  /// In en, this message translates to:
  /// **'EgyptLore Pro Member'**
  String get pro_member;

  /// No description provided for @pro_tier_weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get pro_tier_weekly;

  /// No description provided for @pro_tier_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get pro_tier_monthly;

  /// No description provided for @pro_tier_annual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get pro_tier_annual;

  /// No description provided for @pro_tier_lifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get pro_tier_lifetime;

  /// No description provided for @pro_member_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your membership is active'**
  String get pro_member_subtitle;

  /// No description provided for @restore_purchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restore_purchases;

  /// No description provided for @restore_sign_in_required.
  ///
  /// In en, this message translates to:
  /// **'Sign in to restore your EgyptLore Pro purchases.'**
  String get restore_sign_in_required;

  /// No description provided for @restore_setup_required.
  ///
  /// In en, this message translates to:
  /// **'Purchase restoration is not available right now.'**
  String get restore_setup_required;

  /// No description provided for @restore_none_found.
  ///
  /// In en, this message translates to:
  /// **'No previous Pro purchases were found.'**
  String get restore_none_found;

  /// No description provided for @restore_success.
  ///
  /// In en, this message translates to:
  /// **'Your EgyptLore Pro purchases have been restored.'**
  String get restore_success;

  /// No description provided for @restore_pending.
  ///
  /// In en, this message translates to:
  /// **'Purchase restored. Pro access will activate after verification.'**
  String get restore_pending;

  /// No description provided for @restore_failed.
  ///
  /// In en, this message translates to:
  /// **'Purchases could not be restored. Please try again.'**
  String get restore_failed;

  /// No description provided for @tour_visited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get tour_visited;

  /// No description provided for @google_sha1_error.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In setup error (Code 10). Contact developer.'**
  String get google_sha1_error;

  /// No description provided for @google_config_error.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In not configured properly. Try email login.'**
  String get google_config_error;

  /// No description provided for @google_network_error.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get google_network_error;

  /// No description provided for @google_general_error.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed. Try email login instead.'**
  String get google_general_error;

  /// No description provided for @hub_community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get hub_community;

  /// No description provided for @hub_leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get hub_leaderboard;

  /// No description provided for @hub_badges.
  ///
  /// In en, this message translates to:
  /// **'Badges & Progress'**
  String get hub_badges;

  /// No description provided for @login_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get login_apple;

  /// No description provided for @login_apple_failed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in failed. Please try again.'**
  String get login_apple_failed;

  /// No description provided for @ach_alex_foodie_name.
  ///
  /// In en, this message translates to:
  /// **'Alexandria Foodie'**
  String get ach_alex_foodie_name;

  /// No description provided for @ach_alex_foodie_desc.
  ///
  /// In en, this message translates to:
  /// **'Try 5 food places in Alexandria'**
  String get ach_alex_foodie_desc;

  /// No description provided for @ach_alexandria_legend_name.
  ///
  /// In en, this message translates to:
  /// **'Alexandria Legend'**
  String get ach_alexandria_legend_name;

  /// No description provided for @ach_alexandria_legend_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit 30 places'**
  String get ach_alexandria_legend_desc;

  /// No description provided for @ach_culture_vulture_name.
  ///
  /// In en, this message translates to:
  /// **'Culture Vulture'**
  String get ach_culture_vulture_name;

  /// No description provided for @ach_culture_vulture_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit 5 cultural places'**
  String get ach_culture_vulture_desc;

  /// No description provided for @ach_lore_master_name.
  ///
  /// In en, this message translates to:
  /// **'Lore Master'**
  String get ach_lore_master_name;

  /// No description provided for @ach_lore_master_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit 15 places'**
  String get ach_lore_master_desc;

  /// No description provided for @ach_nature_lover_name.
  ///
  /// In en, this message translates to:
  /// **'Nature Lover'**
  String get ach_nature_lover_name;

  /// No description provided for @ach_nature_lover_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit 3 nature places'**
  String get ach_nature_lover_desc;

  /// No description provided for @ach_social_explorer_name.
  ///
  /// In en, this message translates to:
  /// **'Social Explorer'**
  String get ach_social_explorer_name;

  /// No description provided for @ach_social_explorer_desc.
  ///
  /// In en, this message translates to:
  /// **'Make 3 friends'**
  String get ach_social_explorer_desc;

  /// No description provided for @ach_street_explorer_name.
  ///
  /// In en, this message translates to:
  /// **'Alexandria Explorer'**
  String get ach_street_explorer_name;

  /// No description provided for @ach_street_explorer_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit 5 different places in Alexandria'**
  String get ach_street_explorer_desc;

  /// No description provided for @ach_time_traveler_name.
  ///
  /// In en, this message translates to:
  /// **'History Buff'**
  String get ach_time_traveler_name;

  /// No description provided for @ach_time_traveler_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit 5 historical places'**
  String get ach_time_traveler_desc;

  /// No description provided for @badge_bookmark_collector_name.
  ///
  /// In en, this message translates to:
  /// **'Bookmark Collector'**
  String get badge_bookmark_collector_name;

  /// No description provided for @badge_bookmark_collector_desc.
  ///
  /// In en, this message translates to:
  /// **'Save 5 places'**
  String get badge_bookmark_collector_desc;

  /// No description provided for @badge_cafe_hopper_name.
  ///
  /// In en, this message translates to:
  /// **'Cafe Hopper'**
  String get badge_cafe_hopper_name;

  /// No description provided for @badge_cafe_hopper_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit 4 cafes'**
  String get badge_cafe_hopper_desc;

  /// No description provided for @badge_community_spark_name.
  ///
  /// In en, this message translates to:
  /// **'Community Spark'**
  String get badge_community_spark_name;

  /// No description provided for @badge_community_spark_desc.
  ///
  /// In en, this message translates to:
  /// **'Send 5 chat messages'**
  String get badge_community_spark_desc;

  /// No description provided for @badge_grand_tour_master_name.
  ///
  /// In en, this message translates to:
  /// **'Grand Tour Master'**
  String get badge_grand_tour_master_name;

  /// No description provided for @badge_grand_tour_master_desc.
  ///
  /// In en, this message translates to:
  /// **'Complete 3 tours'**
  String get badge_grand_tour_master_desc;

  /// No description provided for @badge_lens_of_alexandria_name.
  ///
  /// In en, this message translates to:
  /// **'Lens of Alexandria'**
  String get badge_lens_of_alexandria_name;

  /// No description provided for @badge_lens_of_alexandria_desc.
  ///
  /// In en, this message translates to:
  /// **'Upload 3 photos'**
  String get badge_lens_of_alexandria_desc;

  /// No description provided for @badge_tour_finisher_name.
  ///
  /// In en, this message translates to:
  /// **'Tour Finisher'**
  String get badge_tour_finisher_name;

  /// No description provided for @badge_tour_finisher_desc.
  ///
  /// In en, this message translates to:
  /// **'Complete a tour'**
  String get badge_tour_finisher_desc;

  /// No description provided for @feed_suggest_hidden_gem.
  ///
  /// In en, this message translates to:
  /// **'Suggest a Hidden Gem'**
  String get feed_suggest_hidden_gem;

  /// No description provided for @feed_friend_requests_summary.
  ///
  /// In en, this message translates to:
  /// **'{count} Friend Requests — Tap to view'**
  String feed_friend_requests_summary(Object count);

  /// No description provided for @feed_notifications_summary.
  ///
  /// In en, this message translates to:
  /// **'{count} Notifications — Tap to view'**
  String feed_notifications_summary(Object count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
