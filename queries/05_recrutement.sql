-- ============================================================
--  BASE 05 — PLATEFORME DE RECRUTEMENT
--  Niveau : avancé+ (WHERE vs HAVING, éclatement de listes, CTE en cascade)
--  Schéma : entreprises / candidats / offres / candidatures
--  Particularités : compétences stockées en listes JSON,
--                   candidat sans compétence, candidats sans candidature,
--                   offre sans candidature
-- ============================================================


-- ############################################################
--  PARTIE 1 — WHERE contre HAVING
-- ############################################################
--
--  WHERE  : filtre des LIGNES, avant le GROUP BY, jamais d'agrégat.
--  HAVING : filtre des GROUPES, après le GROUP BY, sur un agrégat.
--  Ordre d'exécution : FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY
--  Quand les deux sont possibles, WHERE est préférable (moins de lignes
--  à regrouper).
--
--  Règle de décision : si la condition peut s'écrire sans fonction
--  d'agrégation, elle appartient au WHERE.
-- ############################################################


-- 1. Candidats ayant postulé plus de 2 fois — version HAVING.
SELECT cd.id, COUNT(c.id) AS nb_candidatures
FROM candidats cd
JOIN candidatures c ON c.candidat_id = cd.id
GROUP BY cd.id
HAVING COUNT(c.id) > 2;

-- 1 bis. Même résultat via une CTE : l'agrégat devient une colonne
-- ordinaire à l'étage suivant, donc filtrable au WHERE.
WITH candidature AS (
    SELECT cd.id, COUNT(c.id) AS nb_candidatures
    FROM candidats cd
    JOIN candidatures c ON c.candidat_id = cd.id
    GROUP BY cd.id
)
SELECT id, nb_candidatures
FROM candidature
WHERE nb_candidatures > 2;


-- 2. Candidatures acceptées ou en entretien, par candidat.
-- Le statut est une propriété de chaque LIGNE → WHERE.
-- Avec HAVING, un groupe contiendrait plusieurs statuts différents :
-- la condition n'aurait pas de valeur définie, et le COUNT porterait
-- sur toutes les candidatures du candidat, pas seulement les retenues.
SELECT candidat_id, COUNT(id) AS nb_retenues
FROM candidatures
WHERE statut IN ('acceptée', 'entretien')
GROUP BY candidat_id;


-- 3. Villes comptant au moins 3 candidats.
-- L'entité comptée est le candidat : c'est `candidats.ville` qui compte,
-- pas la ville des offres.
SELECT ville, COUNT(id) AS nb_candidats
FROM candidats
GROUP BY ville
HAVING COUNT(id) >= 3;


-- 4. Villes comptant au moins 2 candidats de plus de 3 ans d'expérience.
-- Les deux clauses coopèrent :
--   WHERE  écarte les candidats juniors (critère de ligne)
--   HAVING écarte les villes trop peu peuplées (critère de groupe)
SELECT ville, COUNT(id) AS nb_candidats
FROM candidats
WHERE annees_exp > 3
GROUP BY ville
HAVING COUNT(id) >= 2;


-- 5. Offres ayant reçu au moins 4 candidatures.
SELECT o.id, COUNT(c.candidat_id) AS nb_candidatures
FROM offres o
JOIN candidatures c ON o.id = c.offre_id
GROUP BY o.id
HAVING COUNT(c.candidat_id) >= 4;


-- 6. Villes dont la moyenne d'expérience dépasse 3 ans.
-- AVG est un agrégat → HAVING obligatoire.
SELECT ville, COUNT(id) AS nb_candidats
FROM candidats
GROUP BY ville
HAVING AVG(annees_exp) > 3;


-- 7. Comparatif sur une même question (candidatures de 2025).
-- Version WHERE — recommandée : filtre en amont, résultat non ambigu.
SELECT candidat_id, COUNT(id) AS nb_candidatures
FROM candidatures
WHERE strftime('%Y', date_candidature) = '2025'
GROUP BY candidat_id;

-- Version HAVING — valide uniquement si l'année est une clé de groupe,
-- sinon un groupe mélangerait plusieurs années. Correcte mais plus
-- coûteuse : elle construit tous les groupes puis en jette la plupart.
SELECT candidat_id,
       strftime('%Y', date_candidature) AS annee,
       COUNT(id) AS nb_candidatures
FROM candidatures
GROUP BY candidat_id, annee
HAVING annee = '2025';


