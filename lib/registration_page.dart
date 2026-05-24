import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_language.dart';
import 'app_scope.dart';
import 'eula_page.dart';
import 'log_service.dart';
import 'privacy_policy_page.dart';
import 'tapflow_page.dart';

enum _RegistrationStep {
  server,
  serverLogin,
  name,
  theme,
  inputField,
  navigationPanel,
  thanks,
}

class _CreateServerPage extends StatefulWidget {
  const _CreateServerPage({this.onSaved});

  final Future<void> Function(String url, String anonKey)? onSaved;

  @override
  State<_CreateServerPage> createState() => _CreateServerPageState();
}

class _CreateServerPageState extends State<_CreateServerPage> {
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseAnonKeyController =
      TextEditingController();
  bool _ready = false;

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _supabaseUrlController.addListener(_syncReady);
    _supabaseAnonKeyController.addListener(_syncReady);
    _syncReady();
  }

  void _syncReady() {
    final next =
        _supabaseUrlController.text.trim().isNotEmpty &&
        _supabaseAnonKeyController.text.trim().isNotEmpty;
    if (next == _ready) return;
    setState(() => _ready = next);
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context);
    final url = _supabaseUrlController.text.trim();
    final key = _supabaseAnonKeyController.text.trim();
    if (url.isEmpty || key.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server.supabase.url', url);
      await prefs.setString('server.supabase.anonKey', key);
      final cb = widget.onSaved;
      if (cb != null) {
        await cb(url, key);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('save_error').replaceAll('\$e', e.toString()))));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('create_server'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Text(
              l10n.get('server_docs_desc'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _ServerDocsPage(),
                    ),
                  );
                },
                child: Text(l10n.get('docs')),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _supabaseUrlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                hintText: 'Supabase API URL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.get('supabase_url_hint'),
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _supabaseAnonKeyController,
              textInputAction: TextInputAction.done,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                hintText: 'Supabase anon publick key',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _ready ? _continue : null,
                child: Text(l10n.get('continue_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerDocsPage extends StatefulWidget {
  const _ServerDocsPage();

  @override
  State<_ServerDocsPage> createState() => _ServerDocsPageState();
}

class _ServerDocsPageState extends State<_ServerDocsPage> {
  static final RegExp _urlRe = RegExp(r'(https?:\/\/[^\s]+)');

  final _scrollController = ScrollController();
  final _key1 = GlobalKey();
  final _key2 = GlobalKey();
  final _key3 = GlobalKey();
  final _key4 = GlobalKey();
  final _key5 = GlobalKey();
  final _key6 = GlobalKey();
  final _key7 = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final listViewContext = _scrollController.position.context.storageContext;
    final listViewRenderBox = listViewContext.findRenderObject() as RenderBox?;
    if (listViewRenderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero, ancestor: listViewRenderBox);
    final targetOffset = _scrollController.offset + position.dy;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _h(String text, {GlobalKey? key}) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );

  Widget _buildTableOfContents(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Оглавление',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _tocItem(context, '1. Подготовка Supabase', () => _scrollTo(_key1)),
          _tocItem(context, '2. Получение ключей облачного хранилища', () => _scrollTo(_key2)),
          _tocItem(context, '3. Настройка разрешений для работы токенов', () => _scrollTo(_key3)),
          _tocItem(context, '4. Получение авторизационного кода', () => _scrollTo(_key4)),
          _tocItem(context, '5. Получение Refresh Token через терминал', () => _scrollTo(_key5)),
          _tocItem(context, '6. Финальная настройка в Supabase', () => _scrollTo(_key6)),
          _tocItem(context, '7. Решение проблем SQL', () => _scrollTo(_key7)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Рекомендуется за место 2 пункт!',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tocItem(BuildContext context, String title, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: cs.primary,
              decoration: TextDecoration.underline,
              decorationColor: cs.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _linkify(String text, TextStyle style, TextStyle linkStyle) {
    final out = <TextSpan>[];
    final matches = _urlRe.allMatches(text).toList(growable: false);
    if (matches.isEmpty) return [TextSpan(text: text, style: style)];

    var start = 0;
    for (final m in matches) {
      if (m.start > start) {
        out.add(TextSpan(text: text.substring(start, m.start), style: style));
      }
      final url = text.substring(m.start, m.end);
      out.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      out.add(TextSpan(text: text.substring(start), style: style));
    }
    return out;
  }

  Widget _p(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final linkStyle = style.copyWith(
      color: cs.primary,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary.withValues(alpha: 0.7),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SelectableText.rich(
        TextSpan(children: _linkify(text, style, linkStyle)),
      ),
    );
  }

  Widget _code(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _fileTile({
    required BuildContext context,
    required String title,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Material(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
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

  Widget _img(BuildContext context, String asset, {String? caption}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _DocImageViewerPage(asset: asset),
                ),
              );
            },
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('docs')),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _p(context, 'Данное приложение работает на сервере Supabase.'),
              const SizedBox(height: 12),
              _buildTableOfContents(context),
              const SizedBox(height: 12),
              _h('1. Подготовка Supabase', key: _key1),
            _p(
              context,
              'Для начала вам нужно зарегистрироваться на сайте: http://supabase.com/',
            ),
            _p(context, 'После этого создайте организацию.'),
            _img(
              context,
              'assets/docum/SRC1.png',
              caption: 'Пример создания организации',
            ),
            _p(
              context,
              'Далее система попросит вас создать приложение. Придумайте имя и пароль для вашего приложения. В качестве региона рекомендую оставить Европу.',
            ),
            _img(
              context,
              'assets/docum/SRC2.png',
              caption: 'Имя и пароль замазаны в целях безопасности',
            ),
            _p(
              context,
              'После создания приложения перейдите в категорию SQL Editor и введите в поле всё, что написано в предоставленном документе, а затем нажмите Run (зелёная кнопка).',
            ),
            _fileTile(
              context: context,
              title: '@SQL_CODE.txt',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _SqlCodePage(
                      assetPath: 'assets/docum/SQL_CODE.txt',
                      title: '@SQL_CODE.txt',
                    ),
                  ),
                );
              },
            ),
            _img(context, 'assets/docum/SRC3.png'),
            _p(
              context,
              'Перейдите в раздел Edge Function — Secrets. Не закрывайте эту страницу.',
            ),
            _img(context, 'assets/docum/SRC4.png'),
            _h('2. Получение ключей облачного хранилища', key: _key2),
            _p(
              context,
              'Перейдите на сайт вашего облака и получите APP_KEY и APP_SECRET.',
            ),
            _p(
              context,
              'Примечание: Дальнейшая инструкция приведена на примере Dropbox, так как приложение создавалось под него изначально!',
            ),
            _p(
              context,
              'Перейдите на сайт Dropbox, зарегистрируйте новый аккаунт и откройте страницу разработчика: https://www.dropbox.com/developers/apps.',
            ),
            _p(
              context,
              'Инициируйте создание нового приложения с помощью команды Create app.',
            ),
            _img(context, 'assets/docum/SRC5.png'),
            _h('3. Настройка разрешений для работы токенов', key: _key3),
            _p(
              context,
              'В интерфейсе управления приложением перейдите во вкладку Permissions.',
            ),
            _p(
              context,
              'Активируйте полномочия в блоке работы с контентом, указанные на скриншоте.',
            ),
            _img(context, 'assets/docum/SRC6.png'),
            _p(
              context,
              'Обязательно подтвердите изменения нажатием кнопки Submit в нижней части страницы, чтобы они вступили в силу.',
            ),
            _h('4. Получение авторизационного кода', key: _key4),
            _p(
              context,
              'Перейдите во вкладку Settings и скопируйте значение из поля App key. Нажмите кнопку Show в поле App secret и скопируйте отобразившееся значение.',
            ),
            _img(context, 'assets/docum/SRC7.png'),
            _p(
              context,
              'Перейдите по ссылке: https://www.dropbox.com/oauth2/authorize?client_id=ВАШ_APP_KEY&token_access_type=offline&response_type=code, предварительно заменив «ВАШ_APP_KEY» на фактический App key из настроек.',
            ),
            _p(
              context,
              'После этого нажимайте «Продолжить», «Согласиться» или «Предоставить», как показано на скриншотах.',
            ),
            _img(context, 'assets/docum/SRC8.png'),
            _img(context, 'assets/docum/SRC9.png'),
            _img(context, 'assets/docum/SRC10.png'),
            _h('5. Получение Refresh Token через терминал', key: _key5),
            _p(
              context,
              'Откройте CMD (командную строку), скопируйте ваши данные и подставьте их в следующую команду:',
            ),
            _code(
              context,
              'curl https://api.dropbox.com/oauth2/token ^\n'
              '    -d code=ВАШ_ПОЛУЧЕННЫЙ_КОД ^\n'
              '    -d grant_type=authorization_code ^\n'
              '    -u ВАШ_APP_KEY:ВАШ_APP_SECRET\n'
              '(Символ ^ в Windows CMD используется для переноса строки. Если вставляете команду одной строкой, уберите его.)',
            ),
            _img(context, 'assets/docum/SRC11.png'),
            _h('6. Финальная настройка в Supabase', key: _key6),
            _p(
              context,
              'Откройте раздел секретов или переменных окружения в Supabase.',
            ),
            _p(
              context,
              'Внесите скопированный App key в поле DROPBOX_APP_KEY.',
            ),
            _p(
              context,
              'Внесите скопированный App secret в поле DROPBOX_APP_SECRET.',
            ),
            _p(
              context,
              'Внесите полученный на пятом этапе Refresh Token в поле DROPBOX_REFRESH_TOKEN.',
            ),
            _img(context, 'assets/docum/SRC4.png'),
            _h('7. Решение проблем SQL', key: _key7),
            _p(
              context,
              'Если картинки не отправляются или же SQL код не принимается, то удалите все приватные файлы (где вводили SQL код), создайте новый лист и введите код из файла @SQL_CODE_VER2.txt.',
            ),
            _fileTile(
              context: context,
              title: '@SQL_CODE_VER2.txt',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _SqlCodePage(
                      assetPath: 'assets/docum/SQL_CODE_VER2.txt',
                      title: '@SQL_CODE_VER2.txt',
                    ),
                  ),
                );
              },
            ),
            _p(
              context,
              'После этого создайте ещё один лист и введите код из файла @ChatToken.txt.',
            ),
            _fileTile(
              context: context,
              title: '@ChatToken.txt',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _SqlCodePage(
                      assetPath: 'assets/docum/ChatToken.txt',
                      title: '@ChatToken.txt',
                    ),
                  ),
                );
              },
            ),
            _p(
              context,
              'После этого зайдите в Edge Functions, нажмите Deploy a new function и затем Via Editor.',
            ),
            _img(context, 'assets/docum/SRC12.png'),
            _p(
              context,
              'Там будет файл index.ts — переименуйте его в uploadAndGetRawLink.ts, затем вставьте код из файла и нажмите Deploy updates.',
            ),
            _fileTile(
              context: context,
              title: '@DropReshBR.txt',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _SqlCodePage(
                      assetPath: 'assets/docum/DropReshBR.txt',
                      title: '@DropReshBR.txt',
                    ),
                  ),
                );
              },
            ),
            _p(
              context,
              'Зайдите в настройки этой функции и проверьте, что всё совпадает с инструкцией.',
            ),
            _img(context, 'assets/docum/SRC13.png'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocImageViewerPage extends StatelessWidget {
  const _DocImageViewerPage({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(child: Image.asset(asset)),
        ),
      ),
    );
  }
}

