"""Fichiers de relecture des traductions de Tilto.

Lit lib/l10n/app_fr.arb (modèle, avec les descriptions), app_en.arb et
app_es.arb, et écrit :

- lib/l10n/RELECTURE.md  : tableau clé | où | FR | EN | ES, à lire ;
- lib/l10n/relecture.csv : le même tableau, avec une colonne « Remarques »,
  à ouvrir dans un tableur pour annoter (UTF-8 avec BOM, séparateur « ; »).

À relancer après chaque modification des fichiers .arb :

    python tool/l10n_review.py
"""
import csv
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')
LANGS = ('fr', 'en', 'es')


def load(lang):
    with open(os.path.join(L10N, f'app_{lang}.arb'), encoding='utf8') as f:
        return json.load(f)


def visible(text):
    """Rend visibles les espaces et traits d'union insécables."""
    return text.replace('\u00a0', '⍽').replace('\u2011', '‑')


def md_cell(text):
    return visible(text).replace('|', '\\|').replace('\n', '<br>')


def main():
    arbs = {lang: load(lang) for lang in LANGS}
    template = arbs['fr']
    keys = [k for k in template if not k.startswith('@')]

    lines = [
        '# Relecture des traductions',
        '',
        'Fichier généré par `python tool/l10n_review.py` depuis `lib/l10n/*.arb` : '
        'ne pas le modifier à la main. Pour annoter, ouvrir `relecture.csv` dans '
        'un tableur (colonne « Remarques »).',
        '',
        '*Generated from `lib/l10n/*.arb` for the English and Spanish reviewers. '
        'Please annotate `relecture.csv` (column « Remarques »). The French text is '
        'the original; the « Où » column says where the text appears and how long '
        'it may be. Glossary: `GLOSSAIRE.md`.*',
        '',
        'Conventions : `{name}` est remplacé par une valeur (pseudo, nombre) et ne '
        'se traduit pas. `{count, plural, one{…} other{…}}` choisit le singulier ou '
        'le pluriel ; `{x, select, …}` choisit une variante. ⍽ marque une espace '
        'insécable, à garder.',
        '',
        f'{len(keys)} chaînes.',
        '',
        '| Clé | Où | FR | EN | ES |',
        '|---|---|---|---|---|',
    ]
    for key in keys:
        meta = template.get('@' + key, {})
        where = meta.get('description', '')
        lines.append('| `{}` | {} | {} | {} | {} |'.format(
            key, md_cell(where),
            *(md_cell(arbs[lang][key]) for lang in LANGS)))
    with open(os.path.join(L10N, 'RELECTURE.md'), 'w', encoding='utf8',
              newline='\n') as f:
        f.write('\n'.join(lines) + '\n')

    with open(os.path.join(L10N, 'relecture.csv'), 'w', encoding='utf-8-sig',
              newline='') as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerow(['Clé', 'Où (description)', 'FR', 'EN', 'ES',
                         'Remarques'])
        for key in keys:
            meta = template.get('@' + key, {})
            writer.writerow([key, meta.get('description', ''),
                             *(visible(arbs[lang][key]) for lang in LANGS), ''])
    print(f'{len(keys)} chaînes : lib/l10n/RELECTURE.md, lib/l10n/relecture.csv')


if __name__ == '__main__':
    main()
