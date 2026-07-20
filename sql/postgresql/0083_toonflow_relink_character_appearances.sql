WITH unique_matches AS (
    SELECT d.id AS derivative_id, min(ca.id) AS appearance_id
    FROM toonflow.assets d
    JOIN toonflow.character_appearances ca
      ON ca.project_id = d.project_id
     AND ca.role_asset_id = d.parent_asset_id
     AND (ca.name = d.name OR ca.costume_prompt = d.description)
    WHERE d.parent_asset_id IS NOT NULL
      AND d.appearance_id IS NULL
    GROUP BY d.id
    HAVING count(*) = 1
)
UPDATE toonflow.assets d
SET appearance_id = unique_matches.appearance_id
FROM unique_matches
WHERE d.id = unique_matches.derivative_id;
