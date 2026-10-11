# Revue du code : ce qui a changé et pourquoi

Ce document compare la première version (commit `9ec6e1a`) à la version actuelle. Pour chaque
point : ce qui posait problème, ce qui le remplace, et la raison. Les commentaires `/** */` du code
expliquent le reste au fil des fichiers.

## 1. Les bugs

### La page web affichait le jeu en tout petit

`index.html` donnait au canvas `height:100%`, mais ni `<html>` ni `<body>` n'avaient de hauteur.
Un pourcentage se calcule par rapport au parent : sans hauteur, le navigateur garde la hauteur par
défaut d'un canvas, **150 px**. Le `LetterBox` de Heaps faisait alors tenir le plateau dans cette
bande : sur un écran de téléphone, le jeu occupait un huitième de la largeur.

→ `html, body { height: 100% }` et `canvas { display: block }` (sinon une marge de quelques
pixels sous le canvas fait apparaître une barre de défilement).

### La ligne suivante reprenait l'essai précédent

Après une validation, `currentTry` n'était jamais vidé. Au premier clic sur la ligne suivante,
`refreshTry` redessinait les quatre anciens pions et le bouton de validation apparaissait tout de
suite : on pouvait revalider le même essai en un clic, sans voir qu'il était prérempli.

→ `Mastermind.submit()` repart d'un essai vide. C'est maintenant une règle du modèle, vérifiée par
un test (`new guess is empty`).

### Un essai fantôme en fin de partie

À la fin de `validate()`, un nouvel objet `tryObject` était créé même quand la partie était
finie, à la ligne `-1` (au-dessus du plateau, `y` négatif). Il était invisible et sans effet, mais
c'est le signe que l'état « partie finie » n'était pas vraiment pris en compte.

### `removeChild(getChildAt(4))`

Pour enlever le bouton de validation, le code retirait le 5ᵉ enfant de `tryObject`, en comptant
sur le fait que les 4 premiers sont les pions. Ça marche tant que l'ordre de création ne change
pas. Un jour on ajoute une animation ou un pion de plus, et c'est un pion qui disparaît.

→ Le bouton a sa propre variable (`submitButton`) et sa visibilité est calculée :
`submitButton.visible = game.canSubmit()`.

## 2. L'architecture : séparer les règles de l'affichage

C'est le changement principal. Dans la première version, la classe `Game` faisait tout :
les règles (`validate` calcule les bien/mal placés), l'état (`tries`, `currentTry`, `state`),
le chargement des images et l'affichage (création des `Bitmap`). Conséquences :

- **on ne peut pas tester les règles** sans ouvrir une fenêtre et cliquer ;
- **les règles dépendaient du graphisme** : les compteurs de couleurs de `validate` étaient
  initialisés en parcourant `TILE_PIONS.keys()`, c'est-à-dire la liste des *images* ;
- **l'écran et l'état pouvaient diverger** : chaque action modifiait l'affichage à la main
  (ajouter un pion ici, retirer un enfant là), donc chaque oubli laisse un écran faux, comme pour
  le bug de l'essai prérempli.

La nouvelle version a trois classes, avec un rôle chacune :

| Classe | Rôle | Dépend de |
|---|---|---|
| `mastermind.Mastermind` | le **modèle** : le secret, les essais, l'essai en cours, l'état (`Playing`, `Won`, `Lost`), et les règles | rien (pas de Heaps) |
| `view.BoardView` | la **vue** : dessine une partie, signale les clics par des callbacks (`onPickColor`, `onClickHole`, `onSubmit`, `onRestart`) | Heaps, et le modèle en lecture |
| `Game` | le **contrôleur** : reçoit les clics, modifie le modèle, demande à la vue de se redessiner | les deux |

Toute action suit le même chemin :

```
clic → BoardView.onClickHole(i) → Game : model.place(i, couleur) → view.refresh(model)
```

### La vue se redessine entièrement à partir du modèle

`BoardView.refresh(game, selected)` efface les pions et les résultats, puis les redessine d'après
le modèle. Ça paraît du gaspillage, mais il y a au plus 50 pions : c'est gratuit, et **l'écran
ne peut plus être en désaccord avec l'état**, puisqu'il en est recalculé. Ce qui ne change jamais
(trous, fonds, palette, boutons) est créé une seule fois dans le constructeur.

