-- ============================================================
--  BASE D'ENTRAINEMENT SQL n°3 — "entreprise" (niveau avancé)
--  A coller dans ton éditeur SQLite puis "Run".
--  Relançable à volonté (DROP au début).
-- ============================================================

DROP TABLE IF EXISTS affectations;
DROP TABLE IF EXISTS projets;
DROP TABLE IF EXISTS employes;
DROP TABLE IF EXISTS departements;

-- ---------- SCHEMA ----------

CREATE TABLE departements (
    id  INTEGER PRIMARY KEY,
    nom TEXT
);

-- manager_id pointe vers un autre employé de la MEME table (hiérarchie).
-- Un manager_id NULL = personne tout en haut (la PDG).
CREATE TABLE employes (
    id             INTEGER PRIMARY KEY,
    nom            TEXT,
    departement_id INTEGER,
    manager_id     INTEGER,      -- référence employes(id), peut être NULL
    salaire        INTEGER,
    date_embauche  TEXT,         -- 'AAAA-MM-JJ'
    FOREIGN KEY (departement_id) REFERENCES departements(id),
    FOREIGN KEY (manager_id)     REFERENCES employes(id)
);

CREATE TABLE projets (
    id             INTEGER PRIMARY KEY,
    nom            TEXT,
    departement_id INTEGER,
    budget         INTEGER,
    FOREIGN KEY (departement_id) REFERENCES departements(id)
);

CREATE TABLE affectations (
    id         INTEGER PRIMARY KEY,
    employe_id INTEGER,
    projet_id  INTEGER,
    heures     INTEGER,          -- heures travaillées sur le projet
    FOREIGN KEY (employe_id) REFERENCES employes(id),
    FOREIGN KEY (projet_id)  REFERENCES projets(id)
);

-- ---------- DONNEES ----------

-- 'Juridique' (id 5) n'a AUCUN employé (utile pour LEFT JOIN + COUNT = 0)
INSERT INTO departements (id, nom) VALUES
(1, 'Direction'),
(2, 'Ingénierie'),
(3, 'Ventes'),
(4, 'Marketing'),
(5, 'Juridique');

-- Hiérarchie :
--   Sophie (1) est PDG (manager_id NULL)
--   Karim (2) et Léna (3) reportent à Sophie
--   Les autres reportent à Karim ou Léna
-- Salaires avec des ex aequo volontaires (Tom & Rita = 45000) pour tester RANK vs DENSE_RANK.
INSERT INTO employes (id, nom, departement_id, manager_id, salaire, date_embauche) VALUES
(1, 'Sophie',  1, NULL, 120000, '2015-03-01'),
(2, 'Karim',   2, 1,     90000, '2017-06-15'),
(3, 'Léna',    3, 1,     88000, '2018-01-10'),
(4, 'Tom',     2, 2,     45000, '2020-09-01'),
(5, 'Rita',    2, 2,     45000, '2021-02-20'),
(6, 'Yann',    2, 2,     62000, '2019-11-05'),
(7, 'Inès',    3, 3,     52000, '2022-04-12'),
(8, 'Marc',    3, 3,     48000, '2023-07-30'),
(9, 'Zoé',     4, 3,     41000, '2023-10-01'),
(10,'Hugo',    4, 3,     39000, '2024-01-15');

-- Le projet 'Refonte site' (id 5) n'a AUCUNE affectation (utile pour repérer les projets sans travail).
INSERT INTO projets (id, nom, departement_id, budget) VALUES
(1, 'App mobile',     2, 200000),
(2, 'API paiement',   2, 150000),
(3, 'Campagne été',   4,  80000),
(4, 'Nouveau CRM',    3, 120000),
(5, 'Refonte site',   4,  60000);

-- Zoé (id 9) n'a AUCUNE affectation (employé sans projet).
INSERT INTO affectations (id, employe_id, projet_id, heures) VALUES
(1,  2, 1, 40),   -- Karim / App mobile
(2,  4, 1, 120),  -- Tom   / App mobile
(3,  5, 1, 100),  -- Rita  / App mobile
(4,  6, 2, 90),   -- Yann  / API paiement
(5,  4, 2, 60),   -- Tom   / API paiement
(6,  3, 4, 30),   -- Léna  / Nouveau CRM
(7,  7, 4, 110),  -- Inès  / Nouveau CRM
(8,  8, 4, 80),   -- Marc  / Nouveau CRM
(9, 10, 3, 70),   -- Hugo  / Campagne été
(10, 7, 3, 20);   -- Inès  / Campagne été

-- ---------- VERIF ----------
-- SELECT * FROM departements;
-- SELECT * FROM employes;
-- SELECT * FROM projets;
-- SELECT * FROM affectations;
