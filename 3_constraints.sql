USE GraphDemo

GO



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

