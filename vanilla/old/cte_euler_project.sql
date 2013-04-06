-- From: http://wiki.postgresql.org/wiki/Euler_Project,_Question_1
WITH RECURSIVE t1(a, b) AS (
        VALUES(0,0)
    UNION ALL
        SELECT CASE CAST(b AS BOOLEAN)
                      WHEN b % 3 = 0 THEN b
                      WHEN b % 5 = 0 THEN b
                END,
                b + 1
          FROM t1
         WHERE b < 1000
)
SELECT sum(a) FROM t1; 
