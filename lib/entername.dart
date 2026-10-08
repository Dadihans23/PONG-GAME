import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/aide.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/hompage.dart';
import 'package:pong_game/leaderboard.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/settings/settings_page.dart';
import 'package:pong_game/statistics.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Accueil (maquette H1 / H2), en trois étages : qui joue (pseudo) → à quoi
/// (cartes de mode, la difficulté vit dans la carte Solo) → « Jouer ».
/// Classement, Statistiques et Aide sont des raccourcis neutres en bas.
class NamePage extends StatefulWidget {
  const NamePage({super.key, this.savedPseudo});

  final String? savedPseudo;

  /// Difficultés transmises au jeu, telles quelles (`MyHomePage.difficulty`).
  static const List<String> difficulties = ['Facile', 'Normal', 'Difficile'];

  /// Longueur maximale d'un pseudo : il tient sur une ligne du classement.
  static const int pseudoMaxLength = PongSettings.pseudoMaxLength;

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  // Sons : un lecteur par son, chargé une fois à l'ouverture de l'écran
  final GameSound _ambientSound =
      GameSound('sounds/athmopshere.mp3', loop: true);
  final GameSound _letsgoSound = GameSound('sounds/letsgo.mp3');
  final GameSound _shootSound = GameSound('sounds/shoot.mp3');

  String _difficulty = 'Normal';

  // Pseudo courant (celui de Hive au lancement, puis le dernier enregistré)
  String? _pseudo;
  bool _editingPseudo = false; // true quand le joueur a tapé « Modifier »
  bool _isStarting = false; // true entre le tap sur « Jouer » et le retour du jeu

  // Erreur du champ pseudo, et compteur qui le refait trembler à chaque refus
  String? _pseudoError;
  int _pseudoShake = 0;

  bool get _hasSavedPseudo => _pseudo != null && _pseudo!.isNotEmpty;
  bool get _showPseudoField => !_hasSavedPseudo || _editingPseudo;

  @override
  void initState() {
    super.initState();
    _ambientSound.play();
    _pseudo = widget.savedPseudo;
    if (_hasSavedPseudo) _nameController.text = _pseudo!;
  }

  @override
  void dispose() {
    _ambientSound.dispose();
    _letsgoSound.dispose();
    _shootSound.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _startPlaying() async {
    // Un second tap pendant le lancement n'ouvre pas une deuxième partie
    if (_isStarting) return;
    FocusScope.of(context).unfocus();

    // Un pseudo vide ou fait d'espaces est refusé
    final playerName = _nameController.text.trim();
    if (playerName.isEmpty) {
      setState(() {
        _editingPseudo = true;
        _pseudoError = 'Choisis un pseudo pour jouer';
        _pseudoShake++;
      });
      return;
    }

    _isStarting = true;
    Hive.box('settings').put('pseudo', playerName);
    _nameController.text = playerName;
    setState(() {
      _pseudo = playerName;
      _editingPseudo = false;
      _pseudoError = null;
    });

    _ambientSound.stop();
    // Lecteur membre : NamePage reste dans la pile sous le jeu, le son
    // continue donc pendant la transition
    await _letsgoSound.play();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(
          title: 'Pong Game',
          playerName: playerName,
          difficulty: _difficulty,
        ),
      ),
    );

    // Retour du jeu : rafraîchir le meilleur score et relancer la musique
    _isStarting = false;
    if (!mounted) return;
    setState(() {});
    _ambientSound.play();
  }

  void _editPseudo() {
    setState(() => _editingPseudo = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  /// Ouvre les Réglages ; au retour, reprend le pseudo s'il a changé.
  Future<void> _openSettings() async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
    if (!mounted) return;
    final pseudo = PongSettings().pseudo;
    if (pseudo == null || pseudo == _pseudo) return;
    _nameController.text = pseudo;
    setState(() {
      _pseudo = pseudo;
      _editingPseudo = false;
      _pseudoError = null;
    });
  }

  void _selectDifficulty(String difficulty) {
    setState(() => _difficulty = difficulty);
    _shootSound.play();
  }

  void _open(Widget page) {
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  /// En dessous de cette hauteur d'écran (dp), les espacements passent de
  /// 16 à 12 pour que « Jouer » et les raccourcis restent visibles sans
  /// défiler (SM-A135F : 713 dp, barre de navigation comprise).
  static const double _compactHeight = 760;

  @override
  Widget build(BuildContext context) {
    final topScore = Hive.box<int>('scores').get('topscore', defaultValue: 0) ?? 0;
    final gap = MediaQuery.sizeOf(context).height < _compactHeight
        ? PongSpacing.sm
        : PongSpacing.md;
    return Scaffold(
      backgroundColor: PongColors.background,
      // Réglages à droite ; la place de gauche (48 px) reste vide pour
      // que le logo soit centré
      appBar: PongHeaderBar(
        center: const PongLogo(fontSize: 32),
        showBack: false,
        trailing: PongIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'Réglages',
          color: PongColors.textSecondary,
          onPressed: _openSettings,
        ),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(PongSpacing.screen,
                    PongSpacing.xs, PongSpacing.screen, gap + PongSpacing.xxs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _showPseudoField ? _buildPseudoField() : _buildGreeting(),
                    SizedBox(height: gap + PongSpacing.xxs),
                    const PongOverline('Mode de jeu'),
                    SizedBox(height: gap),
                    _SoloModeCard(
                      difficulty: _difficulty,
                      topScore: topScore,
                      // Comme la maquette H1 : sans consigne ni meilleur
                      // score quand le champ pseudo occupe déjà la place
                      showDetails: !_showPseudoField,
                      onDifficultyChanged: _selectDifficulty,
                    ),
                    SizedBox(height: gap),
                    const _MultiplayerModeCard(),
                    const Spacer(),
                    SizedBox(height: gap),
                    PongPrimaryButton(label: 'Jouer', onPressed: _startPlaying),
                    SizedBox(height: gap),
                    _Shortcuts(onOpen: _open),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPseudoField() {
    return PongTextField(
      controller: _nameController,
      focusNode: _nameFocus,
      label: 'Ton pseudo',
      hintText: 'Entre ton pseudo',
      errorText: _pseudoError,
      shakeTrigger: _pseudoShake,
      maxLength: NamePage.pseudoMaxLength,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) {
        // L'erreur disparaît dès que le joueur écrit
        if (_pseudoError != null) setState(() => _pseudoError = null);
      },
      onSubmitted: (_) => _nameFocus.unfocus(),
    );
  }

  Widget _buildGreeting() {
    return SizedBox(
      height: PongSizes.touchTarget,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Bonjour, $_pseudo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PongText.headline,
            ),
          ),
          const SizedBox(width: PongSpacing.xs),
          PongTextButton(
            label: 'Modifier',
            icon: Icons.edit_rounded,
            color: PongColors.pinkLight,
            onPressed: _editPseudo,
          ),
        ],
      ),
    );
  }
}

