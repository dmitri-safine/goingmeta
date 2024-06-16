// run in cypher-shell
// :param apiKey => "<insert-key-here>"
// :param apiUrl => "<insert-url-here"

CALL n10s.graphconfig.init({ handleVocabUris: "IGNORE", classLabel: "Concept", subClassOfRel: "broader"});

// Load articles from CSV file
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/jbarrasa/goingmeta/main/session2/resources/devto-articles.csv' AS row
CREATE (a:Article { uri: row.uri})
SET a.title = row.title, a.body = row.body, a.datetime = datetime(row.date);

// Load the concept scheme using n10s
CREATE CONSTRAINT n10s_unique_uri FOR (r:Resource) REQUIRE r.uri IS UNIQUE;

CALL n10s.skos.import.fetch("https://raw.githubusercontent.com/jbarrasa/goingmeta/main/session2/resources/goingmeta-skos.ttl","Turtle");

// Remove redundant 'broader' relationships (from Wikidata extract)
MATCH (s:Concept)-[shortcut:broader]->(:Concept)<-[:broader*2..]-(s)
DELETE shortcut;


CALL apoc.periodic.iterate(
  "MATCH (a:Article)
   WHERE a.processed IS NULL
   RETURN a",
  "CALL apoc.nlp.azure.entities.stream([item in $_batch | item.a], {
     nodeProperty: 'body',
     key: $apiKey,
     url: $apiUrl
   })
   YIELD node, value
   SET node.processed = true
   WITH node, value
   UNWIND value.entities AS entity
   WITH entity, node
   WHERE entity.wikipediaUrl IS NOT NULL
   MATCH (c:Concept {
      altLabel: entity.wikipediaUrl
    })
   MERGE (node)-[:refers_to]->(c)",
  {
    batchMode: "BATCH_SINGLE", 
    batchSize: 10, 
    params: { 
       apiKey: $apiKey,
       apiUrl: $apiUrl
    }
  })
YIELD batches, total, timeTaken, committedOperations
RETURN batches, total, timeTaken, committedOperations;


# import another ontology (software stack onto)

CALL n10s.onto.import.fetch("http://www.nsmntx.org/2020/08/swStacks","Turtle");

