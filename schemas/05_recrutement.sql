-- ============================================================
--  BASE D'ENTRAINEMENT SQL n°5 — "recrutement" (niveau avancé+)
--  Thèmes : WHERE vs HAVING, CTE multi-tables, éclatement de listes
--  A coller en entier puis "Run". Relançable à volonté.
-- ============================================================

PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS candidatures;
DROP TABLE IF EXISTS offres;
DROP TABLE IF EXISTS candidats;
DROP TABLE IF EXISTS entreprises;

-- ---------- SCHEMA ----------

CREATE TABLE entreprises (
    id      INTEGER PRIMARY KEY,
    nom     TEXT,
    secteur TEXT,
    taille  TEXT            -- 'startup', 'PME', 'grande'
);

-- competences : liste stockée en JSON, ex. '["SQL","Python"]'
CREATE TABLE candidats (
    id          INTEGER PRIMARY KEY,
    nom         TEXT,
    ville       TEXT,
    annees_exp  INTEGER,
    competences TEXT
);

-- competences_requises : liste JSON
-- mots_cles : liste séparée par des virgules (pour l'exercice bonus)
CREATE TABLE offres (
    id                   INTEGER PRIMARY KEY,
    titre                TEXT,
    entreprise_id        INTEGER,
    ville                TEXT,
    salaire_min          INTEGER,
    salaire_max          INTEGER,
    competences_requises TEXT,
    mots_cles            TEXT,
    date_publication     TEXT
);

CREATE TABLE candidatures (
    id                INTEGER PRIMARY KEY,
    candidat_id       INTEGER,
    offre_id          INTEGER,
    date_candidature  TEXT,
    statut            TEXT   -- 'envoyée', 'entretien', 'refusée', 'acceptée'
);

-- ---------- DONNEES ----------

INSERT INTO entreprises (id, nom, secteur, taille) VALUES
(1, 'TechNova',  'logiciel',    'PME'),
(2, 'DataForge', 'data',        'startup'),
(3, 'FinPlus',   'finance',     'grande'),
(4, 'GreenLog',  'logistique',  'PME'),
(5, 'MediSoft',  'santé',       'startup');

-- Hicham (8) et Jonas (10) n'ont AUCUNE candidature.
-- Jonas a une liste de compétences VIDE (cas limite volontaire).
INSERT INTO candidats (id, nom, ville, annees_exp, competences) VALUES
(1,  'Amina',   'Paris',     5,  '["SQL","Python","Docker"]'),
(2,  'Boris',   'Lyon',      2,  '["JavaScript","React"]'),
(3,  'Carla',   'Paris',     8,  '["SQL","Python","Spark","AWS"]'),
(4,  'Dimitri', 'Marseille', 1,  '["HTML","CSS","JavaScript"]'),
(5,  'Elsa',    'Paris',     4,  '["SQL","Tableau","Excel"]'),
(6,  'Farouk',  'Lyon',      6,  '["Java","Spring","SQL"]'),
(7,  'Gaëlle',  'Nantes',    3,  '["Python","Django","SQL"]'),
(8,  'Hicham',  'Paris',     0,  '["Python"]'),
(9,  'Iris',    'Lyon',      10, '["AWS","Kubernetes","Docker","Python"]'),
(10, 'Jonas',   'Nantes',    2,  '[]');

-- L'offre 7 n'a AUCUNE candidature.
INSERT INTO offres (id, titre, entreprise_id, ville, salaire_min, salaire_max, competences_requises, mots_cles, date_publication) VALUES
(1, 'Data Analyst',      2, 'Paris',  38000, 45000, '["SQL","Python","Tableau"]',        'data,analyse,reporting', '2025-01-15'),
(2, 'Développeur Front', 1, 'Lyon',   35000, 42000, '["JavaScript","React","CSS"]',      'front,web,ui',           '2025-02-01'),
(3, 'Data Engineer',     2, 'Paris',  50000, 62000, '["SQL","Python","Spark","AWS"]',    'data,pipeline,cloud',    '2025-02-20'),
(4, 'Ingénieur Java',    3, 'Paris',  45000, 55000, '["Java","Spring","SQL"]',           'backend,java',           '2025-03-05'),
(5, 'DevOps',            4, 'Lyon',   48000, 58000, '["Docker","Kubernetes","AWS"]',     'cloud,infra,ci',         '2025-03-18'),
(6, 'Analyste BI',       5, 'Nantes', 36000, 44000, '["SQL","Excel","Tableau"]',         'bi,reporting',           '2025-04-02'),
(7, 'Stage Data',        2, 'Paris',  15000, 18000, '["Python","SQL"]',                  'stage,data,junior',      '2025-04-20');

INSERT INTO candidatures (id, candidat_id, offre_id, date_candidature, statut) VALUES
(1,  1, 1, '2025-01-20', 'entretien'),
(2,  1, 3, '2025-02-25', 'refusée'),
(3,  1, 5, '2025-03-20', 'envoyée'),
(4,  2, 2, '2025-02-05', 'acceptée'),
(5,  2, 1, '2025-01-22', 'refusée'),
(6,  3, 3, '2025-02-22', 'acceptée'),
(7,  3, 1, '2025-01-18', 'refusée'),
(8,  3, 6, '2025-04-05', 'envoyée'),
(9,  4, 2, '2025-02-10', 'refusée'),
(10, 4, 6, '2025-04-08', 'envoyée'),
(11, 5, 1, '2025-01-25', 'entretien'),
(12, 5, 6, '2025-04-04', 'entretien'),
(13, 5, 3, '2025-03-02', 'refusée'),
(14, 6, 4, '2025-03-10', 'entretien'),
(15, 6, 3, '2025-02-28', 'refusée'),
(16, 7, 1, '2025-01-30', 'refusée'),
(17, 7, 3, '2025-03-01', 'envoyée'),
(18, 7, 6, '2025-04-10', 'envoyée'),
(19, 9, 5, '2025-03-22', 'acceptée'),
(20, 9, 3, '2025-02-26', 'entretien');

-- ---------- VERIF ----------
-- SELECT COUNT(*) FROM candidatures;          -- doit renvoyer 20
-- SELECT json_each.value FROM candidats, json_each(candidats.competences) LIMIT 5;