C'est la règle la plus utile pour un jeu Heaps : le modèle est la vérité, la vue n'en est que
le reflet. Pour un jeu en temps réel, on fait pareil, mais on met à jour les objets existants
(positions, visibilité) au lieu de les recréer.

### Les tests

Comme le modèle ne dépend pas de Heaps, `haxe test.hxml` l'exécute directement avec
l'interpréteur Haxe (`--interp`), en moins d'une seconde. Les tests couvrent les cas délicats du
calcul : une couleur répétée dans l'essai mais présente une seule fois dans le secret, une couleur
répétée dans le secret, la victoire et la défaite.

## 3. Les détails

| Avant | Après | Pourquoi |
|---|---|---|
| `enum Maybe<T> { None; Some(value:T); }` | `Null<Color>` | Haxe a déjà `haxe.ds.Option` ; et pour « un trou vide », `null` suffit et se lit mieux (`if (color != null)`) |
| `enum State { Game; Exit; Restart; }` dans `Main`, et une classe `Game` | supprimé | le constructeur `Game` de l'enum porte le même nom que la classe `Game` : `switchState(Game)` et `new Game(...)` dans la même fonction, c'est un piège à la lecture. `Restart` faisait la même chose que `Game`, et `Exit` n'était jamais appelé |
| `enum State { Play; Pause; End; Restart; }` dans `Game` | `enum Status { Playing; Won; Lost; }` | `Pause` et `Restart` n'étaient jamais utilisés ; `End` ne disait pas si on avait gagné ou perdu, ce qu'un écran de fin voudra savoir |
| `class GameController` avec deux variables de fonction | des `dynamic function` sur la vue et sur `Game` | c'est la convention de Heaps (`Interactive.onClick`, `Window.onClose`…) : pas besoin d'une classe pour transporter deux callbacks, et on a une implémentation vide par défaut, donc pas de crash si personne ne s'abonne |
| Une nouvelle `h2d.Scene` par partie, avec `setScene` | un objet dans `s2d`, retiré à la fin de la partie | une scène par partie n'apporte rien ici ; `s2d` existe déjà, et la mise à l'échelle se règle une seule fois dans `Main` |
| `CURSOR_PIONS` (6 × `toBitmap()`) | supprimé | jamais utilisé, et `toBitmap()` décode chaque PNG en mémoire à chaque partie |
| `TILE_CELL`, `TILE_PIONS`… en majuscules | `pegTiles`… | les majuscules annoncent des constantes ; c'étaient des variables d'instance |
| `drawRows(x, y, parent)` créait ses objets dans `this.scene` | — | le paramètre `parent` était ignoré |
| L'ordre de la palette venait de l'ordre d'itération d'une `Map` | `Mastermind.COLORS = Type.allEnums(Color)` | l'ordre d'une `Map` n'est pas une garantie du langage ; l'ordre de l'enum, si |
| `init(game:Main)`, `update()`, `drawMenu()` vides, `override update` qui appelle juste `super` | supprimés | du code qui ne fait rien, mais qu'il faut lire |
| Le README parlait de `compile.hxml` | les vraies commandes | ce fichier n'existe pas |

## 4. Ce qui était bien et qui reste

- **Le `LetterBox`** : dessiner sur un écran virtuel fixe et laisser Heaps l'adapter à la
  fenêtre, c'est exactement la bonne approche pour un jeu 2D.
- **`hxd.Res.initEmbed()`** : les images sont embarquées dans le programme, ce qui marche pareil en
  JS et en HashLink.
- **Le calcul des mal placés** par `min(occurrences dans le secret, occurrences dans l'essai)` :
  c'est le bon algorithme, il est gardé tel quel (et maintenant testé).
- **`generator` remplaçable** : l'idée de pouvoir imposer le secret, pour tester, était bonne.
  Elle devient un paramètre du constructeur : `new Mastermind([Red, Blue, Blue, Green])`.
- **`compile_base.hxml`** partagé par les cibles, et les tâches VS Code.
