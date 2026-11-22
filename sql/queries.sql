-- Q0 (sanity check): what's inside "Other Tech"? Any data roles misclassified?
SELECT title, COUNT(*) AS n
FROM jobs
WHERE role_group = 'Other Tech'
GROUP BY title
ORDER BY n DESC
LIMIT 30;

-- Q1: Top 10 skills in fresher data roles
SELECT s.skill_name, COUNT(*) AS jobs
FROM job_skills js
JOIN jobs j   ON j.job_id = js.job_id
JOIN skills s ON s.skill_id = js.skill_id
WHERE j.is_fresher = 1 AND j.role_group <> 'Other Tech'
GROUP BY s.skill_name
ORDER BY jobs DESC
LIMIT 10;

-- Q2: Top 5 skills per role group (window function)
WITH counts AS (
    SELECT j.role_group, s.skill_name, COUNT(*) AS jobs,
           ROW_NUMBER() OVER (PARTITION BY j.role_group ORDER BY COUNT(*) DESC) AS rn
    FROM job_skills js
    JOIN jobs j   ON j.job_id = js.job_id
    JOIN skills s ON s.skill_id = js.skill_id
    WHERE j.role_group <> 'Other Tech'
    GROUP BY j.role_group, s.skill_name
)
SELECT role_group, rn AS rank, skill_name, jobs
FROM counts
WHERE rn <= 5
ORDER BY role_group, rn;

-- Q3: Salary by role group and experience level (average vs median)
SELECT role_group, experience_level, COUNT(*) AS jobs,
       ROUND(AVG(salary_lpa), 1) AS avg_lpa,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_lpa))::numeric, 1) AS median_lpa
FROM jobs
WHERE role_group <> 'Other Tech'
GROUP BY role_group, experience_level
ORDER BY role_group, MIN(exp_min);

-- Q4: Which company type pays freshers the most?
SELECT company_type, COUNT(*) AS fresher_jobs,
       ROUND(AVG(salary_lpa), 1) AS avg_lpa,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_lpa))::numeric, 1) AS median_lpa
FROM jobs
WHERE is_fresher = 1 AND role_group <> 'Other Tech'
GROUP BY company_type
ORDER BY median_lpa DESC;

-- Q5: Competition: applicants per opening ("everyone is applying")
SELECT role_group,
       SUM(openings)   AS total_openings,
       SUM(applicants) AS total_applicants,
       ROUND(SUM(applicants)::numeric / NULLIF(SUM(openings), 0), 1) AS applicants_per_opening
FROM jobs
GROUP BY role_group
ORDER BY applicants_per_opening DESC;

-- Q6: Top 5 hiring companies per role group (RANK)
WITH ranked AS (
    SELECT j.role_group, c.name AS company, COUNT(*) AS postings,
           RANK() OVER (PARTITION BY j.role_group ORDER BY COUNT(*) DESC) AS rnk
    FROM jobs j
    JOIN companies c ON c.company_id = j.company_id
    WHERE j.role_group <> 'Other Tech'
    GROUP BY j.role_group, c.name
)
SELECT * FROM ranked WHERE rnk <= 5 ORDER BY role_group, rnk;

-- Q7: Skill pairs that appear together in data roles (self-join)
SELECT s1.skill_name AS skill_a, s2.skill_name AS skill_b, COUNT(*) AS jobs_together
FROM job_skills a
JOIN job_skills b ON a.job_id = b.job_id AND a.skill_id < b.skill_id
JOIN jobs j       ON j.job_id = a.job_id
JOIN skills s1    ON s1.skill_id = a.skill_id
JOIN skills s2    ON s2.skill_id = b.skill_id
WHERE j.role_group <> 'Other Tech'
GROUP BY s1.skill_name, s2.skill_name
ORDER BY jobs_together DESC
LIMIT 15;

-- Q8: Monthly postings, rolling 3-month average, month-over-month change
WITH monthly AS (
    SELECT DATE_TRUNC('month', posted_date)::date AS month, COUNT(*) AS postings
    FROM jobs
    WHERE role_group <> 'Other Tech'
    GROUP BY 1
)
SELECT month, postings,
       ROUND(AVG(postings) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS rolling_3mo,
       postings - LAG(postings) OVER (ORDER BY month) AS mom_change
FROM monthly
ORDER BY month;

-- Q9: Skills that over-index in the top-paying 25% of data jobs (NTILE + FILTER)
WITH paid AS (
    SELECT job_id, NTILE(4) OVER (ORDER BY salary_lpa) AS q
    FROM jobs
    WHERE role_group <> 'Other Tech'
),
tot AS (
    SELECT COUNT(*) FILTER (WHERE q = 4) AS top_jobs,
           COUNT(*) FILTER (WHERE q < 4) AS other_jobs
    FROM paid
),
r AS (
    SELECT s.skill_name,
           COUNT(*) FILTER (WHERE p.q = 4) AS in_top,
           ROUND(100.0 * COUNT(*) FILTER (WHERE p.q = 4) / (SELECT top_jobs FROM tot), 1)   AS pct_in_top_paying,
           ROUND(100.0 * COUNT(*) FILTER (WHERE p.q < 4) / (SELECT other_jobs FROM tot), 1) AS pct_in_rest
    FROM paid p
    JOIN job_skills js ON js.job_id = p.job_id
    JOIN skills s      ON s.skill_id = js.skill_id
    GROUP BY s.skill_name
)
SELECT skill_name, pct_in_top_paying, pct_in_rest,
       pct_in_top_paying - pct_in_rest AS gap
FROM r
WHERE in_top >= 10
ORDER BY gap DESC
LIMIT 10;

-- Q10: % of jobs asking for SQL, by role group (CTE + LEFT JOIN)
WITH sql_jobs AS (
    SELECT DISTINCT js.job_id
    FROM job_skills js
    JOIN skills s ON s.skill_id = js.skill_id
    WHERE s.skill_name = 'sql'
)
SELECT j.role_group, COUNT(*) AS total_jobs,
       COUNT(sj.job_id) AS jobs_with_sql,
       ROUND(100.0 * COUNT(sj.job_id) / COUNT(*), 1) AS pct_sql
FROM jobs j
LEFT JOIN sql_jobs sj ON sj.job_id = j.job_id
GROUP BY j.role_group
ORDER BY pct_sql DESC;

-- BONUS A: Pay by work mode (data roles)
SELECT work_mode, COUNT(*) AS jobs,
       ROUND(AVG(salary_lpa), 1) AS avg_lpa,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_lpa))::numeric, 1) AS median_lpa
FROM jobs
WHERE role_group <> 'Other Tech'
GROUP BY work_mode
ORDER BY median_lpa DESC;

-- BONUS B: Pay by city (data roles, Remote excluded, at least 10 jobs)
SELECT city, COUNT(*) AS jobs, ROUND(AVG(salary_lpa), 1) AS avg_lpa
FROM jobs
WHERE city <> 'Remote' AND role_group <> 'Other Tech'
GROUP BY city
HAVING COUNT(*) >= 10
ORDER BY avg_lpa DESC;