import 'package:flutter/material.dart';
import 'sticker_picker_sheet.dart';

class EmojiPickerButton extends StatelessWidget {
  const EmojiPickerButton({
    required this.onEmojiSelected,
    required this.iconColor,
    this.icon,
    super.key,
  });

  final ValueChanged<String> onEmojiSelected;
  final Color iconColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          final picked = await showModalBottomSheet<String>(
            context: context,
            useSafeArea: true,
            isScrollControlled: false,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (context) =>
                _EmojiPickerSheet(onPicked: onEmojiSelected, popOnPick: true),
          );
          if (picked == null) return;
          onEmojiSelected(picked);
        },
        icon: Icon(icon ?? Icons.sentiment_satisfied_alt, color: iconColor),
      ),
    );
  }
}

class EmojiPickerSheet extends StatelessWidget {
  const EmojiPickerSheet({
    required this.onEmojiSelected,
    this.onStickerSelected,
    super.key,
  });

  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<String>? onStickerSelected;

  @override
  Widget build(BuildContext context) {
    return _EmojiPickerSheet(
      onPicked: onEmojiSelected,
      popOnPick: false,
      onStickerSelected: onStickerSelected,
    );
  }
}

class QuickEmojiRow extends StatelessWidget {
  const QuickEmojiRow({required this.onEmojiSelected, super.key});

  final ValueChanged<String> onEmojiSelected;

