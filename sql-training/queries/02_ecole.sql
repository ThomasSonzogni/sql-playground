-- ============================================================
--  BASE 02 — ÉCOLE
--  Niveau : consolidation (NULL, anti-jointures, fenêtres)
--  Schéma : etudiants / professeurs / cours / inscriptions
--  Particularités : notes NULL, étudiant sans cours, cours sans inscrit
-- ============================================================


-- ------------------------------------------------------------
-- NIVEAU 1 — Bases
-- ------------------------------------------------------------

-- 1. Nom et filière des étudiants, triés par nom.
SELECT nom, filiere
FROM etudiants
ORDER BY nom;


-- 2. Cours d'informatique valant plus de 3 crédits.
SELECT id, intitule, credits
FROM cours
WHERE departement = 'informatique'
  AND credits > 3;


-- 3. Étudiants entrés en 2024.
SELECT id, nom, annee_entree
FROM etudiants
WHERE annee_entree = 2024;


-- ------------------------------------------------------------
-- NIVEAU 2 — Agrégation
-- ------------------------------------------------------------

-- 4. Nombre d'étudiants par filière.
SELECT filiere, COUNT(id) AS nb_etudiants
FROM etudiants
GROUP BY filiere
ORDER BY nb_etudiants DESC;


-- 5. Note moyenne par cours.
-- AVG ignore les NULL : il divise par le nombre de notes présentes.
-- Un cours dont toutes les notes sont NULL renvoie NULL (et non 0).
SELECT c.intitule, AVG(i.note) AS note_moyenne
FROM inscriptions i
JOIN cours c ON c.id = i.cours_id
GROUP BY c.id, c.intitule;


-- 6. Filières comptant au moins 2 étudiants.
-- HAVING ne va jamais sans GROUP BY.
SELECT filiere, COUNT(id) AS nb_etudiants
FROM etudiants
GROUP BY filiere
HAVING COUNT(id) >= 2;


-- ------------------------------------------------------------
-- NIVEAU 3 — Jointures
-- ------------------------------------------------------------

-- 7. Étudiant + cours pour chaque inscription.
SELECT i.id, e.nom, c.intitule, e.annee_entree
FROM inscriptions i
JOIN cours c     ON c.id = i.cours_id
JOIN etudiants e ON e.id = i.etudiant_id;


-- 8. Chaque cours avec son professeur.
-- Aucun agrégat ici : donc aucun GROUP BY.
SELECT c.intitule, p.nom AS professeur
FROM cours c
JOIN professeurs p ON c.prof_id = p.id;


-- 9. Moyenne de chaque étudiant.
SELECT e.nom, AVG(i.note) AS note_moyenne
FROM inscriptions i
JOIN etudiants e ON e.id = i.etudiant_id
GROUP BY e.id, e.nom
ORDER BY note_moyenne DESC;


-- 10. Étudiants inscrits à aucun cours — version LEFT JOIN.
SELECT nom
FROM etudiants e
LEFT JOIN inscriptions i ON e.id = i.etudiant_id
WHERE i.etudiant_id IS NULL;

-- 10 bis. Même question — version NOT EXISTS.
SELECT nom
FROM etudiants e
WHERE NOT EXISTS (
    SELECT 1 FROM inscriptions i WHERE e.id = i.etudiant_id
);


-- 11. Cours sans aucun inscrit — version LEFT JOIN.
SELECT intitule
FROM cours c
LEFT JOIN inscriptions i ON i.cours_id = c.id
WHERE i.cours_id IS NULL;

-- 11 bis. Même question — version NOT EXISTS.
SELECT c.intitule
FROM cours c
WHERE NOT EXISTS (
    SELECT 1 FROM inscriptions i WHERE i.cours_id = c.id
);


-- ------------------------------------------------------------
-- NIVEAU 4 — Avancé
-- ------------------------------------------------------------

-- 12. Étiquetage de chaque note.
-- Une ligne par inscription : pas de GROUP BY, sinon on perd les notes.
SELECT e.nom, c.intitule, i.note,
       CASE
           WHEN i.note >= 16 THEN 'excellent'
           WHEN i.note >= 10 THEN 'correct'
           ELSE 'insuffisant'
       END AS etiquette
FROM inscriptions i
JOIN cours c     ON i.cours_id = c.id
JOIN etudiants e ON e.id = i.etudiant_id;


-- 13. Classement des étudiants par moyenne.
-- Agrégation (GROUP BY + AVG) et fonction fenêtre (RANK) cohabitent :
-- la fenêtre s'applique au résultat de l'agrégation.
SELECT e.nom,
       AVG(i.note) AS note_moyenne,
       RANK() OVER (ORDER BY AVG(i.note) DESC) AS classement
FROM inscriptions i
JOIN etudiants e ON e.id = i.etudiant_id
GROUP BY e.id, e.nom
ORDER BY classement;


-- 14. Meilleure note de chaque étudiant, avec le cours correspondant.
SELECT nom, note, intitule
FROM (
    SELECT e.id, e.nom, i.note, c.intitule,
           ROW_NUMBER() OVER (PARTITION BY e.id
                              ORDER BY i.note DESC) AS rn
    FROM inscriptions i
    JOIN cours c     ON i.cours_id = c.id
    JOIN etudiants e ON e.id = i.etudiant_id
) AS t
WHERE rn = 1;
