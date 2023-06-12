-- 1. Obsluga prostych zapytań. Tworzenie grafowej bazy danych, zapytania.
-- Na podstawie oficjalnej dokumentacji.
-- Stworzmy baze danych
IF NOT EXISTS (SELECT * FROM sys.databases WHERE NAME = 'graphdemo')
	CREATE DATABASE GraphDemo;
GO
USE GraphDemo;
GO
-- Stworzmy node
CREATE TABLE Person (
  ID INTEGER PRIMARY KEY,
  name VARCHAR(100)
) AS NODE;
CREATE TABLE Restaurant (
  ID INTEGER NOT NULL,
  name VARCHAR(100),
  city VARCHAR(100)
) AS NODE;
CREATE TABLE City (
  ID INTEGER PRIMARY KEY,
  name VARCHAR(100),
  stateName VARCHAR(100)
) AS NODE;
-- Create EDGE tables.
CREATE TABLE likes (rating INTEGER) AS EDGE;
CREATE TABLE friendOf AS EDGE;
CREATE TABLE livesIn AS EDGE;
CREATE TABLE locatedIn AS EDGE;
-- Insert data into node tables. Inserting into a node table is same as inserting into a regular table
INSERT INTO Person (ID, name)
	VALUES (1, 'John')
		 , (2, 'Mary')
		 , (3, 'Alice')
		 , (4, 'Jacob')
		 , (5, 'Julie');
INSERT INTO Restaurant (ID, name, city)
	VALUES (1, 'Taco Dell','Bellevue')
		 , (2, 'Ginger and Spice','Seattle')
		 , (3, 'Noodle Land', 'Redmond');
INSERT INTO City (ID, name, stateName)
	VALUES (1,'Bellevue','WA')
		 , (2,'Seattle','WA')
		 , (3,'Redmond','WA');
-- Dodajmy dane
INSERT INTO likes
	VALUES ((SELECT $node_id FROM Person WHERE ID = 1), (SELECT $node_id FROM Restaurant WHERE ID = 1), 9)
		 , ((SELECT $node_id FROM Person WHERE ID = 2), (SELECT $node_id FROM Restaurant WHERE ID = 2), 9)
		 , ((SELECT $node_id FROM Person WHERE ID = 3), (SELECT $node_id FROM Restaurant WHERE ID = 3), 9)
		 , ((SELECT $node_id FROM Person WHERE ID = 4), (SELECT $node_id FROM Restaurant WHERE ID = 3), 9)
		 , ((SELECT $node_id FROM Person WHERE ID = 5), (SELECT $node_id FROM Restaurant WHERE ID = 3), 9);
INSERT INTO livesIn
	VALUES ((SELECT $node_id FROM Person WHERE ID = 1), (SELECT $node_id FROM City WHERE ID = 1))
		 , ((SELECT $node_id FROM Person WHERE ID = 2), (SELECT $node_id FROM City WHERE ID = 2))
		 , ((SELECT $node_id FROM Person WHERE ID = 3), (SELECT $node_id FROM City WHERE ID = 3))
		 , ((SELECT $node_id FROM Person WHERE ID = 4), (SELECT $node_id FROM City WHERE ID = 3))
		 , ((SELECT $node_id FROM Person WHERE ID = 5), (SELECT $node_id FROM City WHERE ID = 1));
INSERT INTO locatedIn
	VALUES ((SELECT $node_id FROM Restaurant WHERE ID = 1), (SELECT $node_id FROM City WHERE ID =1))
		 , ((SELECT $node_id FROM Restaurant WHERE ID = 2), (SELECT $node_id FROM City WHERE ID =2))
		 , ((SELECT $node_id FROM Restaurant WHERE ID = 3), (SELECT $node_id FROM City WHERE ID =3));
