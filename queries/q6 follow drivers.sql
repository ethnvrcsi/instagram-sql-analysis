-- Q6: Which reels drove my follows?
-- Skills: CTE, ROW_NUMBER(), running total, grand total with SUM() OVER ()

WITH ranked AS (
    SELECT p.post_id, p.publish_date, p.duration_sec, m.reach, m.follows,
           ROW_NUMBER() OVER (ORDER BY m.follows DESC, p.post_id)   AS rn,
           SUM(m.follows) OVER (ORDER BY m.follows DESC, p.post_id) AS running_follows,
           SUM(m.follows) OVER ()                                   AS total_follows
    FROM posts p
    JOIN post_metrics m ON m.post_id = p.post_id
)
SELECT rn AS reel_rank, publish_date, duration_sec, reach, follows,
       running_follows,
       ROUND(100.0 * running_follows / total_follows, 1)    AS cum_pct_of_follows,
       ROUND(100.0 * rn / (SELECT COUNT(*) FROM posts), 1)  AS pct_of_reels
FROM ranked
WHERE rn <= 15
ORDER BY rn;
