-- ============================================================
--  BASE 04 — BANQUE PERSONNELLE
--  Niveau : avancé (dates, cumuls, pivot, opérations ensemblistes)
--  Schéma : clients / comptes / categories / transactions
--  Particularités : montants signés (+ crédit / − débit),
--                   arbre de catégories sur 3 niveaux,
--                   catégories NULL, compte sans transaction
-- ============================================================


-- ------------------------------------------------------------
-- NIVEAU A — Échauffement
-- ------------------------------------------------------------

-- 1. Nombre de comptes par client, y compris ceux à 0.
SELECT cl.nom, COUNT(c.id) AS nb_comptes
FROM clients cl
LEFT JOIN comptes c ON cl.id = c.client_id
GROUP BY cl.id, cl.nom;


-- 2. Nombre de transactions par compte.
-- JOIN vers clients (obligatoire) + LEFT JOIN vers transactions (préservation).
SELECT c.id, cl.nom, c.type, COUNT(t.id) AS nb_transactions
FROM comptes c
JOIN clients cl          ON cl.id = c.client_id
LEFT JOIN transactions t ON t.compte_id = c.id
GROUP BY c.id;


-- 3. Entrées et sorties d'un compte, sur une seule ligne.
-- SUM(CASE ...) : transforme une condition de ligne en valeur de groupe.
SELECT SUM(CASE WHEN montant > 0 THEN montant ELSE 0 END) AS total_entrees,
       SUM(CASE WHEN montant < 0 THEN montant ELSE 0 END) AS total_sorties
FROM transactions
WHERE compte_id = 1;


-- ------------------------------------------------------------
-- NIVEAU B — Dates et périodes
-- ------------------------------------------------------------

-- 4. Nombre de transactions par mois.
-- strftime('%Y-%m', d) produit '2025-03' : format qui se trie
-- correctement en ordre alphabétique (année avant mois).
SELECT strftime('%Y-%m', date_operation) AS mois,
       COUNT(id) AS nb_transactions
FROM transactions
GROUP BY mois
ORDER BY mois;


-- 5. Solde net mensuel d'un compte.
SELECT strftime('%Y-%m', date_operation) AS mois,
       SUM(montant) AS solde_net
FROM transactions
WHERE compte_id = 1
GROUP BY mois
ORDER BY mois;


-- 6. Dépenses mensuelles en valeur absolue.
SELECT strftime('%Y-%m', date_operation) AS mois,
       SUM(ABS(montant)) AS total_depenses
FROM transactions
WHERE montant < 0
GROUP BY mois
ORDER BY mois;


-- ------------------------------------------------------------
-- NIVEAU C — Cumuls et comparaisons temporelles
-- ------------------------------------------------------------

-- 7. Solde cumulé après chaque opération.
-- Un ORDER BY DANS le OVER change la fenêtre : au lieu de sommer
-- tout le groupe, SQL somme du début jusqu'à la ligne courante.
SELECT t.date_operation, t.libelle, t.montant,
       c.solde_initial + SUM(t.montant) OVER (ORDER BY t.date_operation, t.id) AS solde_cumule
FROM transactions t
JOIN comptes c ON c.id = t.compte_id
WHERE t.compte_id = 1
ORDER BY t.date_operation;


-- 8. Variation du total mensuel par rapport au mois précédent (LAG).
-- La CTE évite de répéter l'agrégat à l'intérieur du OVER.
WITH mensuel AS (
    SELECT strftime('%Y-%m', date_operation) AS mois,
           SUM(montant) AS total
    FROM transactions
    WHERE compte_id = 1
    GROUP BY mois
)
SELECT mois, total,
       total - LAG(total) OVER (ORDER BY mois) AS variation
FROM mensuel
ORDER BY mois;