INSERT INTO friendOf
	VALUES ((SELECT $NODE_ID FROM Person WHERE ID = 1), (SELECT $NODE_ID FROM Person WHERE ID = 2))
		 , ((SELECT $NODE_ID FROM Person WHERE ID = 2), (SELECT $NODE_ID FROM Person WHERE ID = 3))
		 , ((SELECT $NODE_ID FROM Person WHERE ID = 3), (SELECT $NODE_ID FROM Person WHERE ID = 1))
		 , ((SELECT $NODE_ID FROM Person WHERE ID = 4), (SELECT $NODE_ID FROM Person WHERE ID = 2))
		 , ((SELECT $NODE_ID FROM Person WHERE ID = 5), (SELECT $NODE_ID FROM Person WHERE ID = 4));

--Zobaczmy nasze dane:
--AS NODE 
-- Dokłada 2 kolumny:
-- graph_id - wewnetrzna SQL Serverowa kolumna, nie da sie po niej prowadzic zapytan
-- node_id - id wierzchołka grafu

--Krawędź będzie miała 8 domyślnych kolumn, które zostaną automatycznie dodane dla każdej utworzonej tabeli, 
--z czego tylko 3 z nich będą automatycznie widoczne w każdym zapytaniu (nieukryte).
--graph_id_<hex_string> - wewnętrzna kolumna graph_id grafu (obecnie możemy mieć tylko jeden graf na bazę danych)
--$edge_id_<hex_string> - zewnętrzne $edge_id, które jednoznacznie identyfikuje krawędź (relację)
--from_obj_id_<hex_string> - przechowuje object_id węzła FROM
--from_id_<hex_string> - przechowuje graph_id węzła FROM
--$from_id_<hex_string> - przechowuje node_id węzła FROM
--to_obj_id_<hex_string> - przechowuje object_id węzła TO
--to_id_<hex_string> - przechowuje graph_id węzła TO
--$to_id_<hex_string> - przechowuje node_id węzła TO

-- Przeprowadzmy proste zapytania:
-- Jakie restauracje lubi John? 
SELECT Restaurant.name
FROM Person, likes, Restaurant
WHERE MATCH (Person-(likes)->Restaurant)
AND Person.name = 'John';
-- Jakie restauracje lubia przyjaciele Johna?
SELECT Restaurant.name
FROM Person person1, Person person2, likes, friendOf, Restaurant
WHERE MATCH(person1-(friendOf)->person2-(likes)->Restaurant)
AND person1.name='John';
-- Jacy ludzie lubia restauracje w miastach ktore oni zamieszkuja?
SELECT Person.name
FROM Person, likes, Restaurant, livesIn, City, locatedIn
WHERE MATCH (Person-(likes)->Restaurant-(locatedIn)->City AND Person-(livesIn)->City);
-- Znajdź znajomych znajomych znajomych, wykluczając przypadki, w których występuje "pętla" relacji.
-- Na przykład, Alicja jest przyjacielem Johna; Johna jest przyjacielem Marii; a Maria z kolei jest przyjacielem Alicji.
-- Powoduje to "pętlę" z powrotem do Alicji. W wielu przypadkach konieczne jest jawnie sprawdzenie takich pętli i wykluczenie wyników.
SELECT CONCAT(Person.name, '=>', Person2.name, '=>', Person3.name, '=>', Person4.name)
FROM Person, friendOf, Person as Person2, friendOf as friendOffriend, Person as Person3, friendOf as friendOffriendOfFriend, Person as Person4
WHERE MATCH (Person-(friendOf)->Person2-(friendOffriend)->Person3-(friendOffriendOfFriend)->Person4)
AND Person2.name != Person.name
AND Person3.name != Person2.name
AND Person4.name != Person3.name
AND Person.name != Person4.name;

-- 2. MATCH 
-- Mieszane krawędzie na przykładzie zadłużeń u osób i banków.
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

