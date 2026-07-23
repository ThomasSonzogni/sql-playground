# Mémo — notions clés et pièges

Fiche de synthèse rédigée au fil des exercices. Chaque point correspond à une
erreur réellement rencontrée et corrigée, pas à une liste théorique recopiée.

---

## 1. Ordre d'exécution d'une requête

L'ordre d'écriture n'est pas l'ordre d'exécution. Presque tous les pièges
qui suivent découlent de cette différence.

```
FROM / JOIN  →  WHERE  →  GROUP BY  →  HAVING  →  SELECT  →  ORDER BY  →  LIMIT
```

Conséquences directes :

- `WHERE` ne peut pas utiliser d'agrégat (les groupes n'existent pas encore).
- `WHERE` ne peut pas utiliser une colonne calculée par une fonction fenêtre
  (`WHERE rn = 1` échoue systématiquement) → il faut une sous-requête ou une CTE.
- `HAVING` ne peut pas utiliser une colonne hors du `GROUP BY` (les lignes
  individuelles ont disparu).

## 2. WHERE contre HAVING

| | `WHERE` | `HAVING` |
|---|---|---|
| Filtre | des **lignes** | des **groupes** |
| Moment | avant `GROUP BY` | après `GROUP BY` |
| Agrégat | interdit | c'est son rôle |

**Règle de décision** : si la condition s'écrit sans fonction d'agrégation,
elle appartient au `WHERE`.

Quand les deux fonctionnent, `WHERE` est préférable : il réduit le volume
avant regroupement.

Écrire `HAVING statut = 'acceptée'` est une erreur classique : un groupe
contient plusieurs statuts, la condition n'a donc pas de valeur définie.
PostgreSQL rejette la requête ; SQLite pioche une ligne au hasard et renvoie
un résultat instable.

## 3. GROUP BY

- **Pas d'agrégat dans le `SELECT` → pas de `GROUP BY`.** Un `GROUP BY`
  superflu ne sert à rien au mieux, écrase des lignes au pire.
- Toute colonne du `SELECT` doit être soit dans le `GROUP BY`, soit dans un
  agrégat. SQLite tolère les colonnes nues (et affiche une valeur arbitraire) ;
  les autres moteurs refusent.
- Grouper sur l'`id` plutôt que sur le `nom` : robuste aux homonymes.

## 4. Le piège du « max par groupe »

`SELECT nom, MAX(budget) FROM projets` affiche un `nom` sans rapport avec le
budget maximal. Trois solutions correctes :

```sql
-- a) sous-requête : renvoie tous les ex æquo
WHERE budget = (SELECT MAX(budget) FROM projets)

-- b) ORDER BY + LIMIT : une seule ligne, arbitraire en cas d'égalité
ORDER BY budget DESC LIMIT 1

-- c) fonction fenêtre : le motif général, extensible par groupe
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY g ORDER BY x DESC) AS rn
    FROM t
) WHERE rn = 1
```

## 5. Jointures et préservation des lignes

**Principe transversal : ce qui doit apparaître dans le résultat doit être
présent dès la première étape.** On ne ressuscite pas en aval ce qui a été
éliminé en amont.

- La table de gauche d'un `LEFT JOIN` est celle dont on veut toutes les lignes.
- La condition part de la clé étrangère vers l'id (`c.parent_id = p.id`),
  jamais l'inverse.
- **Une condition sur la table de droite placée dans le `WHERE` annule le
  `LEFT JOIN`** (car `NULL < 0` est faux). Il faut la déplacer dans le `ON`.
- `COUNT(colonne)` ignore les NULL, `COUNT(*)` non : après un `LEFT JOIN`
  sans correspondance, seul `COUNT(colonne)` renvoie 0.
- `SUM` sur un ensemble vide renvoie `NULL`, pas 0 → `COALESCE(SUM(x), 0)`.
- Contrôle systématique : **si le résultat contient plus de lignes que la
  table de départ, il y a duplication par jointure.**

## 6. Anti-jointures (chercher une absence)