/// Carte Solo, toujours sélectionnée (seul mode disponible) : difficulté et
/// meilleur score.
class _SoloModeCard extends StatelessWidget {
  const _SoloModeCard({
    required this.difficulty,
    required this.topScore,
    required this.showDetails,
    required this.onDifficultyChanged,
  });

  final String difficulty;
  final int topScore;

  /// Affiche « Choisis la difficulté » et le meilleur score.
  final bool showDetails;
  final ValueChanged<String> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    return PongChoiceCard(
      icon: Icons.person_rounded,
      title: 'Solo',
      subtitle: "Contre l'ordinateur",
      selected: true,
      // Déjà choisi : le toucher ne change rien, mais la carte reste active
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDetails) ...[
            Text('Choisis la difficulté',
                style: PongText.caption.copyWith(fontWeight: FontWeight.w400)),
            const SizedBox(height: PongSpacing.xs),
          ],
          // Segments posés directement dans la carte, sans le rail de
          // `PongSegmentedControl` : la carte joue déjà ce rôle (maquette H2)
          Row(
            children: [
              for (final value in NamePage.difficulties) ...[
                if (value != NamePage.difficulties.first)
                  const SizedBox(width: PongSpacing.xs),
                Expanded(
                  child: PongSelectableButton(
                    label: value,
                    selected: value == difficulty,
                    onPressed: () => onDifficultyChanged(value),
                  ),
                ),
              ],
            ],
          ),
          if (showDetails && topScore > 0) ...[
            const SizedBox(height: 14),
            _BestScoreRow(score: topScore),
          ],
        ],
      ),
    );
  }
}

/// Ligne « Meilleur score » sous un filet, en or record.
class _BestScoreRow extends StatelessWidget {
  const _BestScoreRow({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final value = PongFormat.number(score);
    return Semantics(
      label: 'Meilleur score : $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.only(top: PongSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: PongColors.borderSubtle)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 18, color: PongColors.record),
            const SizedBox(width: PongSpacing.xs),
            Expanded(
              child: Text('Meilleur score',
                  style:
                      PongText.caption.copyWith(fontWeight: FontWeight.w400)),
            ),
            Text(value,
                style: PongText.listValue
                    .copyWith(fontSize: 16, color: PongColors.record)),
          ],
        ),
      ),
    );
  }
}

/// Carte Multijoueur : le mode n'existe pas encore, la carte est visible
/// mais désactivée, avec la mention « Bientôt ».
class _MultiplayerModeCard extends StatelessWidget {
  const _MultiplayerModeCard();

  @override
  Widget build(BuildContext context) {
    return const PongChoiceCard(
      icon: Icons.group_rounded,
      title: 'Multijoueur',
      // ‑ : trait d'union insécable, « Wi-Fi » ne se coupe pas
      subtitle: 'À deux, même Wi‑Fi',
      selected: false,
      onTap: null,
      trailing: PongPill.status(label: 'Bientôt'),
    );
  }
}

/// Raccourcis neutres : Classement · Statistiques · Aide.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PongTileButton(
            icon: Icons.leaderboard_rounded,
            label: 'Classement',
            onPressed: () => onOpen(const LeaderboardPage()),
          ),
        ),
        const SizedBox(width: PongSpacing.xs),
        Expanded(
          child: PongTileButton(
            icon: Icons.bar_chart_rounded,
            label: 'Statistiques',
            onPressed: () => onOpen(const StatisticsPage()),
          ),
        ),
        const SizedBox(width: PongSpacing.xs),
        Expanded(
          child: PongTileButton(
            icon: Icons.help_rounded,
            label: 'Aide',
            onPressed: () => onOpen(const AidePage()),
          ),
        ),
      ],
    );
  }
}
