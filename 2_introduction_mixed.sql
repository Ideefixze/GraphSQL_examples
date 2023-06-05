-- 2. Mieszane krawędzie na przykładzie zadłużeń u osób i banków.
-- Przemiennosc uzywania MATCH i zapytan SQL.

-- Stworzmy baze danych
IF NOT EXISTS (SELECT * FROM sys.databases WHERE NAME = 'graphdemo')
	CREATE DATABASE GraphDemo;
GO

USE GraphDemo;
GO

-- Stworzmy tabelę NODE Person
CREATE TABLE Person (
  ID INTEGER PRIMARY KEY,
  name VARCHAR(100)
) AS NODE;


-- oraz Bank
CREATE TABLE Bank (
  ID INTEGER PRIMARY KEY,
  name VARCHAR(100),
  city VARCHAR(100)
) AS NODE;

-- Mamy dwa typy wierzcholkow i jeden typ krawedzi zastosujemy je w różnych przypadkach
CREATE TABLE owesMoney (debt INTEGER) AS EDGE;

INSERT INTO Person (ID, name)
	VALUES (1, 'Jan')
		 , (2, 'Anna')
		 , (3, 'Adam Zadłużony')

INSERT INTO Bank (ID, name, city)
	VALUES (1, 'KRK Bank', 'Krakow')
		 , (2, 'WAW Bank', 'Warszawa')

INSERT INTO owesMoney
	VALUES ((SELECT $node_id FROM Person WHERE ID = 3), (SELECT $node_id FROM Bank WHERE ID = 1), 1000)
		, ((SELECT $node_id FROM Person WHERE ID = 3), (SELECT $node_id FROM Bank WHERE ID = 2), 2000)
		,  ((SELECT $node_id FROM Person WHERE ID = 3), (SELECT $node_id FROM Person WHERE ID = 1), 100)
		,  ((SELECT $node_id FROM Person WHERE ID = 3), (SELECT $node_id FROM Person WHERE ID = 2), 100)
		, ((SELECT $node_id FROM Bank WHERE ID = 2), (SELECT $node_id FROM Bank WHERE ID = 1), 5000000)


--Znajdzmy całe zadluzenie Adama Zadłużonego u innych osób i banków:

-- W Neo4J dla takich i innych zapytan uzywamy MATCH:
--MATCH (p:Person {name: 'Jon'})-[owes:owesMoney]->(recipient)
--WHERE recipient:Bank OR recipient:Person
--RETURN p.name AS Person, recipient.name AS Recipient, owes.debt AS Debt


-- Wada grafów w SQL Serwerze:
-- nie da się "dopasowywać" elastycznie ani krawędzi ani wierzchołków przy użycia MATCH:

--Synatx wygląda następująco:
--MATCH(<search_pattern>)
--<search_pattern>::=
--    <node_alias>
--    { -( <edge_alias> )-> | <-( <edge_alias> )- }
--    <node_alias>
--    [ { AND <search_pattern> } [ ...n ] ]
--  <node_alias> ::=
--    node_table_name | node_alias 
--  <edge_alias> ::=
--    edge_table_name | edge_alias

SELECT person1.name, person2.name, owesMoney.debt
FROM Person as person1, Person as person2, owesMoney
WHERE MATCH(person1-(owesMoney)->person2) AND person1.ID=3
UNION ALL
SELECT person1.name, bank.name, owesMoney.debt
FROM Person as person1, Bank as bank, owesMoney
WHERE MATCH(person1-(owesMoney)->bank) AND person1.ID=3

-- jest zbyt długie, ale dziala.
-- Dla takiego prostego zapytania można też skorzystać z faktu, że
-- owesMoney to tabela i uzywac klasycznych JOINow bez uzycia MATCH:

SELECT p0.name, p1.name, om.debt
FROM owesMoney as om 
INNER JOIN Person p0 on om.$from_id = p0.$node_id
JOIN Person p1 on om.$to_id = p1.$node_id
JOIN Bank b1 on om.$to_id = b1.$node_id

SELECT p0.name, ISNULL(p1.name, b1.name) name, om.debt FROM owesMoney as om 
JOIN Person p0 on om.$from_id = p0.$node_id
LEFT JOIN Person p1 on om.$to_id = p1.$node_id
LEFT JOIN Bank b1 on om.$to_id = b1.$node_id


DROP TABLE IF EXISTS Bank
DROP TABLE IF EXISTS Person
DROP TABLE IF EXISTS owesMoney
DROP TABLE IF EXISTS likes