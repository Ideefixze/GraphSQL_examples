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
DROP TABLE IF EXISTS likes;
DROP TABLE IF EXISTS Person;
DROP TABLE IF EXISTS Restaurant;
DROP TABLE IF EXISTS City;
DROP TABLE IF EXISTS friendOf;
DROP TABLE IF EXISTS livesIn;
DROP TABLE IF EXISTS locatedIn;
DROP TABLE IF EXISTS Bank;
DROP TABLE IF EXISTS owesMoney;