Deux écritures équivalentes :

```sql
-- LEFT JOIN + IS NULL
FROM a LEFT JOIN b ON b.a_id = a.id WHERE b.id IS NULL

-- NOT EXISTS
FROM a WHERE NOT EXISTS (SELECT 1 FROM b WHERE b.a_id = a.id)
```

**Une jointure ne produit que des paires qui se ressemblent.** Pour trouver
des paires sans recoupement, on ne les fabrique pas par jointure : on part de
l'ensemble complet et on retranche.

`EXCEPT` et `INTERSECT` couvrent les cas simples et dédoublonnent d'office.
Contrainte : mêmes colonnes, même ordre, types compatibles.

## 7. Agrégat contre fonction fenêtre

| | agrégat | fonction fenêtre |
|---|---|---|
| Lignes en sortie | fusionnées | conservées |
| Syntaxe | `SUM(x) ... GROUP BY g` | `SUM(x) OVER (PARTITION BY g)` |

Les trois réglages de `OVER` :

| Écriture | Fenêtre | Usage |
|---|---|---|
| `OVER ()` | tout le résultat | total général reporté sur chaque ligne (calcul de part) |
| `OVER (PARTITION BY g)` | tout, par groupe | comparer une ligne à son groupe |
| `OVER (ORDER BY d)` | du début à la ligne courante | total cumulé |
| `OVER (ORDER BY d ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` | cadre glissant | moyenne mobile |

**On partitionne sur ce qui suit « pour chaque… » dans l'énoncé.** Partitionner
trop finement isole chaque ligne et rend le classement vide de sens.

`RANK`, `ROW_NUMBER`, `NTILE`, `LAG`, `LEAD` exigent un `ORDER BY` dans le
`OVER`. Seuls les agrégats-fenêtres peuvent s'en passer.

Sur des valeurs 90, 90, 80 :

| Fonction | Résultat |
|---|---|
| `ROW_NUMBER()` | 1, 2, 3 |
| `RANK()` | 1, 1, 3 (saute) |
| `DENSE_RANK()` | 1, 1, 2 (ne saute pas) |
| `NTILE(n)` | appartenance à l'un des n paquets |

Choix conscient : `RANK` pour afficher tous les ex æquo, `ROW_NUMBER` pour
garantir une seule ligne par groupe.

## 8. CTE

Plusieurs CTE se déclarent après un seul `WITH`, séparées par des virgules ;
chacune peut lire les précédentes.

Avantages : un bloc = une étape testable isolément, et un agrégat devient
une colonne ordinaire à l'étage suivant (donc filtrable au `WHERE`).

- Ne jamais nommer une CTE comme une table existante.
- Un `ORDER BY` à l'intérieur d'une CTE est du bruit : l'ordre n'y est pas
  garanti et sera refait à l'étage suivant.
- Deux CTE ayant le même `FROM` et le même `GROUP BY` peuvent fusionner.

## 9. CTE récursives

Structure invariable :

```sql
WITH RECURSIVE t AS (
    SELECT ...            -- cas de base : point de départ, exécuté une fois
    UNION ALL
    SELECT ... FROM table JOIN t ON ...   -- se réfère à t : c'est la boucle
)
```

Fonctionnement en boule de neige : à chaque tour on ajoute les éléments
rattachés à ceux déjà trouvés, jusqu'à ce qu'il n'y ait plus rien à ajouter.

**Le sens du parcours est entièrement contenu dans la condition de jointure :**

| Condition | Sens |
|---|---|
| `e.manager_id = h.id` | descendre (les subordonnés) |
| `e.id = h.manager_id` | remonter (le manager) |

Le compteur `niveau + 1` n'est qu'une étiquette et ne change pas le parcours.

Le cas de base délimite le périmètre : `WHERE manager_id IS NULL` part de la
racine sans id en dur (et gère plusieurs racines) ; `WHERE nom = 'X'` cible
une branche précise.