-- 9. Même chose, en pourcentage.
-- Formule d'une variation : (nouveau − ancien) / ancien × 100.
-- Un mois identique au précédent doit donner 0, pas 100.
WITH mensuel AS (
    SELECT strftime('%Y-%m', date_operation) AS mois,
           SUM(montant) AS total
    FROM transactions
    WHERE compte_id = 1
    GROUP BY mois
)
SELECT mois, total,
       ROUND((total - LAG(total) OVER (ORDER BY mois)) * 100.0
             / LAG(total) OVER (ORDER BY mois), 2) AS variation_pct
FROM mensuel
ORDER BY mois;


-- 10. Moyenne glissante sur 3 transactions.
-- ROWS BETWEEN définit explicitement le cadre de la fenêtre.
SELECT date_operation, libelle, montant,
       AVG(montant) OVER (ORDER BY date_operation, id
                          ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moyenne_glissante
FROM transactions
WHERE compte_id = 1
ORDER BY date_operation;


-- ------------------------------------------------------------
-- NIVEAU D — Arbre de catégories
-- ------------------------------------------------------------

-- 11. Chaque catégorie avec son parent (self-join).
-- La table de gauche est celle dont on veut TOUTES les lignes.
-- La condition part de la clé étrangère vers l'id : c.parent_id = p.id.
SELECT c.nom AS categorie, p.nom AS parent
FROM categories c
LEFT JOIN categories p ON c.parent_id = p.id;


-- 12. Descendance d'une catégorie précise, avec la profondeur.
WITH RECURSIVE hierarchie AS (
    SELECT id, nom, 0 AS niveau
    FROM categories
    WHERE nom = 'Dépenses'

    UNION ALL

    SELECT c.id, c.nom, h.niveau + 1
    FROM categories c
    JOIN hierarchie h ON c.parent_id = h.id
)
SELECT nom, niveau
FROM hierarchie
ORDER BY niveau, nom;


-- 13. Chaque transaction avec sa catégorie ET sa catégorie racine.
-- Technique : transporter la racine pendant la descente.
-- Dans le cas de base, chaque racine est sa propre racine ; dans la
-- partie récursive, l'enfant recopie la racine de son parent (a.racine).
WITH RECURSIVE arbre AS (
    SELECT id, nom, nom AS racine
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.id, c.nom, a.racine
    FROM categories c
    JOIN arbre a ON c.parent_id = a.id
)
SELECT t.id, t.libelle, a.nom AS categorie, a.racine
FROM transactions t
LEFT JOIN arbre a ON a.id = t.categorie_id
ORDER BY t.id;
-- Contrôle : 55 lignes attendues (= nombre de transactions).
-- Plus de lignes que la table de départ = duplication par jointure.


-- ------------------------------------------------------------
-- NIVEAU E — Classements et segmentation
-- ------------------------------------------------------------

-- 14. Segmentation des clients en quartiles de revenus.
-- NTILE(n) répartit les lignes triées en n paquets de taille égale.
-- Contrairement à RANK (position individuelle), il donne une appartenance.
WITH revenus AS (
    SELECT cl.nom,
           SUM(CASE WHEN t.montant > 0 THEN t.montant ELSE 0 END) AS total_revenus
    FROM clients cl
    LEFT JOIN comptes c      ON cl.id = c.client_id
    LEFT JOIN transactions t ON t.compte_id = c.id
    GROUP BY cl.id, cl.nom
)
SELECT NTILE(4) OVER (ORDER BY total_revenus DESC) AS quartile,
       nom, total_revenus
FROM revenus
ORDER BY quartile;


-- 15. Plus grosse dépense de chaque compte.
WITH classement AS (
    SELECT compte_id, id AS transaction_id, montant, libelle, date_operation,
           RANK() OVER (PARTITION BY compte_id ORDER BY montant ASC) AS rang
    FROM transactions
    WHERE montant < 0
)
SELECT compte_id, libelle, montant, date_operation
FROM classement
WHERE rang = 1;


-- 16. Part de chaque catégorie dans le total des dépenses.
-- SUM(x) OVER () : fenêtre vide = total général sur toutes les lignes,
-- reporté à côté de chaque ligne. Motif standard pour un calcul de part.
WITH depenses AS (
    SELECT c.nom, SUM(ABS(t.montant)) AS total
    FROM transactions t
    JOIN categories c ON c.id = t.categorie_id
    WHERE t.montant < 0
    GROUP BY c.id, c.nom
)
SELECT nom, total,
       ROUND(total * 100.0 / SUM(total) OVER (), 2) AS part_pct
FROM depenses
ORDER BY part_pct DESC;


-- ------------------------------------------------------------
-- NIVEAU F — Ensembles et corrélations
-- ------------------------------------------------------------

-- 17. Catégories utilisées par le compte 1 mais pas par le compte 3.
-- EXCEPT dédoublonne automatiquement.
SELECT c.nom
FROM categories c
JOIN transactions t ON t.categorie_id = c.id
WHERE t.compte_id = 1

EXCEPT

SELECT c.nom
FROM categories c
JOIN transactions t ON t.categorie_id = c.id
WHERE t.compte_id = 3;


-- 18. Catégories communes aux deux comptes.
SELECT c.nom
FROM categories c
JOIN transactions t ON t.categorie_id = c.id
WHERE t.compte_id = 1

INTERSECT

SELECT c.nom
FROM categories c
JOIN transactions t ON t.categorie_id = c.id
WHERE t.compte_id = 3;


-- 19. Transactions au-dessus de la moyenne DE LEUR PROPRE COMPTE.
-- Version fenêtre : une seule passe (préférable).
WITH base AS (
    SELECT id, compte_id, montant,
           AVG(montant) OVER (PARTITION BY compte_id) AS moyenne_compte
    FROM transactions
)
SELECT id, compte_id, montant, ROUND(moyenne_compte, 2) AS moyenne_compte
FROM base
WHERE montant > moyenne_compte;   -- comparaison sur la valeur non arrondie

-- 19 bis. Version sous-requête corrélée (recalculée pour chaque ligne).
SELECT t.id, t.compte_id, t.montant
FROM transactions t
WHERE t.montant > (
    SELECT AVG(t2.montant)
    FROM transactions t2
    WHERE t2.compte_id = t.compte_id     -- le lien avec la ligne courante
);


-- 20. Tableau croisé : une ligne par catégorie, une colonne par mois.
-- Pivot manuel : les colonnes s'écrivent en dur, SQL standard ne sait
-- pas les générer dynamiquement.
-- Le filtre est dans le ON (et non le WHERE) pour ne pas neutraliser
-- le LEFT JOIN : une condition sur la table de droite placée dans le
-- WHERE transforme un LEFT JOIN en JOIN interne.
SELECT c.nom,
       SUM(CASE WHEN strftime('%Y-%m', t.date_operation) = '2025-01' THEN ABS(t.montant) ELSE 0 END) AS janvier,
       SUM(CASE WHEN strftime('%Y-%m', t.date_operation) = '2025-02' THEN ABS(t.montant) ELSE 0 END) AS fevrier,
       SUM(CASE WHEN strftime('%Y-%m', t.date_operation) = '2025-03' THEN ABS(t.montant) ELSE 0 END) AS mars,
       SUM(CASE WHEN strftime('%Y-%m', t.date_operation) = '2025-04' THEN ABS(t.montant) ELSE 0 END) AS avril,
       SUM(CASE WHEN strftime('%Y-%m', t.date_operation) = '2025-05' THEN ABS(t.montant) ELSE 0 END) AS mai,
       SUM(CASE WHEN strftime('%Y-%m', t.date_operation) = '2025-06' THEN ABS(t.montant) ELSE 0 END) AS juin
FROM categories c
LEFT JOIN transactions t ON c.id = t.categorie_id AND t.montant < 0
GROUP BY c.id, c.nom;
