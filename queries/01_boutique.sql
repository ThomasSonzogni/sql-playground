-- ============================================================
--  BASE 01 — BOUTIQUE EN LIGNE
--  Niveau : fondamentaux (SELECT, agrégation, jointures)
--  Schéma : clients / produits / commandes / lignes_commande
-- ============================================================


-- ------------------------------------------------------------
-- NIVEAU 1 — Bases
-- ------------------------------------------------------------

-- 1. Nom et ville de tous les clients, triés par nom.
SELECT nom, ville
FROM clients
ORDER BY nom;


-- 2. Produits informatiques à plus de 100 €.
SELECT nom
FROM produits
WHERE categorie = 'informatique'
  AND prix > 100;


-- 3. Commandes annulées.
SELECT *
FROM commandes
WHERE statut = 'annulée';


-- 4. Clients inscrits en 2024.
-- Bornes de dates : >= début et < début de l'année suivante.
SELECT nom
FROM clients
WHERE date_inscription >= '2024-01-01'
  AND date_inscription <  '2025-01-01';


-- ------------------------------------------------------------
-- NIVEAU 2 — Agrégation
-- ------------------------------------------------------------

-- 5. Nombre de clients par ville.
SELECT ville, COUNT(*) AS nb_clients
FROM clients
GROUP BY ville;


-- 6. Prix moyen par catégorie.
SELECT categorie, AVG(prix) AS prix_moyen
FROM produits
GROUP BY categorie;


-- 7. Catégories contenant plus de 5 produits.
-- HAVING : filtre sur un agrégat, donc APRÈS le regroupement.
SELECT categorie, COUNT(id) AS nb_produits
FROM produits
GROUP BY categorie
HAVING COUNT(id) > 5;


-- 8. Nombre total d'articles par commande.
SELECT c.id, SUM(l.quantite) AS total_articles
FROM commandes c
JOIN lignes_commande l ON c.id = l.commande_id
GROUP BY c.id;


-- ------------------------------------------------------------
-- NIVEAU 3 — Jointures
-- ------------------------------------------------------------

-- 9. Nom du client pour chaque commande.
SELECT c.id, c.date_commande, cl.nom
FROM commandes c
JOIN clients cl ON cl.id = c.client_id;


-- 10. Produits commandés dans la commande n°42.
SELECT p.nom
FROM commandes c
JOIN lignes_commande l ON c.id = l.commande_id
JOIN produits p        ON p.id = l.produit_id
WHERE c.id = 42;


-- 11. Chiffre d'affaires par client (hors commandes annulées).
-- Le prix vit dans `produits` : la jointure vers cette table est indispensable.
SELECT cl.id, cl.nom, SUM(p.prix * l.quantite) AS ca_client
FROM commandes c
JOIN clients cl        ON cl.id = c.client_id
JOIN lignes_commande l ON l.commande_id = c.id
JOIN produits p        ON p.id = l.produit_id
WHERE c.statut <> 'annulée'
GROUP BY cl.id, cl.nom;


-- 12. Clients n'ayant jamais commandé — version LEFT JOIN.
SELECT cl.nom
FROM clients cl
LEFT JOIN commandes c ON c.client_id = cl.id
WHERE c.id IS NULL;

-- 12 bis. Même question — version NOT EXISTS.
SELECT cl.nom
FROM clients cl
WHERE NOT EXISTS (
    SELECT 1 FROM commandes c WHERE c.client_id = cl.id
);


-- ------------------------------------------------------------
-- NIVEAU 4 — Avancé
-- ------------------------------------------------------------

-- 13. Produit le plus vendu (hors commandes annulées).
-- Ordre canonique : SELECT / FROM / JOIN / WHERE / GROUP BY / HAVING / ORDER BY / LIMIT
SELECT l.produit_id, p.nom, SUM(l.quantite) AS nb_vendus
FROM lignes_commande l
JOIN produits p  ON p.id = l.produit_id
JOIN commandes c ON c.id = l.commande_id
WHERE c.statut IN ('payée', 'expédiée')
GROUP BY l.produit_id, p.nom
ORDER BY nb_vendus DESC
LIMIT 1;


-- 14. Commande la plus récente de chaque client.
-- Motif "meilleure ligne par groupe" : ROW_NUMBER() dans une sous-requête,
-- puis filtre rn = 1 à l'étage du dessus (WHERE s'exécute avant les fenêtres).
SELECT *
FROM (
    SELECT c.*,
           ROW_NUMBER() OVER (PARTITION BY c.client_id
                              ORDER BY c.date_commande DESC) AS rn
    FROM commandes c
) AS t
WHERE rn = 1;


-- 15. Classement des clients par chiffre d'affaires.
SELECT cl.nom,
       SUM(p.prix * l.quantite) AS ca,
       RANK() OVER (ORDER BY SUM(p.prix * l.quantite) DESC) AS rang
FROM clients cl
JOIN commandes c       ON c.client_id = cl.id
JOIN lignes_commande l ON l.commande_id = c.id
JOIN produits p        ON p.id = l.produit_id
GROUP BY cl.id, cl.nom;


-- 16. Étiquetage des produits par gamme de prix.
-- Les WHEN sont évalués dans l'ordre : inutile de borner par le haut.
SELECT nom, prix,
       CASE
           WHEN prix > 500  THEN 'cher'
           WHEN prix >= 100 THEN 'moyen'
           ELSE 'abordable'
       END AS etiquette
FROM produits;