On peut transporter une valeur pendant la descente : recopier `a.racine`
propage la racine à toute la branche, concaténer `h.chemin || ' > ' || e.nom`
construit un chemin complet.

## 10. Arithmétique et NULL

- **Toujours multiplier avant de diviser, et écrire `100.0`.** `(a / b) * 100.0`
  effectue une division entière : `2 / 5` vaut 0. Écrire `a * 100.0 / b`.
- Division par zéro : `NULL` en SQLite (pas d'erreur) → `COALESCE(..., 0)`.
- `AVG` ignore les `NULL` : il divise par le nombre de valeurs présentes.
  Un groupe entièrement `NULL` renvoie `NULL`.
- `IS NULL`, jamais `= NULL` : rien n'est égal à `NULL`, pas même `NULL`.
- Arrondir à l'affichage, pas dans le calcul : comparer une valeur à une
  moyenne arrondie fausse les cas limites.
- `SUM(CASE WHEN c THEN 1 ELSE 0 END)` compte les vrais.
  `COUNT(CASE WHEN c THEN 1 ELSE 0 END)` compte **tout** (0 est non-NULL).

## 11. CASE

Un seul `CASE`, un seul `END`, autant de `WHEN` que nécessaire — **sans
virgules entre eux** (la virgule sépare des colonnes, pas des `WHEN`).

Les conditions sont évaluées dans l'ordre et l'évaluation s'arrête à la
première vraie : inutile de borner par le haut (`WHEN prix >= 100` après
`WHEN prix > 500` implique déjà `<= 500`).

Usage clé : les valeurs textuelles n'ont pas d'ordre métier. Un statut se
convertit en score numérique, on prend le `MAX`, puis on retraduit.

## 12. Dates (SQLite)

`strftime('%Y-%m', d)` produit `'2025-03'`. Ce format se trie correctement en
ordre alphabétique — raison pour laquelle l'année précède le mois. Avec
`'%m-%Y'`, le tri serait chronologiquement faux.

## 13. Éclatement de listes

| Moteur | Écriture |
|---|---|
| SQLite | `FROM t, json_each(t.col) j` → `j.value` |
| PostgreSQL | `FROM t, unnest(t.col) AS v` |
| BigQuery | `FROM t, UNNEST(t.col) AS v` |

La virgule est une jointure interne : une liste vide produit zéro ligne et
la ligne disparaît. Pour la conserver : `LEFT JOIN json_each(...) ON 1=1`,
ou `json_array_length()` quand seul le compte importe.

**Ne jamais parser une donnée structurée comme du texte.** `LIKE '%SQL%'`
remonte `PostgreSQL`, `NoSQL` et `MySQL`, dépend de la casse selon le moteur,
et casse si la structure JSON change.

## 14. Pivot

SQL standard ne génère pas de colonnes dynamiquement : on les écrit en dur,
une par valeur attendue.

```sql
SUM(CASE WHEN periode = '2025-01' THEN x ELSE 0 END) AS janvier
```

Le `ELSE 0` évite des `NULL` dans le tableau. Certains moteurs (SQL Server,
Oracle) proposent une clause `PIVOT` dédiée ; SQLite et PostgreSQL non.

## 15. Méthode de construction

Ne jamais écrire une requête complexe d'un seul jet. Construire par couches,
dans l'ordre d'exécution, en lançant après chaque ajout :

1. `FROM` / `JOIN` — quelles tables, comment les relier
2. `WHERE` — quelles lignes écarter
3. `GROUP BY` / fonctions fenêtre — vérifier visuellement la numérotation
   ou le regroupement avant d'aller plus loin
4. emballer et filtrer (`WHERE rn = 1`)
5. `ORDER BY`, mise en forme

Pour valider une requête censée détecter une anomalie, **créer temporairement
l'anomalie** : un résultat vide ne prouve rien.

Avant d'écrire : formuler « je compte **quoi**, groupé par **quoi** ». La
majorité des erreurs restantes viennent d'une lecture d'énoncé trop rapide,
pas de la syntaxe.
