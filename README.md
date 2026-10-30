# Mastermind in <a href="https://haxe.org" > HAXE <img alt="haxe" width="40px" src="public/img/haxe.svg" style="padding-right:11px;" /></a>

Simple adaptation du jeu Mastermind avec le moteur de jeu [Heaps.io](https://heaps.io/) utilisé et maintenu par le studio [ShiroGames](https://shirogames.com/).

[Jouer!](https://mastermind-haxe.netlify.app/)

## Commandes

| Action | Souris | Clavier | Manette |
|---|---|---|---|
| Choisir une couleur | clic sur la palette | Haut / Bas (ou Z / S, W / S) | croix ou stick haut / bas |
| Choisir et poser une couleur | | 1 à 6 | |
| Déplacer le curseur | | Gauche / Droite (ou Q / D, A / D) | croix ou stick gauche / droite |
| Poser la couleur | clic sur une case | Espace | A |
| Effacer | clic sans couleur choisie | Retour arrière, Suppr | B ou X |
| Valider la ligne | bouton V | Entrée | Y |
| Recommencer | bouton R | R | Back / Select |

En fin de partie, Entrée, Espace ou A relancent une partie.

## Compilation

il faut installer [Haxe](https://haxe.org/download/) sur votre machine.

Installer la lib Heaps.io 

`haxelib install heaps`

Le principe du langage Haxe et qu'il compile vers d'autres langages ici dans
le fichier **compile_js.hxml** je précise que je souhaite cibler le javascript.

`haxe compile_js.hxml`


On peut creer autant de fichier **hxml** qu'on souhaite de language cible.

Ouvrez build/js/index.html dans un navigateur

## Tests

Les règles du jeu (`src/model/Mastermind.hx`) ne dépendent pas de Heaps : elles se testent
sans fenêtre, avec l'interpréteur de Haxe.

`haxe test.hxml`

## Capture d'écran

![Capture d'écran 1](public/img/1.jpeg) 
![Capture d'écran 2](public/img/2.jpeg) 
