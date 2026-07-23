-- ============================================================
--  BASE D'ENTRAINEMENT SQL n°2 — "école"
--  A coller dans ton éditeur SQLite puis "Run".
--  Le script supprime les anciennes tables et recrée tout :
--  tu peux le relancer autant de fois que tu veux.
-- ============================================================

-- ---------- SUPPRESSION DES ANCIENNES TABLES ----------
-- (ordre inverse des dépendances : d'abord les tables "enfants")
DROP TABLE IF EXISTS inscriptions;
DROP TABLE IF EXISTS cours;
DROP TABLE IF EXISTS professeurs;
DROP TABLE IF EXISTS etudiants;

-- ---------- CREATION DES TABLES ----------

CREATE TABLE etudiants (
    id           INTEGER PRIMARY KEY,
    nom          TEXT,
    filiere      TEXT,       -- 'informatique', 'maths', 'physique'...
    annee_entree INTEGER
);

CREATE TABLE professeurs (
    id          INTEGER PRIMARY KEY,
    nom         TEXT,
    departement TEXT
);

CREATE TABLE cours (
    id          INTEGER PRIMARY KEY,
    intitule    TEXT,
    departement TEXT,
    credits     INTEGER,
    prof_id     INTEGER,
    FOREIGN KEY (prof_id) REFERENCES professeurs(id)
);

CREATE TABLE inscriptions (
    id          INTEGER PRIMARY KEY,
    etudiant_id INTEGER,
    cours_id    INTEGER,
    note        REAL,        -- sur 20 ; peut être NULL (pas encore noté)
    FOREIGN KEY (etudiant_id) REFERENCES etudiants(id),
    FOREIGN KEY (cours_id)    REFERENCES cours(id)
);

-- ---------- DONNEES ----------

-- Hugo (id 6) n'est inscrit à AUCUN cours (utile pour "qui n'a rien fait ?")
INSERT INTO etudiants (id, nom, filiere, annee_entree) VALUES
(1, 'Léa',    'informatique', 2023),
(2, 'Marco',  'maths',        2023),
(3, 'Nina',   'informatique', 2024),
(4, 'Omar',   'physique',     2022),
(5, 'Paula',  'maths',        2024),
(6, 'Hugo',   'informatique', 2024);

INSERT INTO professeurs (id, nom, departement) VALUES
(1, 'Dr Bernard', 'informatique'),
(2, 'Dr Costa',   'maths'),
(3, 'Dr Aziz',    'physique');

-- Le cours 6 (Réseaux) n'a AUCUN inscrit (utile pour repérer les cours vides)
INSERT INTO cours (id, intitule, departement, credits, prof_id) VALUES
(1, 'Algorithmique',      'informatique', 6, 1),
(2, 'Bases de données',   'informatique', 4, 1),
(3, 'Analyse',            'maths',        6, 2),
(4, 'Algèbre',            'maths',        5, 2),
(5, 'Mécanique',          'physique',     5, 3),
(6, 'Réseaux',            'informatique', 3, 1);

-- Notes : certaines sont NULL (pas encore corrigées).
-- Léa (id 1) a des notes dans plusieurs cours (utile pour moyennes / classements).
INSERT INTO inscriptions (id, etudiant_id, cours_id, note) VALUES
(1,  1, 1, 15.0),   -- Léa   / Algorithmique
(2,  1, 2, 17.0),   -- Léa   / Bases de données
(3,  1, 6, NULL),   -- Léa   / Réseaux (pas encore noté)
(4,  2, 3, 12.5),   -- Marco / Analyse
(5,  2, 4, 14.0),   -- Marco / Algèbre
(6,  3, 1, 9.0),    -- Nina  / Algorithmique
(7,  3, 2, 13.0),   -- Nina  / Bases de données
(8,  4, 5, 18.0),   -- Omar  / Mécanique
(9,  5, 3, 11.0),   -- Paula / Analyse
(10, 5, 4, 8.0),    -- Paula / Algèbre
(11, 5, 1, 16.0);   -- Paula / Algorithmique

-- ---------- VERIFICATION RAPIDE ----------
-- SELECT * FROM etudiants;
-- SELECT * FROM professeurs;
-- SELECT * FROM cours;
-- SELECT * FROM inscriptions;