/*
Domyśnie tabele grafowe nie nakładają ograniczeń na tabele dla źródła i celu krawędzi, co może prowadzić do błędów modelu dancyh.
Aby ograniczyć schemat naszej bazy grafowej możemy nałożyć ograniczenia (`CONSTRAINT`) typu `CONNECTION`. Ograniczenie takie możemy nałożyć na tabele krawędziowe, aby określić źródło i cel krawędzi.
Przy utworzeniu ograniczenia musimy wybrać akcję przy usunięciu węzła. 
- Krawędź wiążąca dany węzeł może zostać kaskadowo usunięta
- Usunięcie węzła może zostać udaremnione i spowodować błąd
Ograniczenia możemy nakładać przy okazji tworzenia nowych tabel:
*/
CREATE TABLE visited
(
   VisitDate INT
      ,CONSTRAINT EC_VISITED CONNECTION (Person TO Restaurant) ON DELETE NO ACTION
)
AS EDGE;

/*
lub dodawać do istniejących:
*/
ALTER TABLE friendOf ADD CONSTRAINT EC_FRIEND CONNECTION (Person TO Person);

/*
Jeśli chcemy dodać ograniczenie, które zezwala na skierowanie krawędzi z/do więcej niż jednej tabeli możemy użyć ograniczenia wielokrotnego.
**Uwaga!** Jedno ograniczenie wielokrotne to nie to samo co kilka osobnych ograniczeń.
Przykładowo poniższa kwerenda wymusi koniunkcję ograniczeń, a w rezultacie uniemożliwi dodanie nowych krawędzi tego typu
*/
ALTER TABLE owesMoney ADD CONSTRAINT EC_OWES_B CONNECTION (Person TO Bank)
ALTER TABLE owesMoney ADD CONSTRAINT EC_OWES_P CONNECTION (Person TO Person)
INSERT INTO owesMoney VALUEs
(
(SELECT $node_id FROM Person WHERE Person.name = 'Jacob'),
(SELECT $node_id FROM Bank WHERE Bank.name = 'WAW Bank'),
150
)

INSERT INTO owesMoney VALUEs
(
(SELECT $node_id FROM Person WHERE Person.name = 'Jacob'),
(SELECT $node_id FROM Person WHERE Person.name = 'Julie'),
150
)
/*
SQL Server nie daje możliwości modyfikacji istniejących ograniczeń typu CONNECTION
Usuńmy zatem te ograniczenia i zastąpmy je nowym - takim które dopuszcza skierowanie krawędzi do dowolnej z tabel:
*/
ALTER TABLE owesMoney DROP CONSTRAINT EC_OWES_B
ALTER TABLE owesMoney DROP CONSTRAINT EC_OWES_P
ALTER TABLE owesMoney ADD CONSTRAINT EC_OWES CONNECTION (Person TO Bank, Person TO Person) ON DELETE NO ACTION -- You can't just doge your debt by removing yourself from the database

/*
Listę bieżących ograniczeń możemy wyświetlić za pomocą kwerendy
*/
SELECT
   EC.name AS edge_constraint_name
   , OBJECT_NAME(EC.parent_object_id) AS edge_table_name
   , OBJECT_NAME(ECC.from_object_id) AS from_node_table_name
   , OBJECT_NAME(ECC.to_object_id) AS to_node_table_name
   , is_disabled
   , is_not_trusted
FROM sys.edge_constraints EC
   INNER JOIN sys.edge_constraint_clauses ECC
   ON EC.object_id = ECC.object_id
WHERE EC.parent_object_id = object_id('owesMoney');
/*
Rozważmy teraz przykłady w których chcemy wyciągnąć dane o ścieżkach dowolnej długości.
*/
USE graphdemo
GO
/*
Rozpocznijmy od zwykłego zapytania grafowego
*/
SELECT man1.name, man2.name
FROM Person man1, friendOf, Person man2
WHERE MATCH(man1-(friendOf)->man2)
AND man1.name = 'John'
/*
Chcielibyśmy teraz powielić dowolnie ilość krawędzi na ścieżce do wierzchołka końcowego, tak aby zapytanie reprezentowało ścieżkę dowolnej długości.
Pierwsze (intuicyjne) podejście: dodanie operatora plusa...
*/
SELECT man1.name, man2.name
FROM Person man1, friendOf, Person man2
WHERE MATCH(man1(-(friendOf)->man2)+)
AND man1.name = 'John'
/*
...nie zadziała. Wzorce zmiennej długości muszą być dodatkowo otoczone funkcją SHORTEST\_PATH...
*/
SELECT man1.name, man2.name
FROM Person man1, friendOf, Person man2
WHERE MATCH(SHORTEST_PATH(man1(-(friendOf)->man2)+))
AND man1.name = 'John'
/*
...a tabele wzięte do części rekurencyjnej wzorca muszą być oznaczone słowami kluczowymi `FOR PATH`
*/
SELECT man1.name, man2.name
FROM Person            AS man1
   , friendOf FOR PATH AS fo
   , Person   FOR PATH AS man2
