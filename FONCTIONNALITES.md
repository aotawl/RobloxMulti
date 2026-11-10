# Roblox Multi Launcher : fiche des fonctionnalités

**Version actuelle : v2.0.1**. Cette fiche est mise à jour à chaque nouvelle version.

## Sommaire
1. [Multi-instance](#1-multi-instance)
2. [Comptes](#2-comptes)
3. [Jeux et presets](#3-jeux-et-presets)
4. [Fermeture des Roblox](#4-fermeture-des-roblox)
5. [Mode Économie](#5-mode-économie)
6. [Paramètres : anti-AFK, limites CPU/RAM, optimisation](#6-paramètres--anti-afk-limites-cpuram-optimisation)
6 bis. [Macro Anime Adventures](#6-bis-macro-anime-adventures)
7. [Arrière-plan et icône ^](#7-arrière-plan-et-icône-)
8. [Écran d'accueil (GIF / vidéo)](#8-écran-daccueil-gif--vidéo)
9. [Mises à jour](#9-mises-à-jour)
10. [Raccourcis et épinglage](#10-raccourcis-et-épinglage)
11. [Lancement, logo et terminal](#11-lancement-logo-et-terminal)
12. [Fichiers et données](#12-fichiers-et-données)
13. [Historique des versions](#13-historique-des-versions)

---

## 1. Multi-instance
Permet d'ouvrir plusieurs Roblox en même temps.

| Action | Comment |
|---|---|
| Activer / désactiver | Bouton **Activer / Désactiver** en haut, ou clic droit sur l'icône ^ → **Multi-instance activé** |
| Activation automatique | Le multi-instance s'active tout seul quand le launcher s'ouvre |
| Fermer un Roblox déjà ouvert | Si un Roblox (le jeu) est ouvert au moment de l'activation, le launcher propose de le fermer |
| Voir ce qui tourne | Le compteur affiche le nombre de Roblox (jeu) ouverts et si Roblox Studio est ouvert |

- Roblox Studio n'est jamais bloqué ni compté.
- Si tu quittes le launcher, le prochain Roblox lancé fermera les autres.

## 2. Comptes
Aucun mot de passe n'est enregistré. Seule la session est gardée, **chiffrée avec ton compte Windows**.

| Action | Comment |
|---|---|
| Ajouter un compte | Bouton **Ajouter un compte** → une fenêtre de ton navigateur principal s'ouvre sur la connexion Roblox → connecte-toi → reviens et clique **OK** |
| Lancer un compte | Sélectionne-le puis **Lancer**, ou double-clic dessus |
| Lancer plusieurs comptes | **Ctrl + clic** pour en sélectionner plusieurs, puis **Lancer** (environ 3 s entre chaque) |
| Supprimer un ou plusieurs comptes | Sélectionne-les puis **Supprimer**, ou clic droit → **Supprimer** |
| Menu clic droit | Clic droit sur la liste des comptes : **Lancer**, **Lancer et disposer les fenêtres**, **Ranger les Roblox déjà ouverts**, **Macro Anime Adventures**, **Supprimer** |
| Lancer et disposer les fenêtres | Sélectionne un ou plusieurs comptes → clic droit → **Lancer et disposer les fenêtres** → choisis une disposition (voir ci-dessous) |
| Ranger les Roblox déjà ouverts | Clic droit → **Ranger les Roblox déjà ouverts** → choisis une disposition |
| Session expirée | Le launcher prévient : supprime le compte et ajoute-le à nouveau |

**Dispositions des fenêtres** (sur l'écran où se trouve le launcher) :

| Disposition | Résultat |
|---|---|
| Grille automatique | Les fenêtres se partagent l'écran en grille (2 comptes = 2 colonnes, 4 = 2×2, 6 = 3×2...) |
| Côte à côte | Une colonne par fenêtre, sur toute la hauteur |
| Les uns sous les autres | Une ligne par fenêtre, sur toute la largeur |
| En cascade | Fenêtres empilées en décalé |

- Chaque fenêtre prend sa place dès qu'elle apparaît, puis elle est remise en place pendant 25 s, parce que Roblox se redimensionne en chargeant.
- Si tu fais un clic droit sur un compte qui n'est pas sélectionné, il est sélectionné tout seul.

- Navigateurs compatibles pour la connexion : Chrome, Edge, Brave, Opera, Vivaldi. Avec Firefox, le launcher passe par Edge.
- La fenêtre de connexion est vierge, et elle est effacée après l'ajout du compte.

## 3. Jeux et presets
| Action | Comment |
|---|---|
| Choisir un jeu | Liste déroulante : choisis un preset, ou colle un lien `roblox.com/games/...`, ou juste l'ID du jeu |
| Créer un preset | Colle un lien ou un ID → **+ Preset**. Le nom du jeu est proposé automatiquement, tu peux le changer |
| Renommer un preset | Choisis-le → **+ Preset** → mets un nouveau nom |
| Supprimer un preset | Choisis-le → **Retirer** |
| Dernier jeu | Le launcher se souvient du dernier jeu lancé |

Presets de base : **Anime Adventures** (8304191830) et **Grand Piece Online** (1730877806).

## 4. Fermeture des Roblox
| Action | Comment |
|---|---|
| Fermer tous les Roblox | Bouton **Fermer tous les Roblox**, ou clic droit sur l'icône ^ |
| Fermer un Roblox avec la croix | Le processus est arrêté pour de bon environ 1,5 s après, et le compteur baisse de 1 tout de suite |

Roblox Studio n'est jamais fermé.

## 5. Mode Économie
Ralentit les Roblox que tu **ne regardes pas**. Celui au premier plan reste toujours à fond.

| Niveau | Effet sur les Roblox en arrière-plan |
|---|---|
| Désactivée | Rien |
| Légère | Priorité basse et moitié des cœurs du processeur |
| Forte | Priorité minimale et 2 cœurs |
| Maximale | Priorité minimale et 1 cœur |

| Action | Comment |
|---|---|
| Changer le niveau | Liste **Économie** en haut à droite, ou clic droit sur l'icône ^ → **Économie** |

Le niveau choisi est mémorisé. Tout est remis à la normale quand tu quittes le launcher.

## 6. Paramètres : anti-AFK, limites CPU/RAM, optimisation
S'ouvre avec le lien **Paramètres** en bas du launcher, ou avec un clic droit sur l'icône ^ → **Paramètres**.

### Anti-AFK
Évite le kick automatique de Roblox au bout de 20 min d'inactivité.

| Action | Comment |
|---|---|
| Activer / désactiver | Case **Activer** (activé par défaut) |
| Fréquence | Une action toutes les **1 à 18 min** d'inactivité (15 par défaut) |
| Type d'action | **Clic droit** (recommandé, ne fait rien en jeu) ou **Saut (Espace)** |

- La fenêtre passe devant pendant environ 0,5 s, puis tu reviens sur ce que tu faisais.
- L'anti-AFK attend que tu ne tapes pas, sauf si le kick approche.
- Ça marche aussi pour les fenêtres réduites.

### Limites (tous les Roblox ensemble)
| Action | Comment |
|---|---|
| CPU max | Case **CPU max** puis un % du processeur (5 à 95 %). Ça s'applique à tous les Roblox ensemble |
| RAM max | Case **RAM max** puis des Mo **par Roblox** (300 à 16000). Au-delà, la mémoire va sur le disque : pas de crash, mais des lags si c'est trop bas |

Les deux limites sont désactivées par défaut.

### Optimisation (Roblox en arrière-plan)
| Action | Comment |
|---|---|
| Mode efficacité Windows | Case cochée par défaut : moins de chauffe et moins de conso |
| Libérer la RAM | Case cochée par défaut : toutes les 2 minutes |

## 6 bis. Macro Anime Adventures
Fait tourner en boucle des parties d'Anime Adventures (Infinity Mansion), sur une ou plusieurs fenêtres à la fois.

S'ouvre avec le lien **Macro Anime Adventures** en bas du launcher, avec un clic droit sur l'icône ^, ou avec un clic droit sur la liste des comptes.

**Le cycle** (recommence tout seul) :
1. Attend que le **lobby** soit chargé
2. Clique sur **Play**
3. Appuie sur **Z** (la touche marquée Z sur **ton** clavier, AZERTY compris, modifiable) jusqu'à ce que « Join Matchmaking » apparaisse
4. Clique sur **Find Match**
5. **Captcha** : la fenêtre passe devant avec un son et une notification, le curseur est dans la case. **C'est toi qui tapes le code** puis cliques **Submit**
6. Attend la fin de la partie (**sans limite de temps**), victoire ou défaite
7. Clique sur **Next**, puis fait les clics pour les récompenses (5 par défaut)
8. Clique sur **Return to lobby**, attend le chargement du lobby, et recommence

| Action | Comment |
|---|---|
| Choisir les fenêtres | Coche les fenêtres Roblox dans la liste (**Rafraîchir** si tu viens d'en ouvrir) |
| Retrouver une fenêtre | Sélectionne-la → **Montrer** |
| Vérifier que la macro voit bien l'écran | Sélectionne une fenêtre → **Tester la détection** : affiche ce qui est reconnu, et enregistre une capture `macro_capture.png` sur le Bureau |
| Nombre de clics de récompense | De 0 à 10 (5 par défaut) |
| Changer la touche | Case **Touche** : mets la lettre telle qu'elle est écrite sur ton clavier (Z par défaut) |
| Son du captcha | Case **Son quand un captcha arrive** |
| Démarrer | Bouton **Démarrer** |
| Arrêter | Bouton **Arrêter**, ou touche **F8** n'importe où |
| Suivre | Le tableau affiche l'état de chaque fenêtre et le nombre de parties finies. La ligne en orange attend un captcha |
| Fermer la fenêtre de la macro | La macro continue. Rouvre-la avec le lien ou l'icône ^ |

- **Plusieurs fenêtres** : chacune suit son propre cycle. Quand un captcha arrive, la macro ne touche plus aux autres fenêtres tant qu'il n'est pas rempli, pour ne pas te voler le clavier. S'il y a plusieurs captchas, ils arrivent un par un.
- **Anti-AFK** : il continue de tourner pendant les parties. La macro ajoute aussi un clic droit toutes les 12 min sans action. L'anti-AFK du launcher se met en pause pendant un captcha.
- La macro prend la souris et le clavier : évite d'utiliser le PC pendant qu'elle tourne.
- Ne réduis pas les fenêtres et garde des tailles proches de la normale. La détection supporte des fenêtres plus petites ou plus grandes.
- Si un bouton n'est pas reconnu, utilise **Tester la détection** et envoie le résultat avec la capture.

## 7. Arrière-plan et icône ^
| Action | Comment |
|---|---|
| Passer en arrière-plan | Bouton **Arrière-plan** : la fenêtre disparaît de la barre des tâches et va dans la zone ^ |
| Rouvrir | Clic gauche sur l'icône dans la zone ^ |
| Menu rapide | Clic droit sur l'icône : Ouvrir le launcher, Multi-instance activé, Fermer tous les Roblox, Économie, Paramètres, Macro Anime Adventures, Raccourcis, Quitter |
| Quitter vraiment | Croix de la fenêtre, ou clic droit sur l'icône ^ → **Quitter** |

## 8. Écran d'accueil (GIF / vidéo)
Le propriétaire du dépôt le choisit pour **tout le monde**, dans `splash.json` sur GitHub.

```json
{
  "enabled": true,
  "source": "lien OU nom d'un fichier du dépôt",
  "sound": true,
  "maxSeconds": 6
}
```

| Réglage | Effet |
|---|---|
| `enabled` | `true` = affiché, `false` = pas d'écran d'accueil |
| `source` | **N'importe quel lien** (Discord, Tenor, Giphy, lien direct `.gif` / `.mp4`) ou nom d'un fichier mis sur le dépôt (ex : `Viktor.mp4`) |
| `sound` | Son des vidéos : `true` ou `false` |
| `maxSeconds` | Durée max, de 1 à 30 s |

- L'écran d'accueil **ne peut pas être passé** (ni clic, ni Échap, ni Alt+F4).
- Un GIF joue une fois, une vidéo jusqu'au bout, et les deux s'arrêtent à `maxSeconds`.
- Le média est téléchargé une seule fois puis gardé sur le PC, donc ça marche hors ligne.
- **Robot GitHub** : dès que `splash.json` change, il télécharge le média du lien et en garde une copie dans `splash_media/` (avec `splash.lock.json`). Les liens Discord, qui expirent au bout d'environ 24 h, restent donc utilisables pour toujours. Il faut juste coller un lien **frais**, copié juste avant.
- Suivre le robot : onglet **Actions** du dépôt → « Copie de l'écran d'accueil ». Une coche verte veut dire que c'est copié, une croix rouge que le lien est cassé ou expiré : recopie-le.
- Si le nouveau média ne peut pas être téléchargé (lien cassé ou expiré), aucun écran d'accueil ne s'affiche. L'ancien n'est plus montré à la place.
- Le cache est vidé et re-téléchargé **une fois par jour**. Un fichier remplacé sur le dépôt sous le même nom apparaît donc au plus tard le lendemain. Avec un **nouveau nom**, c'est immédiat.

## 9. Mises à jour
| Action | Comment |
|---|---|
| Vérification automatique | Au démarrage, le message « Une mise à jour est disponible » → **Oui** pour installer |
| Vérifier à la main | Lien **Vérifier les mises à jour** en bas du launcher |
| Après la mise à jour | Le launcher redémarre tout seul. L'ancienne version est gardée dans `RobloxMulti.ps1.bak` |

## 10. Raccourcis et épinglage
| Action | Comment |
|---|---|
| Premier lancement | Une fenêtre propose : Bureau, menu Démarrer, barre des tâches |
| Refaire les raccourcis | Lien **Raccourcis / épingler** en bas, ou clic droit sur l'icône ^ |
| Épingler à la barre des tâches | Clic droit sur l'icône du launcher dans la barre des tâches → **Épingler à la barre des tâches** |
| Réparation automatique | Si tu déplaces le launcher, les raccourcis sont corrigés au démarrage suivant |

## 11. Lancement, logo et terminal
| Action | Comment |
|---|---|
| Lancer le launcher | `RobloxMulti.exe` (créé automatiquement, avec le logo), un raccourci, ou `Lancer RobloxMulti.bat` |
| Terminal | Aucune fenêtre PowerShell ne s'affiche |
| Logo | Affiché sur la fenêtre, dans la barre des tâches, dans la zone ^ et sur les raccourcis |

## 12. Fichiers et données
**Dans le dossier du launcher** (garde-les ensemble) :

| Fichier | Rôle |
|---|---|
| `RobloxMulti.ps1` | Le programme, **obligatoire** |
| `RobloxMulti.exe` | Lanceur avec logo, créé automatiquement |
| `Lancer RobloxMulti.bat` | Lanceur de secours, peut être supprimé si l'exe existe |
| `RobloxMulti.ps1.bak` | Sauvegarde de l'ancienne version, peut être supprimée |

**Dans `%APPDATA%\RobloxMulti`** (ne jamais partager ce dossier) :

| Fichier | Contenu |
|---|---|
| `accounts.json` | Sessions des comptes, chiffrées |
| `presets.json` | Presets de jeux (partageable) |
| `settings.json` | Dernier jeu lancé |
| `economy.json` | Niveau d'économie |
| `options.json` | Anti-AFK, limites, optimisation |
| `splash_state.json`, `splash_*` | Écran d'accueil en cache |
| `icon.ico` | Logo |

## 13. Historique des versions
| Version | Nouveautés |
|---|---|
| **2.0.1** | Macro : la touche Z suit la disposition du clavier (AZERTY), touche modifiable |
| 2.0.0 | Macro Anime Adventures : boucle lobby → Play → Z → Find Match → captcha (manuel) → partie → Next → récompenses → Return to lobby, sur plusieurs fenêtres |
| 1.9.0 | N'importe quel lien dans `source`, même Discord : un robot GitHub copie le média sur le dépôt pour qu'il n'expire jamais |
| 1.8.2 | Si le nouvel écran d'accueil ne se télécharge pas, l'ancien n'est plus affiché à la place |
| 1.8.1 | La croix d'un Roblox ferme vraiment son processus (détection de la fenêtre de jeu), compteur mis à jour tout de suite |
| 1.8.0 | Clic droit sur les comptes : lancer et disposer les fenêtres (grille, côte à côte, lignes, cascade), ranger les Roblox déjà ouverts |
| 1.7.1 | Écran d'accueil re-téléchargé chaque jour pour détecter un changement de vidéo |
| 1.7.0 | Anti-AFK, limites CPU / RAM, optimisation (mode efficacité, libération RAM), fenêtre Paramètres, écran d'accueil impossible à passer |
| 1.6.1 | Fermeture automatique des Roblox restés en arrière-plan après la croix |
| 1.6.0 | Mode Économie (4 niveaux) |
| 1.5.0 | Écran d'accueil choisi depuis GitHub (`splash.json`), message de mise à jour simplifié |
| 1.4.0 | Écran d'accueil GIF / vidéo |
| 1.3.1 | Réparation automatique des raccourcis |
| 1.3.0 | Raccourcis Bureau / menu Démarrer + épinglage |
| 1.2.0 | Plus aucun terminal visible, `RobloxMulti.exe`, logo dans la barre des tâches |
| 1.1.0 | Mode arrière-plan (icône ^), logo |
| 1.0.0 | Multi-instance, comptes, presets, mises à jour GitHub |
