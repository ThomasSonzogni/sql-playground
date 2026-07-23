# SQL — bases d'entraînement et requêtes

Cinq bases de données conçues autour de difficultés progressives, et les
requêtes écrites pour les résoudre. Chaque base isole une famille de problèmes :
préservation des lignes lors des jointures, valeurs nulles, hiérarchies
auto-référencées, séries temporelles, données semi-structurées.

Le dépôt sert de support de révision : les requêtes sont commentées avec le
raisonnement suivi et les pièges évités, pas seulement le résultat.

**Moteur** : SQLite. Les scripts tournent sans installation sur
[sqliteonline.com](https://sqliteonline.com) ou
[extendsclass.com/sqlite-browser.html](https://extendsclass.com/sqlite-browser.html).

---

## Structure

```
.
├── README.md              ← ce fichier
├── NOTES.md               ← mémo des notions et pièges rencontrés
├── schemas/               ← scripts DROP + CREATE + INSERT, relançables
│   ├── 01_boutique.sql
│   ├── 02_ecole.sql
│   ├── 03_entreprise.sql
│   ├── 04_banque.sql
│   └── 05_recrutement.sql
└── queries/               ← les requêtes, commentées
    ├── 01_boutique.sql
    ├── 02_ecole.sql
    ├── 03_entreprise.sql
    ├── 04_banque.sql
    └── 05_recrutement.sql
```

**Utilisation** : coller le contenu d'un fichier de `schemas/` dans l'éditeur
et l'exécuter (chaque script commence par des `DROP TABLE IF EXISTS`, il est
donc relançable à volonté), puis exécuter les requêtes une à une.

---

## Les cinq bases

### 01 — Boutique en ligne
`clients` · `produits` · `commandes` · `lignes_commande`

Modèle relationnel classique à quatre tables avec une table de liaison.
Fondamentaux : filtres, agrégation, jointures multiples, premières fonctions
fenêtre.

Cas limites intégrés : clients sans commande, commandes annulées à exclure
des calculs de chiffre d'affaires.

### 02 — École
`etudiants` · `professeurs` · `cours` · `inscriptions`

Centré sur les valeurs nulles et les anti-jointures.

Cas limites : notes non renseignées (`NULL`) traversant les calculs de
moyenne, étudiant inscrit à aucun cours, cours sans aucun inscrit.

### 03 — Entreprise
`departements` · `employes` · `projets` · `affectations`

`employes.manager_id` référence `employes.id` : la table est auto-référencée,
ce qui ouvre le self-join et le parcours récursif d'un organigramme.

Cas limites : département sans employé, projet sans affectation, salaires
ex æquo pour distinguer `RANK` de `DENSE_RANK`.

### 04 — Banque personnelle
`clients` · `comptes` · `categories` · `transactions`

Séries temporelles sur six mois et arbre de catégories sur trois niveaux.
Montants signés (positif = crédit, négatif = débit).

Cas limites : transactions non catégorisées (`NULL`), compte sans opération,
catégories intermédiaires sans transaction directe.

### 05 — Plateforme de recrutement
`entreprises` · `candidats` · `offres` · `candidatures`

Compétences stockées en listes JSON, ce qui impose de les éclater pour
raisonner dessus. Permet de construire un moteur de matching entre profils
et offres.

Cas limites : candidat à liste de compétences vide, candidats sans
candidature, offre sans candidature.

---

## Index des techniques

| Technique | Où la voir |
|---|---|
| Agrégation, `GROUP BY`, `HAVING` | `01` #5-8, `05` #1-7 |
| `WHERE` vs `HAVING` (comparatif commenté) | `05` #1-7 |
| Jointures multiples | `01` #9-11, `02` #7-9 |
| Anti-jointures (`LEFT JOIN`/`IS NULL` et `NOT EXISTS`) | `01` #12, `02` #10-11, `05` #19 |
| Préservation des zéros (`LEFT JOIN` + `COALESCE`) | `03` #1-2, `04` #1-2, `05` #17-18 |
| Sous-requête scalaire | `03` #3-4 |
| Sous-requête corrélée | `04` #19bis, `05` #19 |
| Self-join (hiérarchie, arbre) | `03` #5, `04` #11 |
| `CASE` simple et scoring de valeurs textuelles | `01` #16, `02` #12, `05` #17 |
| `RANK`, `ROW_NUMBER`, `DENSE_RANK` | `02` #13-14, `03` #6, `04` #15 |
| Motif « meilleure ligne par groupe » | `01` #14, `02` #14, `04` #15, `05` #14 |
| Agrégat en mode fenêtre (`AVG OVER`, `SUM OVER ()`) | `03` #7, `04` #16, `04` #19 |
| Total cumulé et moyenne glissante (`ROWS BETWEEN`) | `04` #7, #10 |
| `LAG` / `LEAD`, variations période sur période | `03` #8, `04` #8-9 |
| `NTILE`, segmentation en quartiles | `04` #14 |
| Fonctions de date (`strftime`), agrégation par mois | `04` #4-6 |
| CTE simple | `03` #9 |
| CTE en cascade (jusqu'à 6 blocs) | `05` #16-18, #20 |
| CTE récursive — descente, remontée, chemin | `03` #10-12, `04` #12-13 |
| Opérations ensemblistes (`EXCEPT`, `INTERSECT`) | `04` #17-18, `05` #15 |
| Éclatement de listes JSON (`json_each` / `unnest`) | `05` #8-15 |
| Pivot manuel (tableau croisé) | `04` #20 |

---

## Quelques points de méthode

Détaillés dans [NOTES.md](NOTES.md), avec les erreurs qui les ont motivés.

- **L'ordre d'exécution** (`FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY`)
  explique la plupart des messages d'erreur : pourquoi `WHERE` ne voit pas un
  alias de fonction fenêtre, pourquoi `HAVING` ne peut pas filtrer sur une
  colonne hors du regroupement.
- **Ce qui doit apparaître dans le résultat doit être présent dès la première
  étape.** Une ligne éliminée par une jointure interne ne se récupère pas en
  aval, quel que soit le nombre de `LEFT JOIN` ajoutés ensuite.
- **Une condition sur la table de droite placée dans le `WHERE` annule un
  `LEFT JOIN`.** Elle doit aller dans le `ON`.
- **Multiplier avant de diviser**, et écrire `100.0` : `(a / b) * 100.0`
  renvoie 0 sur des entiers.
- **Construire par couches**, en exécutant après chaque ajout, plutôt que
  d'écrire la requête entière d'un trait. Visualiser le résultat intermédiaire
  d'un `ROW_NUMBER()` avant de le filtrer.
- **Vérifier le nombre de lignes** : plus de lignes que la table de départ
  signale une duplication par jointure.
- **Tester les requêtes « négatives »** en créant temporairement le cas
  positif : un résultat vide ne prouve pas que la requête est correcte.