-- ############################################################
--  PARTIE 2 — Éclatement de listes (unnest)
-- ############################################################
--
--  Passer d'une ligne contenant N valeurs à N lignes.
--  Équivalences entre moteurs :
--    SQLite      FROM t, json_each(t.col) j        → j.value
--    PostgreSQL  FROM t, unnest(t.col) AS v
--    BigQuery    FROM t, UNNEST(t.col) AS v
--
--  json_each est une fonction table : appelée une fois par ligne de la
--  table de gauche, avec la valeur de cette ligne.
-- ############################################################


-- 8. Une ligne par (candidat, compétence).
SELECT c.nom, j.value AS competence
FROM candidats c, json_each(c.competences) AS j;


-- 9. Compétences les plus répandues.
WITH competences AS (
    SELECT c.nom, j.value AS competence
    FROM candidats c, json_each(c.competences) AS j
)
SELECT competence, COUNT(nom) AS nb_candidats
FROM competences
GROUP BY competence
ORDER BY nb_candidats DESC;


-- 10. Nombre de compétences par candidat, y compris liste vide.
-- Version directe, sans éclatement.
SELECT nom, json_array_length(competences) AS nb_competences
FROM candidats;

-- 10 bis. Version avec éclatement préservant les listes vides.
-- La virgule entre deux tables est une jointure INTERNE : un candidat
-- à liste vide produit zéro ligne et disparaît dès cette étape.
-- Le LEFT JOIN ... ON 1=1 le conserve (la liaison est déjà assurée par
-- l'argument passé à json_each ; la condition est donc toujours vraie).
WITH competences AS (
    SELECT c.nom, j.value AS competence
    FROM candidats c
    LEFT JOIN json_each(c.competences) AS j ON 1=1
)
SELECT nom, COUNT(competence) AS nb_competences
FROM competences
GROUP BY nom;
-- COUNT(competence) et non COUNT(*) : la ligne NULL ne doit pas compter.


-- 11. Candidats maîtrisant SQL — version structurée.
SELECT c.nom
FROM candidats c, json_each(c.competences) AS j
WHERE j.value = 'SQL';

-- 11 bis. Version LIKE — fragile, à ne pas utiliser :
--   • cherche une sous-chaîne, pas un élément : 'PostgreSQL', 'NoSQL'
--     et 'MySQL' remontent comme faux positifs ;
--   • sensibilité à la casse variable selon le moteur (LIKE en SQLite,
--     ILIKE en PostgreSQL) ;
--   • fouille le JSON brut, donc casse si la structure change.
SELECT nom, competences
FROM candidats
WHERE competences LIKE '%SQL%';


-- 12. Une ligne par (offre, compétence requise).
SELECT o.titre, j.value AS competence_requise
FROM offres o, json_each(o.competences_requises) AS j;


-- 13. Matching : compétences communes pour chaque paire (candidat, offre).
-- Chaque ligne issue de la jointure représente une compétence partagée :
-- le COUNT ne fait que les mesurer.
-- Attention : les paires à zéro n'apparaissent PAS (le JOIN ne produit
-- rien pour elles) — voir l'exercice 19.
WITH competence_candidat AS (
    SELECT c.id, c.nom, j.value AS competence
    FROM candidats c, json_each(c.competences) AS j
),
competence_offre AS (
    SELECT o.id, o.titre, j.value AS competence
    FROM offres o, json_each(o.competences_requises) AS j
)
SELECT cd.nom, co.titre, COUNT(*) AS nb_communes
FROM competence_candidat cd
JOIN competence_offre co ON cd.competence = co.competence
GROUP BY cd.id, cd.nom, co.id, co.titre
ORDER BY nb_communes DESC;


-- 14. Meilleure offre de chaque candidat (ex æquo autorisés).
-- On partitionne sur ce qui suit "pour chaque…" dans l'énoncé.
-- RANK et non ROW_NUMBER : les ex æquo doivent tous sortir.
WITH competence_candidat AS (
    SELECT c.id, c.nom, j.value AS competence
    FROM candidats c, json_each(c.competences) AS j
),
competence_offre AS (
    SELECT o.id, o.titre, j.value AS competence
    FROM offres o, json_each(o.competences_requises) AS j
),
matching AS (
    SELECT cd.id AS candidat_id, cd.nom, co.titre,
           COUNT(*) AS nb_communes
    FROM competence_candidat cd
    JOIN competence_offre co ON cd.competence = co.competence
    GROUP BY cd.id, cd.nom, co.id, co.titre
),
classement AS (
    SELECT *,
           RANK() OVER (PARTITION BY candidat_id ORDER BY nb_communes DESC) AS rang
    FROM matching
)
SELECT nom, titre, nb_communes
FROM classement
WHERE rang = 1
ORDER BY nb_communes DESC;


