import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/app_bar_shell.dart';

/// One selectable icon: a search-friendly label plus a stable
/// Material Icons glyph (only the code point is persisted).
class IconOption {
  const IconOption(this.name, this.icon);

  final String name;
  final IconData icon;
}

/// A named group of icons shown as its own section in the picker.
class IconCategory {
  const IconCategory(this.title, this.options);

  final String title;
  final List<IconOption> options;
}

/// Locally bundled Material Icons, grouped by purpose. Every entry is a
/// compile-time `Icons.*` constant from the `MaterialIcons` font, so the
/// stored code point always resolves back to the same glyph.
const List<IconCategory> kHabitIconCategories = [

  // ───────────────── Health & Fitness ─────────────────

  IconCategory('Health & Fitness', [
    IconOption('fitness center', Icons.fitness_center),
    IconOption('running', Icons.directions_run),
    IconOption('walking', Icons.directions_walk),
    IconOption('cycling', Icons.directions_bike),
    IconOption('swimming', Icons.pool),
    IconOption('hiking', Icons.hiking),
    IconOption('rowing', Icons.rowing),
    IconOption('sports', Icons.sports),
    IconOption('soccer', Icons.sports_soccer),
    IconOption('basketball', Icons.sports_basketball),
    IconOption('tennis', Icons.sports_tennis),
    IconOption('cricket', Icons.sports_cricket),
    IconOption('baseball', Icons.sports_baseball),
    IconOption('golf', Icons.sports_golf),
    IconOption('volleyball', Icons.sports_volleyball),
    IconOption('handball', Icons.sports_handball),
    IconOption('esports', Icons.sports_esports),
    IconOption('heart', Icons.favorite),
    IconOption('heart rate', Icons.monitor_heart),
    IconOption('weight', Icons.monitor_weight),
    IconOption('health', Icons.healing),
    IconOption('medical', Icons.medical_services),
    IconOption('medication', Icons.medication),
    IconOption('accessibility', Icons.accessibility_new),
  ]),

  // ───────────────── Mindfulness & Sleep ─────────────────

  IconCategory('Mindfulness & Sleep', [
    IconOption('meditation', Icons.self_improvement),
    IconOption('spa', Icons.spa),
    IconOption('psychology', Icons.psychology),
    IconOption('mind', Icons.psychology_alt),
    IconOption('calm breath', Icons.air),
    IconOption('gratitude', Icons.favorite_border),
    IconOption('volunteer', Icons.volunteer_activism),
    IconOption('nature', Icons.nature),
    IconOption('nature people', Icons.nature_people),
    IconOption('forest', Icons.forest),
    IconOption('flower', Icons.local_florist),
    IconOption('sunrise', Icons.wb_twilight),
    IconOption('sunny', Icons.wb_sunny),
    IconOption('night', Icons.bedtime),
    IconOption('sleep', Icons.hotel),
    IconOption('bed', Icons.bed),
    IconOption('cloud', Icons.cloud),
    IconOption('mood', Icons.sentiment_satisfied_alt),
  ]),

  // ───────────────── Learning & Reading ─────────────────

  IconCategory('Learning & Reading', [
    IconOption('book', Icons.book),
    IconOption('reading', Icons.menu_book),
    IconOption('library', Icons.library_books),
    IconOption('school', Icons.school),
    IconOption('note', Icons.note),
    IconOption('notes', Icons.description),
    IconOption('article', Icons.article),
    IconOption('assignment', Icons.assignment),
    IconOption('quiz', Icons.quiz),
    IconOption('science', Icons.science),
    IconOption('math', Icons.calculate),
    IconOption('formula', Icons.functions),
    IconOption('language', Icons.language),
    IconOption('translate', Icons.translate),
    IconOption('history', Icons.history_edu),
    IconOption('globe', Icons.public),
    IconOption('writing', Icons.edit),
    IconOption('bookmark', Icons.bookmark),
    IconOption('idea', Icons.lightbulb),
  ]),

  // ───────────────── Productivity & Work ─────────────────

  IconCategory('Productivity & Work', [
    IconOption('work', Icons.work),
    IconOption('task', Icons.task_alt),
    IconOption('checklist', Icons.checklist),
    IconOption('check', Icons.check_circle),
    IconOption('done all', Icons.done_all),
    IconOption('schedule', Icons.schedule),
    IconOption('calendar', Icons.calendar_month),
    IconOption('today', Icons.today),
    IconOption('event', Icons.event),
    IconOption('timer', Icons.timer),
    IconOption('alarm', Icons.alarm),
    IconOption('goal flag', Icons.flag),
    IconOption('priority', Icons.priority_high),
    IconOption('focus', Icons.center_focus_strong),
    IconOption('rocket', Icons.rocket_launch),
    IconOption('notifications', Icons.notifications),
    IconOption('email', Icons.email),
    IconOption('print', Icons.print),
  ]),

  // ───────────────── Technology & Coding ─────────────────

  IconCategory('Technology & Coding', [
    IconOption('code', Icons.code),
    IconOption('terminal', Icons.terminal),
    IconOption('computer', Icons.computer),
    IconOption('laptop', Icons.laptop),
    IconOption('phone', Icons.phone_android),
    IconOption('desktop', Icons.desktop_windows),
    IconOption('cloud', Icons.cloud),
    IconOption('database', Icons.storage),
    IconOption('bug', Icons.bug_report),
    IconOption('settings', Icons.settings),
    IconOption('wifi', Icons.wifi),
    IconOption('developer', Icons.developer_mode),
    IconOption('data', Icons.data_object),
  ]),

  // ───────────────── Self Care & Hygiene ─────────────────

  IconCategory('Self Care & Hygiene', [
    IconOption('shower', Icons.shower),
    IconOption('spa', Icons.spa),
    IconOption('face care', Icons.face),
    IconOption('clean', Icons.clean_hands),
    IconOption('health', Icons.health_and_safety),
    IconOption('medication', Icons.medication),
    IconOption('bed', Icons.bed),
    IconOption('sleep', Icons.nightlight_round),
    IconOption('water', Icons.water_drop),
    IconOption('favorite', Icons.favorite),
  ]),

  // ───────────────── Lifestyle & Entertainment ─────────────────

  IconCategory('Lifestyle & Entertainment', [
    IconOption('art', Icons.brush),
    IconOption('design', Icons.design_services),
    IconOption('fashion', Icons.style),
    IconOption('shopping', Icons.shopping_bag),
    IconOption('cart', Icons.shopping_cart),
    IconOption('music', Icons.music_note),
    IconOption('headphones', Icons.headphones),
    IconOption('movie', Icons.movie),
    IconOption('games', Icons.videogame_asset),
    IconOption('camera', Icons.camera_alt),
    IconOption('travel', Icons.travel_explore),
    IconOption('flight', Icons.flight),
    IconOption('car', Icons.directions_car),
    IconOption('celebration', Icons.celebration),
    IconOption('weekend', Icons.weekend),
  ]),

  // ───────────────── Home & Chores ─────────────────

  IconCategory('Home & Chores', [
    IconOption('home', Icons.home),
    IconOption('cleaning', Icons.cleaning_services),
    IconOption('laundry', Icons.local_laundry_service),
    IconOption('kitchen', Icons.kitchen),
    IconOption('yard', Icons.yard),
    IconOption('repair', Icons.home_repair_service),
    IconOption('bed', Icons.bed),
    IconOption('delete', Icons.delete_outline),
    IconOption('shopping', Icons.local_grocery_store),
    IconOption('light', Icons.lightbulb),
  ]),

  // ───────────────── Food & Water ─────────────────

  IconCategory('Food & Water', [
    IconOption('water', Icons.water_drop),
    IconOption('drink', Icons.local_drink),
    IconOption('coffee', Icons.coffee),
    IconOption('tea', Icons.local_cafe),
    IconOption('restaurant', Icons.restaurant),
    IconOption('ramen', Icons.ramen_dining),
    IconOption('breakfast', Icons.breakfast_dining),
    IconOption('lunch', Icons.lunch_dining),
    IconOption('dinner', Icons.dinner_dining),
    IconOption('snack', Icons.fastfood),
    IconOption('ice cream', Icons.icecream),
    IconOption('bakery', Icons.bakery_dining),
    IconOption('rice bowl', Icons.rice_bowl),
    IconOption('fruit', Icons.apple),
    IconOption('egg', Icons.egg),
    IconOption('cooking', Icons.soup_kitchen),
    IconOption('grocery', Icons.local_grocery_store),
    IconOption('no junk food', Icons.no_meals),
  ]),

  // ───────────────── Finance ─────────────────

  IconCategory('Finance', [
    IconOption('wallet', Icons.account_balance_wallet),
    IconOption('savings', Icons.savings),
    IconOption('bank', Icons.account_balance),
    IconOption('payments', Icons.payments),
    IconOption('money', Icons.attach_money),
    IconOption('cash', Icons.money),
    IconOption('card', Icons.credit_card),
    IconOption('chart', Icons.show_chart),
    IconOption('analytics', Icons.analytics),
    IconOption('trending', Icons.trending_up),
    IconOption('receipt', Icons.receipt_long),
    IconOption('budget', Icons.pie_chart),
    IconOption('statistics', Icons.query_stats),
    IconOption('income', Icons.add_circle_outline),
    IconOption('expense', Icons.remove_circle_outline),
    IconOption('investment', Icons.account_balance),
    IconOption('no spending', Icons.money_off),
    IconOption('interest', Icons.percent),
  ]),

  // ───────────────── General ─────────────────

  IconCategory('General', [
    IconOption('star', Icons.star),
    IconOption('trophy', Icons.emoji_events),
    IconOption('medal', Icons.military_tech),
    IconOption('premium', Icons.workspace_premium),
    IconOption('fire', Icons.local_fire_department),
    IconOption('energy', Icons.bolt),
    IconOption('like', Icons.thumb_up),
    IconOption('lock', Icons.lock),
    IconOption('key', Icons.vpn_key),
    IconOption('build', Icons.build),
    IconOption('pet', Icons.pets),
    IconOption('eco', Icons.eco),
    IconOption('recycling', Icons.recycling),
    IconOption('community', Icons.groups),
    IconOption('person', Icons.person),
    IconOption('people', Icons.people),
    IconOption('family', Icons.family_restroom),
    IconOption('place', Icons.location_on),
    IconOption('map', Icons.map),
    IconOption('share', Icons.share),
    IconOption('gift', Icons.card_giftcard),
    IconOption('label', Icons.label),
    IconOption('offer', Icons.local_offer),
    IconOption('info', Icons.info),
  ]),
];

