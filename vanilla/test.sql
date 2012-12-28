BEGIN; 

CREATE TABLE test (stuff INT); 

INSERT INTO test (SELECT generate_series(1,100)); 

COMMIT;