WHERE MATCH(SHORTEST_PATH(man1(-(fo)->man2)+))
AND man1.name = 'John'
/*
Na razie pomińmy również `man2.name` i zobaczmy wynik zapytania.
*/
SELECT man1.name
FROM Person AS man1
   , friendOf FOR PATH AS fo
   , Person FOR PATH AS man2
WHERE MATCH(SHORTEST_PATH(man1(-(fo)->man2)+))
AND man1.name = 'John'
/*
Otrzymujemy w wyniku trzy rekordy. Odpowiadają one ścieżkom rozpoczynającym się od węzła "John" i kończącym w innych węzłach, w tym przypadku z tabeli Person. W sekcji SELECT nie można bezpośrednio odwołać się do tabel ze ścieżki, gdyż mogą się one potencjalnie odwoływać do wielu rekordów na ścieżce. Z tego też powodu rekordy FOR PATH są zbierane do grup, do których należy zaaplikować odpowiednie funkcje agregacji (STRING_AGG, LAST_VALUE, COUNT, SUM, AVG, MIN, MAX), po których musi nastąpić wyrażenie "WITHIN GROUP (GRAPH PATH)"
*/
SELECT man1.name                                              AS FirstNode
     , LAST_VALUE(man2.name)        WITHIN GROUP (GRAPH PATH) AS LastNode
     , STRING_AGG(man2.name, '->')  WITHIN GROUP (GRAPH PATH) AS Path
     , COUNT(man2.name)             WITHIN GROUP (GRAPH PATH) AS PathLength
     , SUM(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS RelationshipStrengthDistance
     , AVG(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS AverageRelationshipStrength
     , MIN(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS MinimumRelationshipStrength
     , MAX(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS MaximumRelationshipStrength
FROM Person            AS man1
   , friendOf FOR PATH AS fo
   , Person   FOR PATH AS man2
WHERE MATCH(SHORTEST_PATH(man1(-(fo)->man2)+))
AND man1.name = 'John'
/*
Aby dodać ograniczenia dotyczące którejkolwiek z tych wartości należy użyć zapytania okalającego
*/
SELECT * FROM (
SELECT man1.name                                              AS FirstNode
     , LAST_VALUE(man2.name)        WITHIN GROUP (GRAPH PATH) AS LastNode
     , STRING_AGG(man2.name, '->')  WITHIN GROUP (GRAPH PATH) AS Path
     , COUNT(man2.name)             WITHIN GROUP (GRAPH PATH) AS PathLength
     , SUM(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS RelationshipStrengthDistance
     , AVG(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS AverageRelationshipStrength
     , MIN(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS MinimumRelationshipStrength
     , MAX(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH) AS MaximumRelationshipStrength
FROM Person            AS man1
   , friendOf FOR PATH AS fo
   , Person   FOR PATH AS man2
WHERE MATCH(SHORTEST_PATH(man1(-(fo)->man2)+))
AND man1.name = 'John'
) Q
WHERE Q.LastNode = 'Alice'
/*
Inny przykład: znajdź tylko takie łańcuszki, gdzie siła przyjaźni nie spada poniżej poziomu 1.0
*/
SELECT * FROM (
SELECT (man1.name + '->' + STRING_AGG(man2.name, '->')  WITHIN GROUP (GRAPH PATH)) AS Path
     ,                     MIN(fo.relationshipStrength) WITHIN GROUP (GRAPH PATH)  AS MinimumRelationshipStrength
FROM Person            AS man1
   , friendOf FOR PATH AS fo
   , Person   FOR PATH AS man2
WHERE MATCH(SHORTEST_PATH(man1(-(fo)->man2)+))
) Q
WHERE Q.MinimumRelationshipStrength >= 1.0
/*
W kolejnych przykładach posłużymy się schematem `klient-\>restauracja\<-klient-\>restauracja-\>...`, aby znaleźć potencjalnie podobne restauracje (załóżmy, że takiej heurystyki chcemy użyć)
*/
SELECT man.name, likes.rating, rest.name
FROM Person man
   , Restaurant rest
   , likes
WHERE MATCH(man-(likes)->rest)
OR MATCH()
SELECT * FROM (
SELECT man1.name AS FirstNode
     , STRING_AGG(N'-'+CONVERT(VARCHAR(4), l1.rating)+'->['+rest.name+']<-'+CONVERT(VARCHAR(4), l2.rating)+'-'+man2.name, '') WITHIN GROUP (GRAPH PATH) AS Path
     , LAST_VALUE(man2.name) WITHIN GROUP (GRAPH PATH) as LastNode
FROM Person AS man1
   , likes FOR PATH AS l1
   , Restaurant FOR PATH AS rest
   , likes FOR PATH AS l2
   , Person FOR PATH as man2 
WHERE MATCH(SHORTEST_PATH(man1(-(l1)->rest<-(l2)-man2){1,4}))
) Q WHERE Q.FirstNode <> Q.LastNode
/*
W czterech ostatnich wierszach mamy krawędź pomiędzy restauracją Taco Dell a Jacobem, która nie powinna się tam znaleźć, jako że nie ma takiej w bazie (możemy to sprawdzić powyżej). Widzimy stąd, że tworzenie bardziej złożonych wzorców niż rekursja jednej krawędzi może produkować niepoprawne wyniki.
*/
SELECT rest1.name
     , STRING_AGG(N'-'+CONVERT(VARCHAR(4), l1.rating)+'->['+man.name+']<-'+CONVERT(VARCHAR(4), l2.rating)+'-'+rest2.name, '') WITHIN GROUP (GRAPH PATH) AS Path
FROM Restaurant AS rest1
   , likes FOR PATH AS l1
   , Person FOR PATH AS man
   , likes FOR PATH AS l2
   , Restaurant FOR PATH as rest2 
WHERE MATCH(SHORTEST_PATH(rest1(<-(l1)-man-(l2)->rest2){1,4}))
/*
 Ograniczenia `SHORTEST_PATH` mogą być łączone z innymi ograniczeniami grafowymi.
W poniższym przykładzie poszukujemy
*/
SELECT
	Person1.name AS PersonName,
	STRING_AGG(Person2.name, '->') WITHIN GROUP (GRAPH PATH) AS Friends,
	Restaurant.name
FROM
	Person AS Person1,
	friendOf FOR PATH AS fo,
	Person FOR PATH  AS Person2,
	likes,
	Restaurant
WHERE MATCH(SHORTEST_PATH(Person1(-(fo)->Person2){1,3}) AND LAST_NODE(Person2)-(likes)->Restaurant )
AND Person1.name = 'Jacob'
AND Restaurant.name = 'Ginger and Spice'


USE graphdemo;
GO

DROP TABLE IF EXISTS owesMoney
DROP TABLE IF EXISTS Bank
DROP TABLE IF EXISTS likes;
DROP TABLE IF EXISTS Person;
DROP TABLE IF EXISTS Restaurant;
DROP TABLE IF EXISTS City;
DROP TABLE IF EXISTS friendOf;
DROP TABLE IF EXISTS livesIn;
DROP TABLE IF EXISTS locatedIn;

USE master;
GO
DROP DATABASE graphdemo;
GO