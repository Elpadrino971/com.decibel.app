# DecibelPro — Sonomètre professionnel iOS

## Features

- **Mesure en temps réel** — Affichage du niveau sonore en décibels (dB) avec mise à jour continue via le microphone
- **Jauge circulaire animée** — Grande jauge arc avec aiguille animée style compteur professionnel, zones colorées (vert → jaune → orange → rouge)
- **Valeurs Min / Max / Moyenne** — Statistiques en direct affichées sous la jauge
- **Graphique temps réel** — Courbe de niveau sonore défilante en bas de l'écran principal
- **Historique des mesures** — Sauvegarde automatique de chaque session avec date, durée, valeurs min/max/moy
- **Export PDF Pro** — Génération de rapports PDF professionnels avec graphiques et données (achat in-app 1,99€)
- **Calibration** — Possibilité de calibrer le microphone avec un offset personnalisé
- **Zones de bruit** — Indicateur visuel de la zone de bruit actuelle (silence, conversation, rue, danger…) avec descriptions et risques pour l'audition
- **Notifications de seuil** — Alerte vibration + visuelle quand un seuil de décibels configuré est dépassé
- **Achat In-App** — Unlock complet à 3,99€ (historique illimité, calibration avancée) + Export PDF Pro à 1,99€

## Design

- **Dark Mode permanent** — Fond noir profond avec accents verts oscilloscope, style instrument de mesure pro
- **Jauge principale** — Arc de cercle ~270° avec gradient vert → jaune → rouge, aiguille fine animée avec spring, valeur dB en grand au centre (SF Pro, poids heavy)
- **Typographie** — SF Pro default avec poids variés (heavy pour les valeurs, semibold pour les labels, regular pour le secondaire)
- **Couleur d'accent verte** — Vert oscilloscope (#00FF88 / vert menthe) pour les éléments interactifs et l'aiguille
- **Matériaux** — Cartes en `.ultraThinMaterial` sur fond noir, séparateurs subtils
- **Animations** — Aiguille animée avec spring, courbe de niveau fluide, transitions douces entre écrans
- **Haptics** — Retour haptique quand un seuil est franchi
- **SF Symbols** — Icônes natives partout (waveform, mic, chart, doc)

## Écrans

1. **Écran principal (Sonomètre)** — Jauge circulaire animée, valeur dB centrale, min/max/moy, zone de bruit, mini-graphique temps réel, bouton start/stop
2. **Historique** — Liste des sessions passées avec date, durée, niveau moyen, swipe pour supprimer
3. **Détail session** — Graphique complet de la session, toutes les statistiques, bouton export PDF
4. **Réglages** — Calibration microphone, seuil d'alerte, unité de mesure, gestion des achats in-app, restauration d'achats
5. **Paywall** — Écran d'achat élégant présentant les deux options (unlock complet + export PDF)

## Icône de l'app

- Fond noir/gris très sombre avec une jauge arc verte lumineuse stylisée et une aiguille, style instrument de mesure premium — icône minimaliste et professionnelle