  static const emojis = <String>['😀', '😂', '👍', '👎', '✅', '❌'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: emojis
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => onEmojiSelected(e),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmojiCategory {
  const _EmojiCategory({
    required this.title,
    required this.icon,
    required this.emojis,
  });

  final String title;
  final IconData icon;
  final List<String> emojis;
}

class _EmojiPickerSheet extends StatefulWidget {
  const _EmojiPickerSheet({
    this.onPicked,
    required this.popOnPick,
    this.onStickerSelected,
  });

  final ValueChanged<String>? onPicked;
  final bool popOnPick;
  final ValueChanged<String>? onStickerSelected;

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  bool _scrollUpdateScheduled = false;
  bool _animatingToCategory = false;
  bool _showStickers = false;

  late final List<_EmojiCategory> _categories = <_EmojiCategory>[
    const _EmojiCategory(
      title: 'Смайлики',
      icon: Icons.emoji_emotions_outlined,
      emojis: _EmojiData.smileysAndPeople,
    ),
    const _EmojiCategory(
      title: 'Природа',
      icon: Icons.pets_outlined,
      emojis: _EmojiData.nature,
    ),
    const _EmojiCategory(
      title: 'Еда и напитки',
      icon: Icons.restaurant_outlined,
      emojis: _EmojiData.foodAndDrink,
    ),
    const _EmojiCategory(
      title: 'Занятия',
      icon: Icons.sports_basketball_outlined,
      emojis: _EmojiData.activities,
    ),
    const _EmojiCategory(
      title: 'Путешествия',
      icon: Icons.directions_car_filled_outlined,
      emojis: _EmojiData.travel,
    ),
    const _EmojiCategory(
      title: 'Предметы',
      icon: Icons.lightbulb_outline,
      emojis: _EmojiData.objects,
    ),
    const _EmojiCategory(
      title: 'Символы',
      icon: Icons.tag,
      emojis: _EmojiData.symbols,
    ),
  ];

  late final List<GlobalKey> _sectionKeys = List<GlobalKey>.generate(
    _categories.length,
    (_) => GlobalKey(),
  );

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_animatingToCategory) return;
    if (_scrollUpdateScheduled) return;
    _scrollUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollUpdateScheduled = false;
      if (!mounted) return;
      _syncSelectedCategoryWithScroll();
    });
  }

  void _syncSelectedCategoryWithScroll() {
    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null) return;

    var bestIndex = _selectedIndex;
    var bestDistance = double.infinity;

    for (var i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final dy = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      final distance = dy.abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    if (bestIndex != _selectedIndex) {
      setState(() => _selectedIndex = bestIndex);
    }
  }

  Future<void> _scrollTo(int index) async {
    if (!_scrollController.hasClients) return;

    final key = _sectionKeys[index];
    BuildContext? ctx = key.currentContext;

    _animatingToCategory = true;
    try {
      if (ctx == null) {
        // Sections are built lazily. Scroll to an approximate position first,
        // then ensureVisible once the target section is built.
        final pos = _scrollController.position;
        final min = pos.minScrollExtent;
        final max = pos.maxScrollExtent;
        final t =
            min +
            (max - min) *
                (index /
                    (_categories.length <= 1 ? 1 : _categories.length - 1));

        await _scrollController.animateTo(
          t.clamp(min, max),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
        await Future<void>.delayed(const Duration(milliseconds: 16));
        ctx = key.currentContext;
      }

      if (ctx == null) return;

      if (!mounted) return;
      if (!ctx.mounted) return;
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } finally {
      _animatingToCategory = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 460,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showStickers
                        ? 'Стикеры'
                        : _categories[_selectedIndex].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onStickerSelected != null)
                  TextButton(
                    onPressed: () =>
                        setState(() => _showStickers = !_showStickers),
                    child: Text(
                      _showStickers ? 'Эмодзи' : 'Стикеры',
                      style: TextStyle(
                        fontWeight: _showStickers ? FontWeight.w800 : null,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.tune),
                  tooltip: 'Настройки',
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: _showStickers
                  ? StickerPickerSheet(
                      key: const ValueKey('stickers'),
                      popOnPick: false,
                      onPicked: (url) {
                        final v = url.trim();
                        if (v.isEmpty) return;
                        widget.onStickerSelected?.call(v);
                      },
                    )
                  : KeyedSubtree(
                      key: const ValueKey('emoji'),
                      child: ListView.builder(
                        key: _listKey,
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return Column(
                            key: _sectionKeys[index],
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  2,
                                  14,
                                  2,
                                  10,
                                ),
                                child: Text(
                                  cat.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              GridView.builder(
                                shrinkWrap: true,
                                primary: false,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 8,
                                      mainAxisSpacing: 6,
                                      crossAxisSpacing: 6,
                                    ),
                                itemCount: cat.emojis.length,
                                itemBuilder: (context, i) {
                                  final e = cat.emojis[i];
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      widget.onPicked?.call(e);
                                      if (widget.popOnPick) {
                                        Navigator.of(context).pop(e);
                                      }
                                    },
                                    child: Center(
                                      child: Text(
                                        e,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ),
          if (!_showStickers)
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: List.generate(_categories.length, (index) {
                      final selected = index == _selectedIndex;
                      return Expanded(
                        child: IconButton(
                          onPressed: () {
                            setState(() => _selectedIndex = index);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              _scrollTo(index);
                            });
                          },
                          icon: Icon(
                            _categories[index].icon,
                            color: selected
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.6),
                          ),
                          tooltip: _categories[index].title,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmojiData {
  static const smileysAndPeople = <String>[
    '😀',
    '😁',
    '😂',
    '🤣',
    '😃',
    '😄',
    '😅',
    '😆',
    '😉',
    '😊',
    '😋',
    '😎',
    '😍',
    '😘',
    '🥰',
    '😗',
    '😙',
    '😚',
    '🙂',
    '🤗',
    '🤩',
    '🤔',
    '🫡',
    '🤨',
    '😐',
    '😑',
    '😶',
    '🫥',
    '🙄',
    '😏',
    '😣',
    '😥',
    '😮',
    '🤐',
    '😯',
    '😪',
    '😫',
    '🥱',
    '😴',
    '😌',
    '😛',
    '😜',
    '😝',
    '🤤',
    '😒',
    '😓',
    '😔',
    '😕',
    '🫤',
    '🙃',
    '🤑',
    '😲',
    '☹️',
    '🙁',
    '😖',
    '😞',
    '😟',
    '😤',
    '😢',
    '😭',
    '😦',
    '😧',
    '😨',
    '😩',
    '🤯',
    '😬',
    '😰',
    '😱',
    '🥵',
    '🥶',
    '😳',
    '🤪',
    '😵',
    '😵‍💫',
    '🥴',
    '😠',
    '😡',
    '🤬',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🤧',
    '😇',
    '🥳',
    '🥺',
    '😈',
    '👿',
    '💀',
    '☠️',
    '👻',
    '👽',
    '🤖',
    '😺',
    '😸',
    '😹',
    '😻',
    '😼',
    '😽',
    '🙀',
    '😿',
    '😾',
    '👍',
    '👎',
    '👌',
    '🤌',
    '🤞',
    '✌️',
    '🤟',
    '🤘',
    '🤙',
    '👈',
    '👉',
    '👆',
    '👇',
    '☝️',
    '👏',
    '🙌',
    '🫶',
    '🙏',
    '💪',
    '🫱',
    '🫲',
    '🫳',
    '🫴',
    '👋',
    '🤝',
    '✅',
    '❌',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '💯',
  ];

  static const nature = <String>[
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🐔',
    '🐧',
    '🐦',
    '🐤',
    '🐣',
    '🦆',
    '🦅',
    '🦉',
    '🦇',
    '🐺',
    '🐗',
    '🐴',
    '🦄',
    '🐝',
    '🪱',
    '🐛',
    '🦋',
    '🐌',
    '🐞',
    '🐜',
    '🪰',
    '🪲',
    '🪳',
    '🕷️',
    '🕸️',
    '🦂',
    '🐢',
    '🐍',
    '🦎',
    '🦖',
    '🦕',
    '🐙',
    '🦑',
    '🦐',
    '🦞',
    '🦀',
    '🐡',
    '🐠',
    '🐟',
    '🐬',
    '🐳',
    '🐋',
    '🦈',
    '🪸',
    '🐊',
    '🐅',
    '🐆',
    '🦓',
    '🦍',
    '🦧',
    '🐘',
    '🦛',
    '🦏',
    '🐪',
    '🐫',
    '🦒',
    '🦘',
    '🦬',
    '🐃',
    '🐂',
    '🐄',
    '🐎',
    '🐖',
    '🐏',
    '🐑',
    '🐐',
    '🦌',
    '🐕',
    '🐩',
    '🦮',
    '🐈',
    '🦢',
    '🦩',
    '🦚',
    '🦜',
    '🌵',
    '🌲',
    '🌳',
    '🌴',
    '🪴',
    '🌱',
    '🌿',
    '☘️',
    '🍀',
    '🎍',
    '🪻',
    '🌷',
    '🌹',
    '🥀',
    '🌺',
    '🌸',
    '🌼',
    '🌻',
    '🌞',
    '🌝',
    '🌛',
    '🌜',
    '🌚',
    '🌙',
    '⭐',
    '🌟',
    '✨',
    '⚡',
    '☄️',
    '🔥',
    '🌈',
    '☀️',
    '⛅',
    '☁️',
    '🌧️',
    '⛈️',
    '❄️',
    '🌊',
  ];

  static const foodAndDrink = <String>[
    '🍏',
    '🍎',
    '🍐',
    '🍊',
    '🍋',
    '🍌',
    '🍉',
    '🍇',
    '🍓',
    '🫐',
    '🍈',
    '🍒',
    '🍑',
    '🥭',
    '🍍',
    '🥥',
    '🥝',
    '🍅',
    '🍆',
    '🥑',
    '🥦',
    '🥬',
    '🥒',
    '🌶️',
    '🫑',
    '🌽',
    '🥕',
    '🧄',
    '🧅',
    '🥔',
    '🍠',
    '🫘',
    '🥐',
    '🥯',
    '🍞',
    '🥖',
    '🥨',
    '🧀',
    '🥚',
    '🍳',
    '🧈',
    '🥞',
    '🧇',
    '🥓',
    '🥩',
    '🍗',
    '🍖',
    '🌭',
    '🍔',
    '🍟',
    '🍕',
    '🥪',
    '🥙',
    '🧆',
    '🌮',
    '🌯',
    '🥗',
    '🍝',
    '🍜',
    '🍲',
    '🍛',
    '🍣',
    '🍱',
    '🥟',
    '🍤',
    '🍙',
    '🍚',
    '🍘',
    '🍥',
    '🫕',
    '🥫',
    '🍿',
    '🧂',
    '🍩',
    '🍪',
    '🎂',
    '🍰',
    '🧁',
    '🍫',
    '🍬',
    '🍭',
    '🍮',
    '🍯',
    '🍼',
    '🥛',
    '☕',
    '🍵',
    '🧃',
    '🥤',
    '🧋',
    '🍶',
    '🍺',
    '🍻',
    '🥂',
    '🍷',
    '🥃',
    '🍸',
    '🍹',
    '🧉',
    '🍾',
    '🧊',
  ];

  static const activities = <String>[
    '⚽',
    '🏀',
    '🏈',
    '⚾',
    '🥎',
    '🎾',
    '🏐',
    '🏉',
    '🥏',
    '🎱',
    '🪀',
    '🏓',
    '🏸',
    '🏒',
    '🏑',
    '🥍',
    '🏏',
    '⛳',
    '🪁',
    '🎣',
    '🤿',
    '🥊',
    '🥋',
    '🎽',
    '🛹',
    '🛼',
    '🛷',
    '⛸️',
    '🥌',
    '🎿',
    '⛷️',
    '🏂',
    '🪂',
    '🏋️',
    '🤼',
    '🤸',
    '⛹️',
    '🤾',
    '🏌️',
    '🏇',
    '🧘',
    '🏄',
    '🏊',
    '🚣',
    '🧗',
    '🚴',
    '🚵',
    '🥇',
    '🥈',
    '🥉',
    '🏆',
    '🏅',
    '🎖️',
    '🎗️',
    '🎫',
    '🎟️',
    '🎪',
    '🤹',
    '🎭',
    '🩰',
    '🎨',
    '🎬',
    '🎤',
    '🎧',
    '🎼',
    '🎹',
    '🥁',
    '🪘',
    '🎷',
    '🎺',
    '🎸',
    '🪕',
    '🎻',
    '🎲',
    '♟️',
    '🎯',
    '🎳',
    '🎮',
    '🎰',
    '🧩',
  ];

  static const travel = <String>[
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '🚎',
    '🏎️',
    '🚓',
    '🚑',
    '🚒',
    '🚐',
    '🛻',
    '🚚',
    '🚛',
    '🚜',
    '🛵',
    '🏍️',
    '🚲',
    '🛴',
    '🚨',
    '🚔',
    '🚍',
    '🚘',
    '🚖',
    '🚡',
    '🚠',
    '🚟',
    '🚃',
    '🚋',
    '🚞',
    '🚝',
    '🚄',
    '🚅',
    '🚈',
    '🚂',
    '🚆',
    '🚇',
    '🚊',
    '✈️',
    '🛫',
    '🛬',
    '🛩️',
    '💺',
    '🚁',
    '🚀',
    '🛸',
    '🚢',
    '🛥️',
    '⛴️',
    '🚤',
    '🛳️',
    '⚓',
    '⛽',
    '🚧',
    '🏠',
    '🏡',
    '🏢',
    '🏣',
    '🏤',
    '🏥',
    '🏦',
    '🏨',
    '🏩',
    '🏪',
    '🏫',
    '🏬',
    '🏭',
    '🏯',
    '🏰',
    '💒',
    '🗼',
    '🗽',
    '⛪',
    '🕌',
    '🛕',
    '🕍',
    '⛩️',
    '🕋',
    '⛲',
    '⛺',
    '🌋',
    '🗻',
    '🏞️',
    '🏜️',
    '🏝️',
    '🏖️',
    '🌅',
    '🌄',
    '🌠',
  ];

  static const objects = <String>[
    '⌚',
    '📱',
    '📲',
    '💻',
    '⌨️',
    '🖥️',
    '🖨️',
    '🖱️',
    '🖲️',
    '🕹️',
    '💽',
    '💾',
    '💿',
    '📀',
    '📷',
    '📸',
    '📹',
    '🎥',
    '📞',
    '☎️',
    '📺',
    '📻',
    '🎙️',
    '🎚️',
    '🎛️',
    '🧭',
    '⏱️',
    '⏲️',
    '⏰',
    '🕰️',
    '🔋',
    '🪫',
    '🔌',
    '💡',
    '🔦',
    '🕯️',
    '🪔',
    '🧯',
    '🛢️',
    '💸',
    '💵',
    '💴',
    '💶',
    '💷',
    '🪙',
    '💳',
    '🧾',
    '💰',
    '📦',
    '✉️',
    '📩',
    '📨',
    '📧',
    '📤',
    '📥',
    '🗳️',
    '📝',
    '💼',
    '📁',
    '📂',
    '📅',
    '📆',
    '🗓️',
    '📌',
    '📍',
    '📎',
    '🖇️',
    '📏',
    '📐',
    '✂️',
    '🗃️',
    '🗄️',
    '🗑️',
    '🔒',
    '🔓',
    '🔑',
    '🗝️',
    '🔨',
    '🪓',
    '⛏️',
    '⚒️',
    '🛠️',
    '🗡️',
    '⚔️',
    '🔫',
    '🪃',
    '🏹',
    '🛡️',
  ];

  static const symbols = <String>[
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '💔',
    '❣️',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '💟',
    '☮️',
    '✝️',
    '☪️',
    '🕉️',
    '☸️',
    '✡️',
    '🔯',
    '🕎',
    '☯️',
    '♈',
    '♉',
    '♊',
    '♋',
    '♌',
    '♍',
    '♎',
    '♏',
    '♐',
    '♑',
    '♒',
    '♓',
    '⚛️',
    '🛐',
    '☢️',
    '☣️',
    '⚠️',
    '🚸',
    '⛔',
    '🚫',
    '🚳',
    '🚭',
    '🚯',
    '🚱',
    '📵',
    '🔞',
    '☢️',
    '✅',
    '☑️',
    '✔️',
    '❌',
    '⭕',
    '🔴',
    '🟠',
    '🟡',
    '🟢',
    '🔵',
    '🟣',
    '🟤',
    '⚪',
    '⚫',
    '⭐',
    '🌟',
    '✨',
    '⚡',
    '☄️',
    '💥',
    '🔥',
    '💫',
    '🔔',
    '🔕',
    '🎵',
    '🎶',
  ];
}
