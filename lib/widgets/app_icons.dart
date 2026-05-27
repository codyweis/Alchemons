// lib/widgets/app_icons.dart
//
// Phosphor-bold–backed icon mapping. Every Material `Icons.X` used in the
// app has a matching `AppIcons.X` here, so `Icons.` → `AppIcons.` is a
// straight text replacement at call sites.
//
// Single source of truth for icon style. To swap weight (bold → duotone,
// etc.) change `PhosphorIconsBold` to another `PhosphorIcons*` class.
//
// Coin icons (gold/silver) are handled by [CoinIcon] and do NOT live here.
// `monetization_on*` / `paid*` / `hexagon*` are still included for the few
// non-currency call sites that haven't been swept yet.

// ignore_for_file: constant_identifier_names

import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AppIcons {
  AppIcons._();

  // ── A ───────────────────────────────────────────────────────────────────
  static const IconData ac_unit = PhosphorIconsBold.snowflake;
  static const IconData ac_unit_outlined = PhosphorIconsBold.snowflake;
  static const IconData ac_unit_rounded = PhosphorIconsBold.snowflake;
  static const IconData access_alarms = PhosphorIconsBold.alarm;
  static const IconData access_time_rounded = PhosphorIconsBold.clock;
  static const IconData account_balance_wallet_outlined = PhosphorIconsBold.wallet;
  static const IconData account_tree_outlined = PhosphorIconsBold.treeStructure;
  static const IconData account_tree_rounded = PhosphorIconsBold.treeStructure;
  static const IconData add = PhosphorIconsBold.plus;
  static const IconData add_circle_outline = PhosphorIconsBold.plusCircle;
  static const IconData add_circle_outline_rounded = PhosphorIconsBold.plusCircle;
  static const IconData add_location_alt_rounded = PhosphorIconsBold.mapPin;
  static const IconData add_outlined = PhosphorIconsBold.plus;
  static const IconData add_rounded = PhosphorIconsBold.plus;
  static const IconData adjust = PhosphorIconsBold.target;
  static const IconData agriculture_rounded = PhosphorIconsBold.tractor;
  static const IconData air = PhosphorIconsBold.wind;
  static const IconData air_rounded = PhosphorIconsBold.wind;
  static const IconData album_outlined = PhosphorIconsBold.vinylRecord;
  static const IconData all_inclusive_rounded = PhosphorIconsBold.infinity;
  static const IconData arrow_back = PhosphorIconsBold.arrowLeft;
  static const IconData arrow_back_ios_new_rounded = PhosphorIconsBold.caretLeft;
  static const IconData arrow_back_rounded = PhosphorIconsBold.arrowLeft;
  static const IconData arrow_downward_rounded = PhosphorIconsBold.arrowDown;
  static const IconData arrow_drop_down = PhosphorIconsBold.caretDown;
  static const IconData arrow_forward = PhosphorIconsBold.arrowRight;
  static const IconData arrow_forward_ios_rounded = PhosphorIconsBold.caretRight;
  static const IconData arrow_forward_rounded = PhosphorIconsBold.arrowRight;
  static const IconData arrow_upward_rounded = PhosphorIconsBold.arrowUp;
  static const IconData auto_awesome = PhosphorIconsBold.sparkle;
  static const IconData auto_awesome_outlined = PhosphorIconsBold.sparkle;
  static const IconData auto_awesome_rounded = PhosphorIconsBold.sparkle;
  static const IconData auto_fix_high_rounded = PhosphorIconsBold.magicWand;
  static const IconData auto_graph_rounded = PhosphorIconsBold.chartLineUp;

  // ── B ───────────────────────────────────────────────────────────────────
  static const IconData badge_rounded = PhosphorIconsBold.identificationBadge;
  static const IconData bar_chart_rounded = PhosphorIconsBold.chartBar;
  static const IconData battery_0_bar_rounded = PhosphorIconsBold.batteryLow;
  static const IconData battery_alert = PhosphorIconsBold.batteryWarning;
  static const IconData biotech = PhosphorIconsBold.testTube;
  static const IconData biotech_outlined = PhosphorIconsBold.testTube;
  static const IconData biotech_rounded = PhosphorIconsBold.testTube;
  static const IconData block_rounded = PhosphorIconsBold.prohibit;
  static const IconData bloodtype = PhosphorIconsBold.drop;
  static const IconData bloodtype_rounded = PhosphorIconsBold.drop;
  static const IconData blur_circular_outlined = PhosphorIconsBold.dropHalf;
  static const IconData blur_circular_rounded = PhosphorIconsBold.dropHalf;
  static const IconData blur_on = PhosphorIconsBold.dotsThree;
  static const IconData blur_on_rounded = PhosphorIconsBold.dotsThree;
  static const IconData bolt = PhosphorIconsBold.lightning;
  static const IconData bolt_rounded = PhosphorIconsBold.lightning;
  static const IconData brightness_2 = PhosphorIconsBold.moon;
  static const IconData brightness_2_rounded = PhosphorIconsBold.moon;
  static const IconData brightness_4_rounded = PhosphorIconsBold.moon;
  static const IconData brightness_high_outlined = PhosphorIconsBold.sun;
  static const IconData broken_image = PhosphorIconsBold.imageBroken;
  static const IconData bubble_chart_rounded = PhosphorIconsBold.dotsThreeCircle;
  static const IconData bug_report = PhosphorIconsBold.bug;
  static const IconData bug_report_rounded = PhosphorIconsBold.bug;

  // ── C ───────────────────────────────────────────────────────────────────
  static const IconData casino_rounded = PhosphorIconsBold.diceFive;
  static const IconData catching_pokemon = PhosphorIconsBold.target;
  static const IconData catching_pokemon_rounded = PhosphorIconsBold.target;
  static const IconData category_rounded = PhosphorIconsBold.squaresFour;
  static const IconData center_focus_strong_rounded = PhosphorIconsBold.crosshair;
  static const IconData change_history_rounded = PhosphorIconsBold.triangle;
  static const IconData check = PhosphorIconsBold.check;
  static const IconData check_circle = PhosphorIconsBold.checkCircle;
  static const IconData check_circle_outline = PhosphorIconsBold.checkCircle;
  static const IconData check_circle_outline_rounded = PhosphorIconsBold.checkCircle;
  static const IconData check_circle_rounded = PhosphorIconsBold.checkCircle;
  static const IconData check_rounded = PhosphorIconsBold.check;
  static const IconData chevron_left_rounded = PhosphorIconsBold.caretLeft;
  static const IconData chevron_right = PhosphorIconsBold.caretRight;
  static const IconData chevron_right_rounded = PhosphorIconsBold.caretRight;
  static const IconData circle = PhosphorIconsBold.circle;
  static const IconData circle_outlined = PhosphorIconsBold.circle;
  static const IconData circle_rounded = PhosphorIconsBold.circle;
  static const IconData clear = PhosphorIconsBold.x;
  static const IconData clear_rounded = PhosphorIconsBold.x;
  static const IconData close = PhosphorIconsBold.x;
  static const IconData close_rounded = PhosphorIconsBold.x;
  static const IconData cloud = PhosphorIconsBold.cloud;
  static const IconData cloud_download_rounded = PhosphorIconsBold.cloudArrowDown;
  static const IconData cloud_rounded = PhosphorIconsBold.cloud;
  static const IconData cloud_upload_rounded = PhosphorIconsBold.cloudArrowUp;
  static const IconData currency_exchange_rounded = PhosphorIconsBold.currencyCircleDollar;
  static const IconData cyclone_rounded = PhosphorIconsBold.tornado;

  // ── D ───────────────────────────────────────────────────────────────────
  static const IconData dangerous = PhosphorIconsBold.warningOctagon;
  static const IconData dangerous_rounded = PhosphorIconsBold.warningOctagon;
  static const IconData dark_mode = PhosphorIconsBold.moon;
  static const IconData dark_mode_rounded = PhosphorIconsBold.moon;
  static const IconData delete_forever_rounded = PhosphorIconsBold.trash;
  static const IconData delete_outline = PhosphorIconsBold.trash;
  static const IconData delete_outline_rounded = PhosphorIconsBold.trash;
  static const IconData delete_rounded = PhosphorIconsBold.trash;
  static const IconData delete_sweep_rounded = PhosphorIconsBold.trash;
  static const IconData device_thermostat_rounded = PhosphorIconsBold.thermometer;
  static const IconData diamond = PhosphorIconsBold.diamond;
  static const IconData diamond_outlined = PhosphorIconsBold.diamond;
  static const IconData diamond_rounded = PhosphorIconsBold.diamond;

  // ── E ───────────────────────────────────────────────────────────────────
  static const IconData eco = PhosphorIconsBold.leaf;
  static const IconData eco_outlined = PhosphorIconsBold.leaf;
  static const IconData eco_rounded = PhosphorIconsBold.leaf;
  static const IconData edit_outlined = PhosphorIconsBold.pencilSimple;
  static const IconData egg_alt_outlined = PhosphorIconsBold.egg;
  static const IconData emoji_events = PhosphorIconsBold.trophy;
  static const IconData emoji_events_outlined = PhosphorIconsBold.trophy;
  static const IconData emoji_events_rounded = PhosphorIconsBold.trophy;
  static const IconData emoji_nature_rounded = PhosphorIconsBold.butterfly;
  static const IconData error = PhosphorIconsBold.warningCircle;
  static const IconData error_outline = PhosphorIconsBold.warningCircle;
  static const IconData error_outline_rounded = PhosphorIconsBold.warningCircle;
  static const IconData error_rounded = PhosphorIconsBold.warningCircle;
  static const IconData exit_to_app_rounded = PhosphorIconsBold.signOut;
  static const IconData expand_less_rounded = PhosphorIconsBold.caretUp;
  static const IconData expand_more = PhosphorIconsBold.caretDown;
  static const IconData expand_more_rounded = PhosphorIconsBold.caretDown;
  static const IconData explore_rounded = PhosphorIconsBold.compass;

  // ── F ───────────────────────────────────────────────────────────────────
  static const IconData family_restroom = PhosphorIconsBold.users;
  static const IconData fast_forward_rounded = PhosphorIconsBold.fastForward;
  static const IconData favorite = PhosphorIconsBold.heart;
  static const IconData favorite_rounded = PhosphorIconsBold.heart;
  static const IconData file_upload_rounded = PhosphorIconsBold.fileArrowUp;
  static const IconData filter_alt_off_rounded = PhosphorIconsBold.funnelX;
  static const IconData filter_list_rounded = PhosphorIconsBold.funnel;
  static const IconData fitness_center = PhosphorIconsBold.barbell;
  static const IconData fitness_center_rounded = PhosphorIconsBold.barbell;
  static const IconData flag_rounded = PhosphorIconsBold.flag;
  static const IconData flash_off_rounded = PhosphorIconsBold.lightningSlash;
  static const IconData flash_on = PhosphorIconsBold.lightning;
  static const IconData flash_on_rounded = PhosphorIconsBold.lightning;
  static const IconData flight_takeoff_rounded = PhosphorIconsBold.airplaneTakeoff;
  static const IconData folder_open = PhosphorIconsBold.folderOpen;
  static const IconData forest_rounded = PhosphorIconsBold.tree;

  // ── G ───────────────────────────────────────────────────────────────────
  static const IconData gamepad_rounded = PhosphorIconsBold.gameController;
  static const IconData gpp_bad_outlined = PhosphorIconsBold.shieldWarning;
  static const IconData gps_fixed = PhosphorIconsBold.crosshair;
  static const IconData gps_fixed_rounded = PhosphorIconsBold.crosshair;
  static const IconData gradient = PhosphorIconsBold.diamondsFour;
  static const IconData grain = PhosphorIconsBold.dotsThree;
  static const IconData grain_rounded = PhosphorIconsBold.dotsThree;
  static const IconData graphic_eq_rounded = PhosphorIconsBold.equalizer;
  static const IconData grass_rounded = PhosphorIconsBold.plant;
  static const IconData grid_3x3_rounded = PhosphorIconsBold.squaresFour;
  static const IconData grid_view_rounded = PhosphorIconsBold.squaresFour;
  static const IconData group_add_rounded = PhosphorIconsBold.userPlus;
  static const IconData groups_rounded = PhosphorIconsBold.users;

  // ── H ───────────────────────────────────────────────────────────────────
  static const IconData help_center_rounded = PhosphorIconsBold.question;
  static const IconData help_outline = PhosphorIconsBold.question;
  static const IconData help_outline_rounded = PhosphorIconsBold.question;
  static const IconData hexagon = PhosphorIconsBold.hexagon;
  static const IconData hexagon_rounded = PhosphorIconsBold.hexagon;
  static const IconData home_rounded = PhosphorIconsBold.house;
  static const IconData hourglass_bottom_rounded = PhosphorIconsBold.hourglass;
  static const IconData hourglass_empty_rounded = PhosphorIconsBold.hourglass;
  static const IconData hub_rounded = PhosphorIconsBold.graph;

  // ── I ───────────────────────────────────────────────────────────────────
  static const IconData image_not_supported_rounded = PhosphorIconsBold.imageBroken;
  static const IconData info = PhosphorIconsBold.info;
  static const IconData info_outline = PhosphorIconsBold.info;
  static const IconData info_outline_rounded = PhosphorIconsBold.info;
  static const IconData info_rounded = PhosphorIconsBold.info;
  static const IconData insights_rounded = PhosphorIconsBold.chartLineUp;
  static const IconData inventory_2_outlined = PhosphorIconsBold.package;
  static const IconData inventory_2_rounded = PhosphorIconsBold.package;
  static const IconData inventory_rounded = PhosphorIconsBold.package;

  // ── K ───────────────────────────────────────────────────────────────────
  static const IconData key_rounded = PhosphorIconsBold.key;
  static const IconData keyboard_arrow_down_rounded = PhosphorIconsBold.caretDown;
  static const IconData keyboard_arrow_up_rounded = PhosphorIconsBold.caretUp;
  static const IconData keyboard_double_arrow_up_rounded = PhosphorIconsBold.caretDoubleUp;

  // ── L ───────────────────────────────────────────────────────────────────
  static const IconData landscape_rounded = PhosphorIconsBold.mountains;
  static const IconData layers_rounded = PhosphorIconsBold.stack;
  static const IconData leaderboard_rounded = PhosphorIconsBold.ranking;
  static const IconData lens_blur_rounded = PhosphorIconsBold.cube;
  static const IconData light_mode = PhosphorIconsBold.sun;
  static const IconData light_mode_rounded = PhosphorIconsBold.sun;
  static const IconData lightbulb_outline_rounded = PhosphorIconsBold.lightbulb;
  static const IconData link = PhosphorIconsBold.link;
  static const IconData link_off = PhosphorIconsBold.linkBreak;
  static const IconData link_off_rounded = PhosphorIconsBold.linkBreak;
  static const IconData link_rounded = PhosphorIconsBold.link;
  static const IconData list_rounded = PhosphorIconsBold.list;
  static const IconData local_drink_rounded = PhosphorIconsBold.beerStein;
  static const IconData local_fire_department = PhosphorIconsBold.fire;
  static const IconData local_fire_department_outlined = PhosphorIconsBold.fire;
  static const IconData local_fire_department_rounded = PhosphorIconsBold.fire;
  static const IconData local_florist = PhosphorIconsBold.flower;
  static const IconData local_gas_station_rounded = PhosphorIconsBold.gasPump;
  static const IconData local_offer_rounded = PhosphorIconsBold.tag;
  static const IconData lock = PhosphorIconsBold.lock;
  static const IconData lock_open = PhosphorIconsBold.lockOpen;
  static const IconData lock_open_rounded = PhosphorIconsBold.lockOpen;
  static const IconData lock_outline = PhosphorIconsBold.lock;
  static const IconData lock_outline_rounded = PhosphorIconsBold.lock;
  static const IconData lock_rounded = PhosphorIconsBold.lock;
  static const IconData login_rounded = PhosphorIconsBold.signIn;
  static const IconData logout_rounded = PhosphorIconsBold.signOut;

  // ── M ───────────────────────────────────────────────────────────────────
  static const IconData map_rounded = PhosphorIconsBold.mapTrifold;
  static const IconData menu_book_rounded = PhosphorIconsBold.book;
  static const IconData merge_type_rounded = PhosphorIconsBold.gitMerge;
  static const IconData military_tech_rounded = PhosphorIconsBold.medal;
  static const IconData monetization_on = PhosphorIconsBold.coin;
  static const IconData monetization_on_rounded = PhosphorIconsBold.coin;
  static const IconData movie_filter_rounded = PhosphorIconsBold.filmStrip;
  static const IconData music_note_rounded = PhosphorIconsBold.musicNote;
  static const IconData my_location_rounded = PhosphorIconsBold.crosshair;

  // ── N ───────────────────────────────────────────────────────────────────
  static const IconData nature_rounded = PhosphorIconsBold.tree;
  static const IconData navigation_rounded = PhosphorIconsBold.navigationArrow;
  static const IconData nightlight_outlined = PhosphorIconsBold.moon;
  static const IconData nightlight_round = PhosphorIconsBold.moon;
  static const IconData nightlight_round_rounded = PhosphorIconsBold.moon;
  static const IconData nights_stay_rounded = PhosphorIconsBold.moonStars;
  static const IconData notification_important = PhosphorIconsBold.bellRinging;
  static const IconData numbers_outlined = PhosphorIconsBold.hash;
  static const IconData numbers_rounded = PhosphorIconsBold.hash;

  // ── O ───────────────────────────────────────────────────────────────────
  static const IconData offline_bolt_rounded = PhosphorIconsBold.lightningSlash;
  static const IconData opacity = PhosphorIconsBold.drop;
  static const IconData opacity_rounded = PhosphorIconsBold.drop;
  static const IconData open_in_full_rounded = PhosphorIconsBold.arrowsOutSimple;

  // ── P ───────────────────────────────────────────────────────────────────
  static const IconData paid_rounded = PhosphorIconsBold.coin;
  static const IconData palette = PhosphorIconsBold.palette;
  static const IconData palette_outlined = PhosphorIconsBold.palette;
  static const IconData park_rounded = PhosphorIconsBold.tree;
  static const IconData password_rounded = PhosphorIconsBold.password;
  static const IconData pause_circle_outline_rounded = PhosphorIconsBold.pauseCircle;
  static const IconData pause_rounded = PhosphorIconsBold.pause;
  static const IconData person_add_alt_1_rounded = PhosphorIconsBold.userPlus;
  static const IconData person_rounded = PhosphorIconsBold.user;
  static const IconData person_search_rounded = PhosphorIconsBold.userFocus;
  static const IconData pets = PhosphorIconsBold.pawPrint;
  static const IconData pets_rounded = PhosphorIconsBold.pawPrint;
  static const IconData phonelink_lock_rounded = PhosphorIconsBold.lock;
  static const IconData place_rounded = PhosphorIconsBold.mapPin;
  static const IconData play_arrow_rounded = PhosphorIconsBold.play;
  static const IconData psychology = PhosphorIconsBold.brain;
  static const IconData psychology_alt_outlined = PhosphorIconsBold.brain;
  static const IconData psychology_rounded = PhosphorIconsBold.brain;
  static const IconData public = PhosphorIconsBold.globe;
  static const IconData public_rounded = PhosphorIconsBold.globe;
  static const IconData push_pin = PhosphorIconsBold.pushPin;
  static const IconData push_pin_outlined = PhosphorIconsBold.pushPin;
  static const IconData push_pin_rounded = PhosphorIconsBold.pushPin;

  // ── R ───────────────────────────────────────────────────────────────────
  static const IconData radar_rounded = PhosphorIconsBold.crosshair;
  static const IconData radio_button_checked = PhosphorIconsBold.record;
  static const IconData radio_button_checked_rounded = PhosphorIconsBold.record;
  static const IconData radio_button_unchecked = PhosphorIconsBold.circle;
  static const IconData radio_button_unchecked_rounded = PhosphorIconsBold.circle;
  static const IconData refresh_rounded = PhosphorIconsBold.arrowClockwise;
  static const IconData remove = PhosphorIconsBold.minus;
  static const IconData remove_circle_outline = PhosphorIconsBold.minusCircle;
  static const IconData remove_circle_outline_rounded = PhosphorIconsBold.minusCircle;
  static const IconData remove_circle_rounded = PhosphorIconsBold.minusCircle;
  static const IconData remove_red_eye_rounded = PhosphorIconsBold.eye;
  static const IconData remove_rounded = PhosphorIconsBold.minus;
  static const IconData replay_rounded = PhosphorIconsBold.arrowCounterClockwise;
  static const IconData rocket_launch_outlined = PhosphorIconsBold.rocketLaunch;
  static const IconData rocket_launch_rounded = PhosphorIconsBold.rocketLaunch;
  static const IconData run_circle_rounded = PhosphorIconsBold.personSimpleRun;

  // ── S ───────────────────────────────────────────────────────────────────
  static const IconData save_rounded = PhosphorIconsBold.floppyDisk;
  static const IconData savings_rounded = PhosphorIconsBold.piggyBank;
  static const IconData scatter_plot_outlined = PhosphorIconsBold.chartScatter;
  static const IconData schedule_rounded = PhosphorIconsBold.clock;
  static const IconData science = PhosphorIconsBold.flask;
  static const IconData science_outlined = PhosphorIconsBold.flask;
  static const IconData science_rounded = PhosphorIconsBold.flask;
  static const IconData search = PhosphorIconsBold.magnifyingGlass;
  static const IconData search_off_rounded = PhosphorIconsBold.magnifyingGlassMinus;
  static const IconData search_rounded = PhosphorIconsBold.magnifyingGlass;
  static const IconData security_rounded = PhosphorIconsBold.shield;
  static const IconData sell_rounded = PhosphorIconsBold.tag;
  static const IconData settings_rounded = PhosphorIconsBold.gear;
  static const IconData severe_cold_rounded = PhosphorIconsBold.snowflake;
  static const IconData shield = PhosphorIconsBold.shield;
  static const IconData shield_moon_outlined = PhosphorIconsBold.shieldStar;
  static const IconData shield_outlined = PhosphorIconsBold.shield;
  static const IconData shield_rounded = PhosphorIconsBold.shield;
  static const IconData shopping_bag_outlined = PhosphorIconsBold.shoppingBag;
  static const IconData shopping_bag_rounded = PhosphorIconsBold.shoppingBag;
  static const IconData shopping_cart_rounded = PhosphorIconsBold.shoppingCart;
  static const IconData show_chart_rounded = PhosphorIconsBold.chartLineUp;
  static const IconData slow_motion_video = PhosphorIconsBold.play;
  static const IconData sort_rounded = PhosphorIconsBold.sortAscending;
  static const IconData south = PhosphorIconsBold.arrowDown;
  static const IconData south_rounded = PhosphorIconsBold.arrowDown;
  static const IconData spa_rounded = PhosphorIconsBold.flower;
  static const IconData speed = PhosphorIconsBold.gauge;
  static const IconData speed_rounded = PhosphorIconsBold.gauge;
  static const IconData sports_kabaddi = PhosphorIconsBold.barbell;
  static const IconData sports_martial_arts = PhosphorIconsBold.barbell;
  static const IconData sports_mma = PhosphorIconsBold.barbell;
  static const IconData star = PhosphorIconsBold.star;
  static const IconData star_border_outlined = PhosphorIconsBold.star;
  static const IconData star_border_rounded = PhosphorIconsBold.star;
  static const IconData star_outline_rounded = PhosphorIconsBold.star;
  static const IconData star_rounded = PhosphorIconsBold.star;
  static const IconData stars = PhosphorIconsBold.starFour;
  static const IconData stars_rounded = PhosphorIconsBold.starFour;
  static const IconData storefront = PhosphorIconsBold.storefront;
  static const IconData storefront_rounded = PhosphorIconsBold.storefront;
  static const IconData straighten = PhosphorIconsBold.ruler;
  static const IconData straighten_rounded = PhosphorIconsBold.ruler;
  static const IconData swap_horiz = PhosphorIconsBold.arrowsLeftRight;
  static const IconData swap_horiz_rounded = PhosphorIconsBold.arrowsLeftRight;

  // ── T ───────────────────────────────────────────────────────────────────
  static const IconData terrain = PhosphorIconsBold.mountains;
  static const IconData terrain_outlined = PhosphorIconsBold.mountains;
  static const IconData terrain_rounded = PhosphorIconsBold.mountains;
  static const IconData text_fields_rounded = PhosphorIconsBold.textT;
  static const IconData theater_comedy_rounded = PhosphorIconsBold.maskHappy;
  static const IconData thermostat_rounded = PhosphorIconsBold.thermometer;
  static const IconData thunderstorm_rounded = PhosphorIconsBold.cloudLightning;
  static const IconData timer_outlined = PhosphorIconsBold.timer;
  static const IconData timer_rounded = PhosphorIconsBold.timer;
  static const IconData touch_app_rounded = PhosphorIconsBold.fingerprint;
  static const IconData travel_explore_rounded = PhosphorIconsBold.globe;
  static const IconData trending_up = PhosphorIconsBold.trendUp;
  static const IconData trending_up_rounded = PhosphorIconsBold.trendUp;
  static const IconData tune_rounded = PhosphorIconsBold.slidersHorizontal;

  // ── V ───────────────────────────────────────────────────────────────────
  static const IconData verified_rounded = PhosphorIconsBold.sealCheck;
  static const IconData verified_user_rounded = PhosphorIconsBold.shieldCheck;
  static const IconData view_carousel_rounded = PhosphorIconsBold.squaresFour;
  static const IconData view_list_rounded = PhosphorIconsBold.list;
  static const IconData visibility_off_rounded = PhosphorIconsBold.eyeSlash;
  static const IconData visibility_rounded = PhosphorIconsBold.eye;
  static const IconData volcano = PhosphorIconsBold.mountains;
  static const IconData volcano_rounded = PhosphorIconsBold.mountains;
  static const IconData volume_up_rounded = PhosphorIconsBold.speakerHigh;
  static const IconData vpn_key_outlined = PhosphorIconsBold.key;
  static const IconData vpn_key_rounded = PhosphorIconsBold.key;

  // ── W ───────────────────────────────────────────────────────────────────
  static const IconData warning_amber = PhosphorIconsBold.warning;
  static const IconData warning_amber_outlined = PhosphorIconsBold.warning;
  static const IconData warning_amber_rounded = PhosphorIconsBold.warning;
  static const IconData warning_rounded = PhosphorIconsBold.warning;
  static const IconData water = PhosphorIconsBold.drop;
  static const IconData water_damage = PhosphorIconsBold.drop;
  static const IconData water_drop = PhosphorIconsBold.drop;
  static const IconData water_drop_rounded = PhosphorIconsBold.drop;
  static const IconData water_outlined = PhosphorIconsBold.drop;
  static const IconData water_rounded = PhosphorIconsBold.drop;
  static const IconData waves = PhosphorIconsBold.waveSine;
  static const IconData waves_rounded = PhosphorIconsBold.waveSine;
  static const IconData wb_sunny = PhosphorIconsBold.sun;
  static const IconData wb_sunny_outlined = PhosphorIconsBold.sun;
  static const IconData wb_sunny_rounded = PhosphorIconsBold.sun;
  static const IconData whatshot = PhosphorIconsBold.fire;
  static const IconData whatshot_rounded = PhosphorIconsBold.fire;
  static const IconData workspace_premium = PhosphorIconsBold.medal;
  static const IconData workspace_premium_rounded = PhosphorIconsBold.medal;

  // ── Z ───────────────────────────────────────────────────────────────────
  static const IconData zoom_in_map_rounded = PhosphorIconsBold.arrowsIn;
  static const IconData zoom_out_map_rounded = PhosphorIconsBold.arrowsOut;
}
