-- ============================================================
--  BASE 03 — ENTREPRISE
--  Niveau : intermédiaire / avancé
--  Schéma : departements / employes / projets / affectations
--  Particularité : `employes.manager_id` référence `employes.id`
--                  (table auto-référencée → self-join et récursivité)
-- ============================================================


-- ------------------------------------------------------------
-- NIVEAU A — Agrégats avec préservation des zéros
-- ------------------------------------------------------------

-- 1. Nombre d'employés par département, y compris ceux à 0.
-- COUNT(e.id) et non COUNT(*) : après un LEFT JOIN sans correspondance,
-- e.id vaut NULL et n'est donc pas compté. COUNT(*) renverrait 1 à tort.
SELECT d.nom, COUNT(e.id) AS nb_employes
FROM departements d
LEFT JOIN employes e ON d.id = e.departement_id
GROUP BY d.id, d.nom;


-- 2. Heures travaillées par projet, y compris les projets à 0.
-- SUM sur un ensemble vide renvoie NULL : COALESCE le ramène à 0.
SELECT p.nom, COALESCE(SUM(a.heures), 0) AS nb_heures
FROM projets p
LEFT JOIN affectations a ON a.projet_id = p.id
GROUP BY p.id, p.nom
ORDER BY nb_heures DESC;


-- ------------------------------------------------------------
-- NIVEAU B — Comparaison à une valeur globale (sous-requête)
-- ------------------------------------------------------------

-- 3. Employés au-dessus de la moyenne générale des salaires.
-- Sous-requête NON corrélée : calculée une seule fois.
SELECT nom, salaire
FROM employes
WHERE salaire > (SELECT AVG(salaire) FROM employes);


-- 4. Projet(s) au budget maximal, sans LIMIT.
-- Avantage sur ORDER BY ... LIMIT 1 : les ex æquo sortent tous.
SELECT nom, budget
FROM projets
WHERE budget = (SELECT MAX(budget) FROM projets);


-- ------------------------------------------------------------
-- NIVEAU C — Self-join
-- ------------------------------------------------------------

-- 5. Chaque employé avec le nom de son manager.
-- Deux alias sur la même table. LEFT JOIN pour conserver la PDG,
-- dont manager_id est NULL.
SELECT e.nom AS employe, m.nom AS manager
FROM employes e
LEFT JOIN employes m ON e.manager_id = m.id;


-- ------------------------------------------------------------
-- NIVEAU D — Fonctions fenêtre
-- ------------------------------------------------------------

-- 6. Rang salarial à l'intérieur de chaque département.
SELECT e.nom, d.nom AS departement, e.salaire,
       RANK() OVER (PARTITION BY e.departement_id
                    ORDER BY e.salaire DESC) AS rang_dept
FROM employes e
JOIN departements d ON e.departement_id = d.id;


-- 7. Écart de chaque salaire à la moyenne de son département.
-- AVG en mode fenêtre : agrège SANS fusionner les lignes.
SELECT e.nom, d.nom AS departement, e.salaire,
       AVG(e.salaire) OVER (PARTITION BY e.departement_id) AS moyenne_dept,
       e.salaire - AVG(e.salaire) OVER (PARTITION BY e.departement_id) AS ecart
FROM employes e
JOIN departements d ON e.departement_id = d.id;


-- 8. Date d'embauche de la personne suivante (LEAD).
SELECT nom, date_embauche,
       LEAD(date_embauche) OVER (ORDER BY date_embauche) AS embauche_suivante
FROM employes
ORDER BY date_embauche;


-- ------------------------------------------------------------
-- NIVEAU E — CTE
-- ------------------------------------------------------------

-- 9. Départements dont la masse salariale dépasse 150 000 €.
WITH masse_salariale AS (
    SELECT d.nom, SUM(e.salaire) AS masse
    FROM employes e
    JOIN departements d ON e.departement_id = d.id
    GROUP BY d.id, d.nom
)
SELECT nom, masse
FROM masse_salariale
WHERE masse > 150000;
-- → Ingénierie (242 000) et Ventes (188 000)


-- ------------------------------------------------------------
-- NIVEAU F — CTE récursives (parcours de hiérarchie)
-- ------------------------------------------------------------

-- 10. Toute la hiérarchie sous la PDG, avec le niveau de profondeur.
-- Le sens du parcours est déterminé par la condition de jointure :
--   e.manager_id = h.id  → on DESCEND (les subordonnés)
--   e.id = h.manager_id  → on REMONTE (le manager)
WITH RECURSIVE hierarchie AS (
    -- cas de base : la racine, désignée sans id en dur
    SELECT id, nom, manager_id, 0 AS niveau
    FROM employes
    WHERE manager_id IS NULL

    UNION ALL

    -- partie récursive : les subordonnés de ceux déjà trouvés
    SELECT e.id, e.nom, e.manager_id, h.niveau + 1
    FROM employes e
    JOIN hierarchie h ON e.manager_id = h.id
)
SELECT nom, niveau
FROM hierarchie
ORDER BY niveau, nom;


-- 11. Chaîne de commandement au-dessus d'un employé (remontée).
WITH RECURSIVE chaine AS (
    SELECT id, nom, manager_id, 0 AS niveau
    FROM employes
    WHERE id = 10

    UNION ALL

    SELECT e.id, e.nom, e.manager_id, h.niveau + 1
    FROM employes e
    JOIN chaine h ON e.id = h.manager_id     -- sens inverse
)
SELECT nom, niveau
FROM chaine
ORDER BY niveau;
-- → Hugo → Léna → Sophie


-- 12. Chemin hiérarchique complet, construit par concaténation.
-- La colonne `chemin` s'allonge à chaque tour en réutilisant celle du parent.
WITH RECURSIVE hierarchie AS (
    SELECT id, nom, manager_id, 0 AS niveau, nom AS chemin
    FROM employes
    WHERE manager_id IS NULL

    UNION ALL

    SELECT e.id, e.nom, e.manager_id, h.niveau + 1,
           h.chemin || ' > ' || e.nom
    FROM employes e
    JOIN hierarchie h ON e.manager_id = h.id
)
SELECT chemin, niveau
FROM hierarchie
ORDER BY chemin;
-- → 'Sophie > Léna > Hugo', 'Sophie > Karim > Tom', ...
