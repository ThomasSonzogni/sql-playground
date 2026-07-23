-- ============================================================
--  BASE D'ENTRAINEMENT SQL — "boutique en ligne"
--  A coller dans https://sqliteonline.com puis cliquer "Run"
--  (colle TOUT le fichier d'un coup, puis lance tes requetes)
-- ============================================================

-- On repart d'une base propre a chaque execution
DROP TABLE IF EXISTS lignes_commande;
DROP TABLE IF EXISTS commandes;
DROP TABLE IF EXISTS produits;
DROP TABLE IF EXISTS clients;

-- ---------- SCHEMA ----------

CREATE TABLE clients (
    id               INTEGER PRIMARY KEY,
    nom              TEXT,
    ville            TEXT,
    date_inscription TEXT      -- format 'AAAA-MM-JJ'
);

CREATE TABLE produits (
    id        INTEGER PRIMARY KEY,
    nom       TEXT,
    categorie TEXT,
    prix      REAL
);

CREATE TABLE commandes (
    id            INTEGER PRIMARY KEY,
    client_id     INTEGER,
    date_commande TEXT,        -- format 'AAAA-MM-JJ'
    statut        TEXT,        -- 'payée', 'expédiée', 'annulée'
    FOREIGN KEY (client_id) REFERENCES clients(id)
);

CREATE TABLE lignes_commande (
    id          INTEGER PRIMARY KEY,
    commande_id INTEGER,
    produit_id  INTEGER,
    quantite    INTEGER,
    FOREIGN KEY (commande_id) REFERENCES commandes(id),
    FOREIGN KEY (produit_id)  REFERENCES produits(id)
);

-- ---------- DONNEES ----------

-- Clients : Fatima (id 6) et Idris (id 7) n'ont AUCUNE commande (utile pour l'ex. 12)
INSERT INTO clients (id, nom, ville, date_inscription) VALUES
(1, 'Alice',   'Paris',    '2023-05-12'),
(2, 'Bruno',   'Lyon',     '2024-01-20'),
(3, 'Chloé',   'Paris',    '2024-03-08'),
(4, 'David',   'Marseille','2024-07-15'),
(5, 'Emma',    'Lyon',     '2025-02-01'),
(6, 'Fatima',  'Paris',    '2024-11-30'),
(7, 'Idris',   'Marseille','2023-09-09');

-- Produits : plusieurs categories, dont 'informatique' avec >5 produits (utile pour l'ex. 7)
INSERT INTO produits (id, nom, categorie, prix) VALUES
(1,  'Ordinateur portable', 'informatique', 899.00),
(2,  'Souris',              'informatique',  25.00),
(3,  'Clavier mécanique',   'informatique',  75.00),
(4,  'Écran 27"',           'informatique', 249.00),
(5,  'Webcam',              'informatique',  55.00),
(6,  'Casque audio',        'informatique', 120.00),
(7,  'Chaise de bureau',    'mobilier',     150.00),
(8,  'Bureau réglable',     'mobilier',     420.00),
(9,  'Lampe LED',           'mobilier',      35.00),
(10, 'Carnet',              'papeterie',      8.00),
(11, 'Stylo premium',       'papeterie',     45.00);

-- Commandes : Alice (id 1) a 3 commandes de dates differentes (utile pour l'ex. 14)
-- La commande 8 est 'annulée' (utile pour les ex. 11 et 13)
INSERT INTO commandes (id, client_id, date_commande, statut) VALUES
(1, 1, '2024-06-01', 'expédiée'),
(2, 1, '2024-09-15', 'payée'),
(3, 1, '2025-01-10', 'payée'),
(4, 2, '2024-04-22', 'expédiée'),
(5, 3, '2024-05-30', 'payée'),
(6, 3, '2024-12-12', 'expédiée'),
(7, 4, '2024-08-19', 'payée'),
(8, 5, '2025-03-05', 'annulée'),
(9, 5, '2025-03-20', 'payée');

-- Lignes de commande
INSERT INTO lignes_commande (id, commande_id, produit_id, quantite) VALUES
(1,  1, 1, 1),   -- Alice : 1 ordi portable
(2,  1, 2, 2),   -- Alice : 2 souris
(3,  2, 4, 2),   -- Alice : 2 ecrans
(4,  3, 3, 1),   -- Alice : 1 clavier
(5,  4, 7, 4),   -- Bruno : 4 chaises
(6,  4, 8, 1),   -- Bruno : 1 bureau
(7,  5, 2, 3),   -- Chloé : 3 souris
(8,  6, 1, 1),   -- Chloé : 1 ordi portable
(9,  6, 6, 1),   -- Chloé : 1 casque
(10, 7, 9, 5),   -- David : 5 lampes
(11, 7, 10, 10), -- David : 10 carnets
(12, 8, 1, 1),   -- Emma : 1 ordi portable (MAIS commande annulée)
(13, 9, 5, 2),   -- Emma : 2 webcams
(14, 9, 2, 1);   -- Emma : 1 souris

-- ---------- VERIFICATION RAPIDE ----------
-- Décommente une ligne pour tester que tout est charge :
-- SELECT * FROM clients;
-- SELECT * FROM produits;
-- SELECT * FROM commandes;
-- SELECT * FROM lignes_commande;
