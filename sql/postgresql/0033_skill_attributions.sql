-- Skill ownership is data, not a Rust code mapping. This mirrors
-- Toonflow-app's o_skillAttribution concept.
CREATE TABLE IF NOT EXISTS toonflow.skill_attributions (
    skill_path text NOT NULL,
    agent_key text NOT NULL,
    priority integer NOT NULL DEFAULT 0,
    PRIMARY KEY (skill_path, agent_key)
);

CREATE INDEX IF NOT EXISTS idx_skill_attributions_agent
    ON toonflow.skill_attributions(agent_key, priority, skill_path);

INSERT INTO toonflow.skill_attributions(skill_path, agent_key, priority)
VALUES
 ('script_agent_decision.md','scriptAgent:decisionAgent',0),
 ('script_agent_supervision.md','scriptAgent:supervisionAgent',0),
 ('script_execution_skeleton.md','scriptAgent:storySkeletonAgent',0),
 ('script_execution_adaptation.md','scriptAgent:adaptationStrategyAgent',0),
 ('script_execution_script.md','scriptAgent:scriptAgent',0),
 ('production_agent_decision.md','productionAgent:decisionAgent',0),
 ('production_agent_supervision.md','productionAgent:supervisionAgent',0),
 ('production_execution_derive_assets.md','productionAgent:deriveAssetsAgent',0),
 ('production_execution_generate_assets.md','productionAgent:generateAssetsAgent',0),
 ('production_execution_director_plan.md','productionAgent:directorPlanAgent',0),
 ('production_execution_storyboard_gen.md','productionAgent:storyboardGenAgent',0),
 ('production_execution_storyboard_panel.md','productionAgent:storyboardPanelAgent',0),
 ('production_execution_storyboard_table.md','productionAgent:storyboardTableAgent',0)
ON CONFLICT (skill_path, agent_key) DO NOTHING;