-- 15. Compétences demandées que personne ne possède.
WITH competence_offre AS (
    SELECT DISTINCT j.value AS competence
    FROM offres o, json_each(o.competences_requises) AS j
),
competence_candidat AS (
    SELECT DISTINCT j.value AS competence
    FROM candidats c, json_each(c.competences) AS j
)
SELECT competence FROM competence_offre
EXCEPT
SELECT competence FROM competence_candidat;
-- Résultat vide sur ce jeu de données : toutes les compétences demandées
-- sont couvertes. Pour valider une requête "négative", créer temporairement
-- le cas positif (ajouter une compétence introuvable à une offre).


-- ############################################################
--  PARTIE 3 — CTE en cascade
-- ############################################################
--
--  Plusieurs CTE se déclarent après un seul WITH, séparées par des
--  virgules ; chacune peut lire les précédentes. Chaque bloc fait une
--  seule chose, ce qui rend la logique lisible et débogable étape par étape.
-- ############################################################


-- 16. Taux d'acceptation par offre, avec le nom de l'entreprise.
-- Pourcentage : toujours multiplier AVANT de diviser, et écrire 100.0.
--   (a / b) * 100.0  → division entière d'abord : 2/5 = 0, puis 0.0
--   a * 100.0 / b    → correct : 200.0 / 5 = 40.0
WITH offre_resultat AS (
    SELECT offre_id,
           COUNT(*) AS nb_candidatures,
           SUM(CASE WHEN statut = 'acceptée' THEN 1 ELSE 0 END) AS nb_acceptees,
           ROUND(SUM(CASE WHEN statut = 'acceptée' THEN 1 ELSE 0 END) * 100.0
                 / COUNT(*), 2) AS taux_acceptation
    FROM candidatures
    GROUP BY offre_id
),
infos_offre AS (
    SELECT o.id, o.titre, e.nom AS entreprise
    FROM offres o
    JOIN entreprises e ON e.id = o.entreprise_id
)
SELECT i.entreprise, i.titre, r.nb_candidatures, r.nb_acceptees, r.taux_acceptation
FROM infos_offre i
JOIN offre_resultat r ON i.id = r.offre_id
WHERE r.nb_candidatures >= 2;
-- Note : SUM(CASE ... THEN 1 ELSE 0 END) et non COUNT(CASE ...) —
-- COUNT compte les non-NULL, donc le ELSE 0 serait comptabilisé.


-- 17. Profil complet par candidat.
-- Les statuts textuels n'ont pas d'ordre naturel : on l'encode en score,
-- on prend le MAX, puis on retraduit.
WITH nombre_competences AS (
    SELECT c.id, c.nom, json_array_length(c.competences) AS nb_competences
    FROM candidats c
),
stats AS (
    SELECT candidat_id,
           COUNT(id) AS nb_candidatures,
           MAX(CASE
                   WHEN statut = 'acceptée'  THEN 4
                   WHEN statut = 'entretien' THEN 3
                   WHEN statut = 'envoyée'   THEN 2
                   WHEN statut = 'refusée'   THEN 1
                   ELSE 0
               END) AS score
    FROM candidatures
    GROUP BY candidat_id
)
SELECT nc.nom,
       nc.nb_competences,
       COALESCE(s.nb_candidatures, 0) AS nb_candidatures,
       CASE
           WHEN s.score = 4 THEN 'acceptée'
           WHEN s.score = 3 THEN 'entretien'
           WHEN s.score = 2 THEN 'envoyée'
           WHEN s.score = 1 THEN 'refusée'
           ELSE 'aucune candidature'
       END AS meilleur_statut
FROM nombre_competences nc
LEFT JOIN stats s ON nc.id = s.candidat_id;
-- La table de référence (candidats) est à gauche ; tout le détail se
-- rattache en LEFT JOIN. Ce qui doit apparaître dans le résultat doit
-- être présent dès la première étape.


