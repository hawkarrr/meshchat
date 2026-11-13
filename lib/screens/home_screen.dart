import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/conversation.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/surfaces.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/nav_bar.dart';
import '../widgets/radio_status_banner.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/top_bar.dart';
import 'chat_screen.dart' show openConversation;
import 'contacts_screen.dart';
import 'discovery_screen.dart';
import 'home_tabs.dart';
import 'room_screen.dart';
import 'settings_screen.dart';
import '../l10n/l10n.dart';

/// The app shell: the places of the app side by side - the public room, private chats,
/// groups and settings - and a floating bar at the bottom to move between them.
///
/// The public room comes first, and is where the app opens: it is the one place with
/// people in it from the first minute, and every new phone is in it. In Kurdish and
/// Arabic, where the first place sits at the right, it is the rightmost item.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const int _publicIndex = 0;
  static const int _privateIndex = 1;
  static const int _groupsIndex = 2;
  static const int _settingsIndex = 3;

  /// The public room that is open in the first place: #mesh until another is chosen.
  static final String _meshConversation = Conversation.roomConversationId(meshRoomId);

  int _index = _publicIndex;
  String _room = _meshConversation;
  bool _searching = false;
  final ValueNotifier<String> _query = ValueNotifier<String>('');
  final TextEditingController _search = TextEditingController();
  late final AppController _controller;

  /// A quick fade-in for the place that was just chosen.
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: AppMotion.enter, value: 1);

  @override
  void initState() {
    super.initState();
    _controller = AppScope.read(context);
    // A tapped notification asks for its conversation: open it, also when the
    // tap is what started the app.
    _controller.openRequest.addListener(_openRequested);
    _controller.roomsListenable.addListener(_checkRoom);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequested());
  }

  void _openRequested() {
    final id = _controller.openRequest.value;
    if (id == null || !mounted) return;
    _controller.openRequest.value = null;
    unawaited(openConversation(context, id));
  }

  /// A room that is gone, or that this phone left, is no longer shown: back to #mesh.
  void _checkRoom() {
    if (!mounted || _room == _meshConversation) return;
    final id = _room.substring(3);
    final still = _controller.rooms.any((r) => r.id == id && r.joined);
    if (!still) setState(() => _room = _meshConversation);
  }

  @override
  void dispose() {
    _controller.openRequest.removeListener(_openRequested);
    _controller.roomsListenable.removeListener(_checkRoom);
    _fade.dispose();
    _query.dispose();
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _search.clear();
      _query.value = '';
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      // Search is about private chats and groups; it has nothing to do elsewhere.
      if (index != _privateIndex && index != _groupsIndex && _searching) {
        _searching = false;
        _search.clear();
        _query.value = '';
      }
    });
    // The new place fades in; with "remove animations" it is just there.
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  /// Back closes the search first, then goes to the first place, and only then
  /// leaves the app.
  void _back() {
    if (_searching) {
      _toggleSearch();
    } else if (_index != _publicIndex) {
      _select(_publicIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    final listPlace = _index == _privateIndex || _index == _groupsIndex;
    return PopScope(
      canPop: _index == _publicIndex && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // The text field of the room and the search field rise above the keyboard;
          // the bottom bar stays under it.
          resizeToAvoidBottomInset: true,
          floatingActionButton: listPlace ? _fab() : null,
          bottomNavigationBar: _navBar(c),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    // The public room has a header of its own, a conversation's.
                    if (_index != _publicIndex) _header(),
                    if (_index != _publicIndex) const RadioStatusBanner(),
                    Expanded(
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 0.4, end: 1)
                            .animate(CurvedAnimation(parent: _fade, curve: AppMotion.out)),
                        child: IndexedStack(
                          index: _index,
                          children: [
                            RoomChat(
                              key: ValueKey<String>(_room),
                              conversationId: _room,
                              embedded: true,
                              active: _index == _publicIndex,
                              onSwitchRoom: (id) => setState(() => _room = id),
                            ),
                            PrivateTab(query: _query),
                            GroupsTab(query: _query),
                            const SettingsTab(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The top of a place that is not the public room: its name, the search and the
  /// people (for the two lists), and how the phone is connected.
  Widget _header() {
    final l = context.l10n;
    switch (_index) {
      case _settingsIndex:
        // The quick switch between the light and the dark appearance sits here, one tap
        // from anywhere through the bottom bar; the Appearance page has all three choices.
        return AppTopBar(title: l.settingsTitle, actions: const [ThemeToggleButton()]);
      default:
        final privateChats = _index == _privateIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTopBar(
              title: privateChats ? l.homePrivateTitle : l.navGroups,
              actions: [
                RoundButton(
                  key: const Key('search-toggle'),
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  tooltip: l.commonSearch,
                  flat: true,
                  onPressed: _toggleSearch,
                ),
                RoundButton(
                  key: const Key('open-people'),
                  icon: Icons.people_alt_outlined,
                  tooltip: l.homePeople,
                  flat: true,
                  onPressed: () => _push(const ContactsScreen()),
                ),
              ],
              // The live connection state, and whether there is any internet at all -
              // a wrap, so the second drops to its own line when there is no room.
              bottom: Wrap(
                spacing: AppSpace.l,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConnectionIndicator(onTap: () => _push(const DiscoveryScreen())),
                  const OfflineBadge(),
                ],
              ),
            ),
            if (_searching) _searchField(),
          ],
        );
    }
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.m, AppSpace.s, AppSpace.m, 0),
      child: TextField(
        key: const Key('search-field'),
        controller: _search,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (v) => _query.value = v,
        decoration: InputDecoration(
          hintText: context.l10n.homeSearchHint,
          prefixIcon: Icon(Icons.search_rounded, color: context.palette.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: 10),
        ),
      ),
    );
  }

  /// The bottom bar, with the number of unread messages on each chat icon. It
  /// listens only to the unread counts, so it does not rebuild for anything else.
  Widget _navBar(AppController c) {
    return ValueListenableBuilder<List<Conversation>>(
      valueListenable: c.conversationsListenable,
      builder: (context, conversations, _) => ValueListenableBuilder<List<GroupChat>>(
        valueListenable: c.groupsListenable,
        builder: (context, groups, _) {
          int unread(ConversationType t) =>
              conversations.where((x) => x.type == t).fold(0, (s, x) => s + x.unreadCount);
          final invites = groups.where((g) => g.state == GroupState.invited).length;
          return AppNavBar(
            index: _index,
            onChanged: _select,
            // In this order: the first sits at the start - the right in Kurdish and
            // Arabic.
            destinations: [
              NavDestination(
                id: 'public',
                label: context.l10n.navPublic,
                icon: Icons.public_outlined,
                selectedIcon: Icons.public_rounded,
                badge: unread(ConversationType.room),
              ),
              NavDestination(
                id: 'private',
                label: context.l10n.navPrivate,
                icon: Icons.lock_outline_rounded,
                selectedIcon: Icons.lock_rounded,
                badge: unread(ConversationType.direct),
              ),
              NavDestination(
                id: 'groups',
                label: context.l10n.navGroups,
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups_rounded,
                badge: unread(ConversationType.group) + invites,
              ),
              NavDestination(
                id: 'settings',
                label: context.l10n.settingsTitle,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  /// The floating button of the two lists: a new message, a new group. It gets out
  /// of the way of the keyboard.
  Widget _fab() {
    final privateChats = _index == _privateIndex;
    final (icon, tooltip, action) = privateChats
        ? (Icons.edit_rounded, context.l10n.fabNewMessage, () => startNewPrivateChat(context))
        : (Icons.group_add_rounded, context.l10n.fabNewGroup, () => startNewGroup(context));
    return _HideWithKeyboard(
      child: FloatingActionButton(
        key: Key(privateChats ? 'fab-private' : 'fab-groups'),
        // The places live in one IndexedStack: a null hero tag avoids clashes
        // during page transitions.
        heroTag: null,
        tooltip: tooltip,
        onPressed: action,
        child: Icon(icon),
      ),
    );
  }
}

/// Shows [child] only while the keyboard is down. It is a widget of its own so that
/// the keyboard moving rebuilds this and nothing else: the room above the keyboard must
/// not be rebuilt by every frame of it.
class _HideWithKeyboard extends StatelessWidget {
  const _HideWithKeyboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0 ? const SizedBox.shrink() : child;
}
