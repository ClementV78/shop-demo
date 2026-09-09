#!/usr/bin/env python3
"""Exporte en SVG autonome un schema Archify deja rendu en HTML.

Archify produit un `.html` interactif dont le menu d'export SVG ne fonctionne
que dans un navigateur. Ce script reproduit exactement le meme resultat hors
navigateur, ce qui rend la regeneration des schemas scriptable et verifiable.

Le bloc <style> emis par l'export est identique pour tous les schemas du
projet : il est repris tel quel depuis un SVG deja exporte plutot que d'etre
reconstruit a la main.

Usage : python3 docs/diagrams/export-svg.py <schema>.html <schema>.svg
"""
import io
import re
import sys

REFERENCE_SVG = 'docs/diagrams/organisation-aws.svg'
BACKGROUND = '<rect width="100%" height="100%" class="c-bg-rect"/>'

VARIABLE = re.compile(r'(--[a-zA-Z0-9-]+)\s*:')


def style_block(path=REFERENCE_SVG):
    return re.search(r'<style>.*?</style>', io.open(path, encoding='utf-8').read(), re.S).group(0)


def check_variables(style, html):
    """Refuse d'exporter si le template a gagne des variables de theme.

    L'export officiel resout les variables CSS avec getComputedStyle, donc
    dans un navigateur. Ce script recopie a la place un bloc de style deja
    resolu, ce qui suppose que le template n'a pas change. Cette hypothese
    doit echouer bruyamment plutot que silencieusement : le commentaire du
    template rapporte que --lane-fill et --lane-stroke avaient deja ete
    oubliees une fois par le pipeline d'export.
    """
    missing = sorted(set(VARIABLE.findall(html)) - set(VARIABLE.findall(style)))
    if missing:
        sys.exit(
            "Le template Archify declare des variables absentes du bloc de style de\n"
            "reference (%s) :\n  %s\n\n"
            "Le raccourci de ce script n'est plus valable. Reexporter un schema\n"
            "depuis le menu SVG du HTML dans un navigateur, remplacer le fichier de\n"
            "reference, puis relancer." % (REFERENCE_SVG, ', '.join(missing)))


def build(html_path, svg_path):
    html = io.open(html_path, encoding='utf-8').read()
    match = re.search(r'(<svg\b[^>]*>)(.*?)(</svg>)', html, re.S)
    if not match:
        sys.exit('aucun <svg> trouve dans ' + html_path)
    open_tag, body, close_tag = match.groups()

    # Le serialiseur du navigateur explicite width/height depuis le viewBox
    # et ajoute le namespace SVG, absent de l'inline HTML.
    width, height = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', open_tag).groups()
    open_tag = '%s width="%s" height="%s" xmlns="http://www.w3.org/2000/svg">' % (
        open_tag[:-1], width, height)

    body = re.sub(r'^\s*<style>.*?</style>', '', body, count=1, flags=re.S)
    body = re.sub(r'\s+/>', '/>', body)

    style = style_block()
    check_variables(style, html)

    io.open(svg_path, 'w', encoding='utf-8').write(
        open_tag + style + BACKGROUND + body + close_tag)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2])
    print('ecrit :', sys.argv[2])