-- 18. Candidatures reçues par entreprise, avec rang.
-- La chaîne de LEFT JOIN garantit qu'aucune entreprise ne se perd,
-- quel que soit l'endroit où la chaîne casse. Le rang est calculé
-- APRÈS, sur un ensemble déjà complet.
WITH totaux AS (
    SELECT e.id, e.nom, e.secteur,
           COUNT(c.id) AS nb_candidatures
    FROM entreprises e
    LEFT JOIN offres o       ON o.entreprise_id = e.id
    LEFT JOIN candidatures c ON c.offre_id = o.id
    GROUP BY e.id, e.nom, e.secteur
)
SELECT nom, secteur, nb_candidatures,
       RANK() OVER (ORDER BY nb_candidatures DESC) AS classement
FROM totaux
ORDER BY classement;


-- 19. Candidats ayant postulé sans posséder AUCUNE compétence requise.
-- Une jointure ne produit que des paires qui se ressemblent : elle ne
-- peut donc pas faire émerger les paires à recoupement nul. On part de
-- l'ensemble complet (les candidatures) et on retranche.
SELECT c.nom, o.titre
FROM candidats c
JOIN candidatures ca ON c.id = ca.candidat_id
JOIN offres o        ON ca.offre_id = o.id
WHERE NOT EXISTS (
    SELECT 1
    FROM json_each(c.competences) jc,
         json_each(o.competences_requises) jo
    WHERE jc.value = jo.value
);
-- Sous-requête corrélée : elle référence c et o, donc se recalcule
-- pour chaque candidature.

-- 19 bis. Même résultat via une table de matching + anti-jointure.
WITH matching AS (
    SELECT cd.id AS candidature_id
    FROM candidatures cd
    JOIN candidats ca ON ca.id = cd.candidat_id
    JOIN offres o     ON o.id  = cd.offre_id,
         json_each(ca.competences) jc,
         json_each(o.competences_requises) jo
    WHERE jc.value = jo.value
)
SELECT ca.nom, o.titre
FROM candidatures cd
JOIN candidats ca ON ca.id = cd.candidat_id
JOIN offres o     ON o.id  = cd.offre_id
LEFT JOIN matching m ON m.candidature_id = cd.id
WHERE m.candidature_id IS NULL;


-- 20. Tableau de bord par offre.
-- Titre, entreprise, volume, taux d'entretien, meilleur candidat matché.
WITH infos_offre AS (
    SELECT o.id, o.titre, e.nom AS entreprise
    FROM offres o
    JOIN entreprises e ON o.entreprise_id = e.id
),
stats_offre AS (
    SELECT o.id,
           COUNT(c.id) AS nb_candidatures,
           SUM(CASE WHEN c.statut = 'entretien' THEN 1 ELSE 0 END) AS nb_entretiens,
           SUM(CASE WHEN c.statut = 'acceptée'  THEN 1 ELSE 0 END) AS nb_acceptees
    FROM offres o
    LEFT JOIN candidatures c ON o.id = c.offre_id
    GROUP BY o.id
),
taux AS (
    SELECT id, nb_candidatures, nb_entretiens, nb_acceptees,
           COALESCE((nb_entretiens + nb_acceptees) * 100.0 / nb_candidatures, 0) AS taux_entretien
    FROM stats_offre
),
competence_candidat AS (
    SELECT c.nom, j.value AS competence
    FROM candidats c, json_each(c.competences) AS j
),
competence_offre AS (
    SELECT o.id, j.value AS competence
    FROM offres o, json_each(o.competences_requises) AS j
),
competences_communes AS (
    SELECT co.id, cd.nom, COUNT(*) AS nb_communes
    FROM competence_candidat cd
    JOIN competence_offre co ON cd.competence = co.competence
    GROUP BY co.id, cd.nom
),
meilleur_candidat AS (
    SELECT id, nom, nb_communes
    FROM (
        SELECT id, nom, nb_communes,
               ROW_NUMBER() OVER (PARTITION BY id ORDER BY nb_communes DESC) AS rg
        FROM competences_communes
    )
    WHERE rg = 1
)
SELECT i.titre, i.entreprise,
       t.nb_candidatures, t.nb_entretiens, t.nb_acceptees,
       ROUND(t.taux_entretien, 2) AS taux_entretien_pct,
       m.nom AS meilleur_profil, m.nb_communes
FROM infos_offre i
LEFT JOIN taux t             ON i.id = t.id
LEFT JOIN meilleur_candidat m ON i.id = m.id
ORDER BY t.nb_candidatures DESC;
-- ROW_NUMBER plutôt que RANK : garantit une seule ligne par offre même
-- en cas d'ex æquo (choix assumé — RANK les afficherait tous).