/// Full-screen icon library: live search, category sections and a grid.
/// Pops with the chosen icon's code point.
class IconPickerScreen extends StatefulWidget {
  const IconPickerScreen({
    super.key,
    required this.selectedCodePoint,
    required this.accent,
  });

  final int selectedCodePoint;
  final Color accent;

  @override
  State<IconPickerScreen> createState() => _IconPickerScreenState();
}

class _IconPickerScreenState extends State<IconPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) =>
      setState(() => _query = value.trim().toLowerCase());

  void _choose(IconOption option) =>
      Get.back<int>(result: option.icon.codePoint);

  List<IconCategory> _filtered() {
    if (_query.isEmpty) return kHabitIconCategories;
    return [
      for (final category in kHabitIconCategories)
        IconCategory(category.title, [
          for (final option in category.options)
            if (option.name.contains(_query) ||
                category.title.toLowerCase().contains(_query))
              option,
        ]),
    ].where((category) => category.options.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accent;
    final categories = _filtered();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBarBackButton(),
        title: const Text('Choose icon'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search icons, e.g. run, book, water',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: _pickerBorder(theme, Colors.transparent),
                enabledBorder: _pickerBorder(theme, Colors.transparent),
                focusedBorder: _pickerBorder(theme, accent, width: 1.6),
              ),
            ),
          ),
          Expanded(
            child: categories.isEmpty
                ? _EmptySearch(query: _query)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      for (final category in categories) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
                          child: Text(
                            category.title.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 72,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                          itemCount: category.options.length,
                          itemBuilder: (context, index) {
                            final option = category.options[index];
                            return _IconTile(
                              option: option,
                              selected:
                                  option.icon.codePoint ==
                                  widget.selectedCodePoint,
                              accent: accent,
                              onTap: () => _choose(option),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _pickerBorder(
  ThemeData theme,
  Color color, {
  double width = 1,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconOption option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: option.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.18)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : theme.colorScheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                option.icon,
                size: 24,
                color: selected
                    ? accent
                    : theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
              if (selected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.check_circle, size: 15, color: accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              query.isEmpty ? 'No icons found' : 'No icons match "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a shorter word like "run", "book" or "water".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