class _SqlCodePage extends StatelessWidget {
  const _SqlCodePage({required this.assetPath, required this.title});

  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(assetPath),
          builder: (context, snap) {
            final text = snap.data ?? '';
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: text.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: text),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Скопировано')),
                              );
                            },
                      child: const Text('Копировать'),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(text.isEmpty ? 'Загрузка...' : text),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _InputFieldChoice { normal, advanced, ios }

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    this.onSupabaseConfigSaved,
    this.requireSupabaseConfig = false,
  });

  final Future<void> Function(String url, String anonKey)?
  onSupabaseConfigSaved;
  final bool requireSupabaseConfig;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseAnonKeyController =
      TextEditingController();
  _RegistrationStep _step = _RegistrationStep.server;
  ThemeMode? _selected;
  bool _busy = false;
  Color? _seedDraft;
  _InputFieldChoice? _inputFieldChoice;
  bool? _messengerNavChoice;

  @override
  void dispose() {
    _nameController.dispose();
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    super.dispose();
  }

  Future<bool> _saveSupabaseConfig() async {
    final url = _supabaseUrlController.text.trim();
    final key = _supabaseAnonKeyController.text.trim();
    if (url.isEmpty || key.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server.supabase.url', url);
    await prefs.setString('server.supabase.anonKey', key);

    try {
      await Supabase.initialize(url: url, anonKey: key);
      LogService.instance.info('Supabase инициализирован с данными пользователя');
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка подключения к Supabase: $e')),
      );
      return false;
    }

    return true;
  }

  Future<void> _submitName() async {
    final controller = AppScope.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_busy) return;
    setState(() {
      _busy = true;
    });
    await controller.setDisplayName(name);
    setState(() {
      _step = _RegistrationStep.theme;
      _busy = false;
    });
  }

  Future<void> _selectTheme(ThemeMode mode) async {
    final controller = AppScope.of(context);
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    setState(() {
      _selected = mode;
    });
    await controller.setThemeMode(mode);
    setState(() => _busy = false);
  }

  Future<void> _continueFromTheme() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final controller = AppScope.of(context);
      if (_seedDraft != null) {
        await controller.setSeedColor(_seedDraft!);
      }
      setState(() => _step = _RegistrationStep.inputField);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectInputFieldChoice(_InputFieldChoice choice) async {
    final controller = AppScope.of(context);
    setState(() => _inputFieldChoice = choice);

    switch (choice) {
      case _InputFieldChoice.normal:
        await controller.setAdvancedComposerEnabled(false);
        await controller.setIosInputPanelEnabled(false);
        break;
      case _InputFieldChoice.advanced:
        await controller.setAdvancedComposerEnabled(true);
        break;
      case _InputFieldChoice.ios:
        await controller.setIosInputPanelEnabled(true);
        break;
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _continueFromInputField() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      setState(() => _step = _RegistrationStep.navigationPanel);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectNavigationPanel(bool iosStyle) async {
    final controller = AppScope.of(context);
    setState(() => _messengerNavChoice = iosStyle);
    await controller.setMessengerNavEnabled(iosStyle);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _continueFromNavigationPanel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final controller = AppScope.of(context);
      LogService.instance.info('Завершение регистрации');
      setState(() => _step = _RegistrationStep.thanks);
      await controller.completeOnboarding();
      LogService.instance.info('Регистрация завершена');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _seedDraft ??= AppScope.of(context).seedColor;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Center(
                child: Text(
                  l10n.get('registration'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _buildBody(context),
                ),
              ),
              if (_step == _RegistrationStep.server) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.privacy_tip, size: 18),
                        label: const Text('Privacy Policy'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        icon: Icon(Icons.description, size: 18),
                        label: const Text('EULA'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const EulaPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_step) {
      case _RegistrationStep.server:
        return Center(
          key: const ValueKey('server'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.get('server'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.get('server_setup_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<bool>(
                              builder: (_) => _CreateServerPage(
                                onSaved: widget.onSupabaseConfigSaved,
                              ),
                            ),
                          )
                          .then((ok) {
                            if (!mounted) return;
                            if (ok == true) {
                              setState(() => _step = _RegistrationStep.name);
                            }
                          });
                    },
                    child: Text(l10n.get('create_server')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _step = _RegistrationStep.serverLogin);
                    },
                    child: Text(l10n.get('login_to_server')),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );

      case _RegistrationStep.serverLogin:
        return Center(
          key: const ValueKey('serverLogin'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.get('login_to_server'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Firebase уже используется в приложении (push-уведомления), но эти данные настраиваются в проекте и сюда вводить не нужно.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _supabaseUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    hintText: 'Supabase API URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.get('supabase_url_hint'),
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _supabaseAnonKeyController,
                  textInputAction: TextInputAction.done,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    hintText: 'Supabase anon public key',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await _saveSupabaseConfig();
                            if (!ok) return;
                            try {
                              final cb = widget.onSupabaseConfigSaved;
                              if (cb != null) {
                                await cb(
                                  _supabaseUrlController.text.trim(),
                                  _supabaseAnonKeyController.text.trim(),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('Ошибка сервера: $e')),
                              );
                              return;
                            }
                            if (!mounted) return;
                            setState(() => _step = _RegistrationStep.name);
                          },
                          child: Text(l10n.get('continue_btn')),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TapFlowPage(
                              mode: TapFlowMode.receiveSupabase,
                              onSupabaseAccepted: (url, anonKey) async {
                                _supabaseUrlController.text = url;
                                _supabaseAnonKeyController.text = anonKey;

                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'server.supabase.url',
                                  url.trim(),
                                );
                                await prefs.setString(
                                  'server.supabase.anonKey',
                                  anonKey.trim(),
                                );

                                try {
                                  await Supabase.initialize(url: url.trim(), anonKey: anonKey.trim());
                                  LogService.instance.info('Supabase инициализирован через TapFlow');
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка подключения к Supabase: $e')),
                                  );
                                  return;
                                }

                                final cb = widget.onSupabaseConfigSaved;
                                if (cb != null) {
                                  await cb(url, anonKey);
                                }

                                if (!mounted) return;
                                setState(() => _step = _RegistrationStep.name);
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Ввести через TapFlow'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case _RegistrationStep.name:
        return Center(
          key: const ValueKey('name'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.get('what_to_call_you'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitName(),
                        style: Theme.of(context).textTheme.titleMedium,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          hintText: l10n.get('name_hint'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : _submitName,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.arrow_forward, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );

      case _RegistrationStep.theme:
        return Center(
          key: const ValueKey('theme'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.get('theme_and_color_prompt'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                _ThemeChoiceTile(
                  title: l10n.get('light'),
                  selected: _selected == ThemeMode.light,
                  onTap: _busy ? () {} : () => _selectTheme(ThemeMode.light),
                ),
                const SizedBox(height: 10),
                _ThemeChoiceTile(
                  title: l10n.get('dark'),
                  selected: _selected == ThemeMode.dark,
                  onTap: _busy ? () {} : () => _selectTheme(ThemeMode.dark),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.get('button_colors'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 10),
                _SeedColorRow(
                  selected: _seedDraft ?? AppScope.of(context).seedColor,
                  onPick: (c) async {
                    setState(() => _seedDraft = c);
                    await AppScope.of(context).setSeedColor(c);
                    if (!mounted) return;
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_selected == null || _busy)
                        ? null
                        : _continueFromTheme,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.get('continue_btn')),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );

      case _RegistrationStep.inputField:
        return Center(
          key: const ValueKey('inputField'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                const spacing = 10.0;
                final tileW = ((w - spacing * 2) / 3).clamp(90.0, 170.0);

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.get('choose_input_field'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: tileW,
                            child: _ChoiceTile(
                              title: l10n.get('normal'),
                              selected:
                                  _inputFieldChoice == _InputFieldChoice.normal,
                              onTap: _busy
                                  ? null
                                  : () => _selectInputFieldChoice(
                                      _InputFieldChoice.normal,
                                    ),
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _ChoiceTile(
                              title: l10n.get('advanced'),
                              selected:
                                  _inputFieldChoice ==
                                  _InputFieldChoice.advanced,
                              onTap: _busy
                                  ? null
                                  : () => _selectInputFieldChoice(
                                      _InputFieldChoice.advanced,
                                    ),
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _ChoiceTile(
                              title: l10n.get('ios_panel'),
                              selected:
                                  _inputFieldChoice == _InputFieldChoice.ios,
                              onTap: _busy
                                  ? null
                                  : () => _selectInputFieldChoice(
                                      _InputFieldChoice.ios,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_inputFieldChoice != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            height: 380,
                            child: Image.asset(
                              key: ValueKey<String>(
                                switch (_inputFieldChoice!) {
                                  _InputFieldChoice.normal =>
                                    'assets/icons/obichin.gif',
                                  _InputFieldChoice.advanced =>
                                    'assets/icons/bolhoe.gif',
                                  _InputFieldChoice.ios =>
                                    'assets/icons/ios_stil.gif',
                                },
                              ),
                              switch (_inputFieldChoice!) {
                                _InputFieldChoice.normal =>
                                  'assets/icons/obichin.gif',
                                _InputFieldChoice.advanced =>
                                  'assets/icons/bolhoe.gif',
                                _InputFieldChoice.ios =>
                                  'assets/icons/ios_stil.gif',
                              },
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: (_inputFieldChoice == null || _busy)
                              ? null
                              : _continueFromInputField,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.get('continue_btn')),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),
        );

      case _RegistrationStep.navigationPanel:
        _messengerNavChoice ??= AppScope.of(context).messengerNavEnabled;
        return Center(
          key: const ValueKey('navigationPanel'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                const spacing = 10.0;
                final tileW = ((w - spacing) / 2).clamp(140.0, 240.0);

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.get('choose_navigation'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: tileW,
                            child: _ChoiceTile(
                              title: l10n.get('sliding'),
                              selected: _messengerNavChoice == false,
                              onTap: _busy
                                  ? null
                                  : () => _selectNavigationPanel(false),
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _ChoiceTile(
                              title: 'IOS',
                              selected: _messengerNavChoice == true,
                              onTap: _busy
                                  ? null
                                  : () => _selectNavigationPanel(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_messengerNavChoice != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            height: 380,
                            child: Image.asset(
                              key: ValueKey<String>(
                                _messengerNavChoice!
                                    ? 'assets/icons/ios_navig.gif'
                                    : 'assets/icons/obuch_navig.gif',
                              ),
                              _messengerNavChoice!
                                  ? 'assets/icons/ios_navig.gif'
                                  : 'assets/icons/obuch_navig.gif',
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: (_messengerNavChoice == null || _busy)
                              ? null
                              : _continueFromNavigationPanel,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.get('continue_btn')),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),
        );

      case _RegistrationStep.thanks:
        return Center(
          key: const ValueKey('thanks'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.get('thanks_for_your_time'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
    }
  }
}

class _SeedColorRow extends StatelessWidget {
  const _SeedColorRow({required this.selected, required this.onPick});

  final Color selected;
  final ValueChanged<Color> onPick;

  static const palette = <Color>[
    Color(0xFF007AFF),
    Color(0xFF34C759),
    Color(0xFF5AC8FA),
    Color(0xFFFF3B30),
    Color(0xFFFF2D55),
    Color(0xFFAF52DE),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF8E8E93),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final c in palette)
          _SeedDot(
            color: c,
            selected: c.toARGB32() == selected.toARGB32(),
            onTap: () => onPick(c),
          ),
      ],
    );
  }
}

class _SeedDot extends StatelessWidget {
  const _SeedDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = selected ? Colors.white : Colors.transparent;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 2),
        ),
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    final border = selected ? cs.primary : cs.outlineVariant;

    return SizedBox(
      height: 96,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: _RadioCircle(selected: selected),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  const _ThemeChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _RadioCircle(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioCircle extends StatelessWidget {
  const _RadioCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.black : const Color(0x55000000),
          width: 2,
        ),
        color: selected ? Colors.black : Colors.transparent,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: selected ? 1 : 0,
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      ),
    );
  }
}
