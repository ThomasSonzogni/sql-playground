-- ============================================================
--  BASE D'ENTRAINEMENT SQL n°4 — "banque" (VERSION SANS FK)
--  Identique à la précédente, mais sans contraintes FOREIGN KEY
--  (elles ne changent rien aux requêtes d'entraînement).
--  A coller en entier puis "Run". Relançable à volonté.
-- ============================================================

PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS comptes;
DROP TABLE IF EXISTS clients;

-- ---------- SCHEMA ----------

CREATE TABLE clients (
    id             INTEGER PRIMARY KEY,
    nom            TEXT,
    ville          TEXT,
    date_ouverture TEXT
);

CREATE TABLE comptes (
    id            INTEGER PRIMARY KEY,
    client_id     INTEGER,
    type          TEXT,
    solde_initial REAL
);

CREATE TABLE categories (
    id        INTEGER PRIMARY KEY,
    nom       TEXT,
    parent_id INTEGER
);

CREATE TABLE transactions (
    id             INTEGER PRIMARY KEY,
    compte_id      INTEGER,
    date_operation TEXT,
    montant        REAL,
    categorie_id   INTEGER,
    libelle        TEXT
);

-- ---------- DONNEES ----------

-- Farid (id 6) n'a AUCUN compte.
INSERT INTO clients (id, nom, ville, date_ouverture) VALUES
(1, 'Alice',  'Paris',     '2023-02-10'),
(2, 'Bruno',  'Lyon',      '2024-05-20'),
(3, 'Chloé',  'Paris',     '2022-11-05'),
(4, 'David',  'Marseille', '2025-01-15'),
(5, 'Emma',   'Lyon',      '2023-08-30'),
(6, 'Farid',  'Nice',      '2024-09-01');

-- Le compte 6 (Emma) n'a AUCUNE transaction.
INSERT INTO comptes (id, client_id, type, solde_initial) VALUES
(1, 1, 'courant',  1000.0),
(2, 1, 'épargne',  5000.0),
(3, 2, 'courant',   500.0),
(4, 3, 'courant',  2000.0),
(5, 4, 'courant',   300.0),
(6, 5, 'courant',   800.0);

-- Arbre sur 3 niveaux : 2 racines, puis sous-catégories, puis sous-sous.
INSERT INTO categories (id, nom, parent_id) VALUES
(1,  'Dépenses',           NULL),
(2,  'Revenus',            NULL),
(3,  'Alimentation',       1),
(4,  'Transport',          1),
(5,  'Loisirs',            1),
(6,  'Restaurants',        3),
(7,  'Courses',            3),
(8,  'Essence',            4),
(9,  'Transports publics', 4),
(10, 'Salaire',            2),
(11, 'Freelance',          2),
(12, 'Cinéma',             5),
(13, 'Streaming',          5);

-- --- Compte 1 : Alice, compte courant (série mensuelle jan -> juin 2025) ---
INSERT INTO transactions (compte_id, date_operation, montant, categorie_id, libelle) VALUES
(1, '2025-01-05',  2500.00, 10, 'Salaire janvier'),
(1, '2025-01-08',   -85.50,  7, 'Supermarché'),
(1, '2025-01-12',   -45.00,  6, 'Restaurant'),
(1, '2025-01-20',   -60.00,  8, 'Station service'),
(1, '2025-01-25',   -12.99, 13, 'Abonnement streaming'),
(1, '2025-02-05',  2500.00, 10, 'Salaire février'),
(1, '2025-02-09',   -92.30,  7, 'Supermarché'),
(1, '2025-02-14',   -78.00,  6, 'Restaurant'),
(1, '2025-02-18',   -12.99, 13, 'Abonnement streaming'),
(1, '2025-02-22',   -30.00, 12, 'Cinéma'),
(1, '2025-03-05',  2500.00, 10, 'Salaire mars'),
(1, '2025-03-07',  -110.00,  7, 'Supermarché'),
(1, '2025-03-15',   -55.00,  8, 'Station service'),
(1, '2025-03-21',   -12.99, 13, 'Abonnement streaming'),
(1, '2025-03-28',   -25.00,  9, 'Pass transport'),
(1, '2025-04-05',  2600.00, 10, 'Salaire avril'),
(1, '2025-04-11',   -95.00,  7, 'Supermarché'),
(1, '2025-04-19',   -12.99, 13, 'Abonnement streaming'),
(1, '2025-04-23',   -40.00,  6, 'Restaurant'),
(1, '2025-05-05',  2600.00, 10, 'Salaire mai'),
(1, '2025-05-10',   -88.00,  7, 'Supermarché'),
(1, '2025-05-16',   -12.99, 13, 'Abonnement streaming'),
(1, '2025-05-27',   -65.00,  8, 'Station service'),
(1, '2025-06-05',  2600.00, 10, 'Salaire juin'),
(1, '2025-06-12',  -105.00,  7, 'Supermarché'),
(1, '2025-06-18',   -12.99, 13, 'Abonnement streaming'),
(1, '2025-06-25',   -50.00, 12, 'Cinéma');

-- --- Compte 2 : Alice, épargne (catégorie NULL volontairement) ---
INSERT INTO transactions (compte_id, date_operation, montant, categorie_id, libelle) VALUES
(2, '2025-01-31', 200.00, NULL, 'Virement épargne'),
(2, '2025-02-28', 200.00, NULL, 'Virement épargne'),
(2, '2025-03-31', 200.00, NULL, 'Virement épargne'),
(2, '2025-04-30', 250.00, NULL, 'Virement épargne'),
(2, '2025-05-31', 250.00, NULL, 'Virement épargne');

-- --- Compte 3 : Bruno ---
INSERT INTO transactions (compte_id, date_operation, montant, categorie_id, libelle) VALUES
(3, '2025-01-10', 1800.00, 10, 'Salaire janvier'),
(3, '2025-01-15',  -60.00,  7, 'Supermarché'),
(3, '2025-02-10', 1800.00, 10, 'Salaire février'),
(3, '2025-02-20',  -75.00,  6, 'Restaurant'),
(3, '2025-03-10', 1800.00, 10, 'Salaire mars'),
(3, '2025-03-14',  -40.00,  8, 'Station service'),
(3, '2025-04-10', 1850.00, 10, 'Salaire avril'),
(3, '2025-04-22',  -90.00,  7, 'Supermarché'),
(3, '2025-05-10', 1850.00, 10, 'Salaire mai'),
(3, '2025-06-10', 1850.00, 10, 'Salaire juin'),
(3, '2025-06-15',  -35.00, 12, 'Cinéma');

-- --- Compte 4 : Chloé (freelance, revenus irréguliers) ---
INSERT INTO transactions (compte_id, date_operation, montant, categorie_id, libelle) VALUES
(4, '2025-02-03',  900.00, 11, 'Mission client'),
(4, '2025-02-15',  -50.00,  7, 'Supermarché'),
(4, '2025-03-03', 1200.00, 11, 'Mission client'),
(4, '2025-03-18',  -70.00,  6, 'Restaurant'),
(4, '2025-04-03', 1100.00, 11, 'Mission client'),
(4, '2025-05-03', 1500.00, 11, 'Mission client'),
(4, '2025-05-20',  -80.00,  8, 'Station service'),
(4, '2025-06-03', 1300.00, 11, 'Mission client');

-- --- Compte 5 : David (arrivé en cours d'année) ---
INSERT INTO transactions (compte_id, date_operation, montant, categorie_id, libelle) VALUES
(5, '2025-02-01', 1500.00, 10, 'Salaire février'),
(5, '2025-02-10', -300.00,  7, 'Courses du mois'),
(5, '2025-03-01', 1500.00, 10, 'Salaire mars'),
(5, '2025-03-12',  -12.99, 13, 'Abonnement streaming');

-- ---------- VERIF ----------
-- SELECT COUNT(*) FROM transactions;   -- doit renvoyer 55
