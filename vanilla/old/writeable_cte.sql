BEGIN; 

-- Create a bogus posts table
CREATE table posts (id SERIAL PRIMARY KEY, user_id INTEGER, created TIMESTAMP default NOW());

INSERT into posts (user_id, created) ( SELECT 14,* from generate_series('2010-07-01 00:00'::timestamp, '2011-07-01 00:00'::timestamp, '1 day')); 

-- Create a writeable CTE!
WITH deleted_posts AS ( 
      DELETE FROM posts WHERE created < now() - '6 months'::INTERVAL RETURNING * 
)
SELECT user_id, count(*) FROM deleted_posts 
GROUP BY 1;

ROLLBACK;
