# instagram-sql-analysis

Analyzing my own Instagram Reels performance with SQL (SQLite) to find out which videos actually grow my account: which reel lengths convert viewers into followers, which individual reels drive growth, and how my results changed month to month.

**Data:** Instagram Insights export from Meta Business Suite, Jan 1 to Oct 22, 2026 (335 posts: 334 reels and 1 carousel). Metrics are lifetime totals per post.
**Tools:** Python (pandas) to load the CSV, SQLite for analysis, DB Browser for SQLite to run queries.
**SQL techniques:** multi-table JOINs (including a range join), GROUP BY, CTEs, `RANK()` with `PARTITION BY`, `ROW_NUMBER()`, `LAG()`, running totals with `SUM() OVER`.

**Key metric:** *follow ratio* = follows per 1,000 reach (`follows * 1000.0 / reach`). It measures how well a reel turns viewers into followers, regardless of how many people saw it.

---

## Key findings

1. **Longer reels convert viewers better, but short reels bring far more volume.** Reels over 30 seconds gained 4.98 follows per 1,000 reach, compared with 1.00 for reels under 8 seconds. But the under-8s averaged about 44K reach per reel, against about 3.8K for the over-30s.
2. **A few reels drive most of the growth.** 15 of my 335 reels (4.5%) produced 50% of all 25,198 follows. Most of those 15 were short reels (6 to 14 seconds) with large reach.
3. **My follow ratio jumped early in the year and then levelled off.** It rose from 0.24 in January to 2.32 in April and stayed between roughly 1 and 2.5 afterward. (January looks low because one reel with 6.2M reach dominated the month's reach.) Posting more didn't help: August had my most posts (53) and the sharpest ratio drop (2.05 to 1.04).
4. **The best reel each month isn't one format.** Of the 10 monthly follow-ratio winners, 5 were 13 to 14 seconds long, 4 were 53 to 61 seconds, and 1 had no duration listed, so there's no single winning length.

*Caveats:* the 16 to 30s and over 30s groups have only 20 and 22 reels, so those numbers are directional. October is partial (data ends Oct 21) and recent reels are still collecting follows. Reel-level rankings only include reels with at least 1,000 reach, so tiny reels don't produce misleading ratios.

---

## Schema

```
posts(post_id PK, publish_ts, publish_date, year_month, post_type, duration_sec, description, permalink)
post_metrics(post_id PK/FK -> posts, views, reach, likes, shares, follows, comments, saves)
time_slots(hour PK, slot_name)                    -- lookup: hour of day -> Morning/Afternoon/Evening/Night
duration_buckets(bucket_name PK, min_sec, max_sec, sort_order)   -- lookup: reel length ranges
```

The raw export is one flat CSV. `load_instagram.py` splits it into descriptive info (`posts`) and performance numbers (`post_metrics`), converts timestamps to ISO format so SQLite date functions work, and builds two small lookup tables for grouping. Columns with no information (always "Lifetime" or always empty) and single-value account columns are dropped.

### How to run

```bash
pip install pandas
python load_instagram.py your_export.csv     # creates instagram.db
```

Then open `instagram.db` in DB Browser for SQLite (or `sqlite3 instagram.db`) and run the files in `queries/`.

---

## Questions and queries

### Q1. Which reel length performs best?
*Skills: multi-table JOIN (range join), GROUP BY, aggregates.* Each post joins to a length bucket by whether its duration falls between the bucket's min and max.

```sql
SELECT b.bucket_name,
       COUNT(*)                                                                   AS num_posts,
       ROUND(AVG(m.views), 0)                                                     AS avg_views,
       ROUND(AVG(m.reach), 0)                                                     AS avg_reach,
       ROUND(AVG((m.likes + m.comments + m.shares + m.saves) * 1.0 / m.reach), 4) AS avg_engagement_rate,
       ROUND(SUM(m.follows) * 1000.0 / SUM(m.reach), 2)                           AS follows_per_1k_reach
FROM posts p
JOIN post_metrics m     ON m.post_id = p.post_id
JOIN duration_buckets b ON p.duration_sec BETWEEN b.min_sec AND b.max_sec
GROUP BY b.bucket_name
ORDER BY b.sort_order;
```

### Q2. Which individual reels have the highest follow ratio?
*Skills: JOIN, WHERE filter, `RANK()` window function.*

```sql
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
```

### Q3. What was my best follow-ratio reel each month?
*Skills: CTE, `RANK()` with `PARTITION BY`, filtering on a window result.*

```sql
WITH ranked AS (
    SELECT p.year_month,
           p.publish_date,
           p.duration_sec,
           m.reach,
           m.follows,
           m.follows * 1000.0 / m.reach AS follow_ratio,
           RANK() OVER (
               PARTITION BY p.year_month
               ORDER BY m.follows * 1000.0 / m.reach DESC
           ) AS month_rank
    FROM posts p
    JOIN post_metrics m ON m.post_id = p.post_id
    WHERE m.reach >= 1000
)
SELECT year_month,
       publish_date,
       duration_sec,
       reach,
       follows,
       ROUND(follow_ratio, 2) AS follows_per_1k_reach
FROM ranked
WHERE month_rank = 1
ORDER BY year_month;
```

### Q4. How has my follow ratio changed month over month?
*Skills: CTE, GROUP BY, `LAG()`.*

```sql
WITH monthly AS (
    SELECT p.year_month,
           COUNT(*)                               AS num_posts,
           SUM(m.reach)                           AS total_reach,
           SUM(m.follows)                         AS total_follows,
           SUM(m.follows) * 1000.0 / SUM(m.reach) AS follows_per_1k_reach
    FROM posts p
    JOIN post_metrics m ON m.post_id = p.post_id
    GROUP BY p.year_month
)
SELECT year_month,
       num_posts,
       total_follows,
       ROUND(follows_per_1k_reach, 2)                                                        AS follows_per_1k_reach,
       ROUND(LAG(follows_per_1k_reach) OVER (ORDER BY year_month), 2)                        AS prev_month_ratio,
       ROUND(follows_per_1k_reach - LAG(follows_per_1k_reach) OVER (ORDER BY year_month), 2) AS mom_change
FROM monthly
ORDER BY year_month;
```

### Q5. How do my follows add up over time?
*Skills: CTE, GROUP BY, running total with `SUM() OVER (ORDER BY ...)`.*

```sql
WITH monthly AS (
    SELECT p.year_month, SUM(m.follows) AS follows
    FROM posts p
    JOIN post_metrics m ON m.post_id = p.post_id
    GROUP BY p.year_month
)
SELECT year_month,
       follows,
       SUM(follows) OVER (ORDER BY year_month) AS running_follows,
       ROUND(100.0 * SUM(follows) OVER (ORDER BY year_month)
             / SUM(follows) OVER (), 1)        AS pct_of_total
FROM monthly
ORDER BY year_month;
```

### Q6. Which reels drove my follows?
*Skills: CTE, `ROW_NUMBER()`, running total, grand total with `SUM() OVER ()`.*

```sql
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
```

---

## Repo layout

```
├── README.md
├── load_instagram.py
└── queries/
    ├── q1_reel_length.sql
    ├── q2_top_follow_reels.sql
    ├── q3_best_reel_per_month.sql
    ├── q4_follow_ratio_mom.sql
    ├── q5_running_follows.sql
    └── q6_follow_drivers.sql
```

The raw export and the database are not included because they contain post links and account details.

*Built by Ethan Vercesi, Biomedical Engineering, UBC.*
