-- Q2: Which individual reels have the highest follow ratio?

SELECT RANK() OVER (ORDER BY m.follows * 1000.0 / m.reach DESC) AS follow_rank,
       p.publish_date,
       p.duration_sec,
       m.reach,
       m.follows,
       ROUND(m.follows * 1000.0 / m.reach, 2) AS follows_per_1k_reach
FROM posts p
JOIN post_metrics m ON m.post_id = p.post_id
WHERE m.reach >= 1000
ORDER BY follow_rank
LIMIT 10;
