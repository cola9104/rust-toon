use std::collections::{HashMap, HashSet, VecDeque};

use rust_toon_framework_web::AppError;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

const WORKFLOW_SCHEMA_VERSION: i32 = 1;

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowPosition {
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowNode {
    pub id: String,
    #[serde(rename = "type")]
    pub node_type: String,
    pub position: WorkflowPosition,
    #[serde(default)]
    pub config: Value,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowEdge {
    pub id: String,
    pub source: String,
    pub target: String,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowDefinition {
    pub schema_version: i32,
    pub nodes: Vec<WorkflowNode>,
    pub edges: Vec<WorkflowEdge>,
}

pub fn default_production_workflow() -> WorkflowDefinition {
    let nodes = [
        ("script", "script.source", 0.0),
        ("scriptPlan", "director.plan", 1000.0),
        ("storyboardTable", "storyboard.plan", 2000.0),
        ("storyboard", "storyboard.image", 3000.0),
        ("workbench", "video.generate", 4000.0),
    ]
    .into_iter()
    .map(|(id, node_type, x)| WorkflowNode {
        id: id.into(),
        node_type: node_type.into(),
        position: WorkflowPosition { x, y: 0.0 },
        config: json!({}),
    })
    .collect();
    let edges = [
        ("script-plan", "script", "scriptPlan"),
        ("plan-table", "scriptPlan", "storyboardTable"),
        ("table-panel", "storyboardTable", "storyboard"),
        ("panel-workbench", "storyboard", "workbench"),
    ]
    .into_iter()
    .map(|(id, source, target)| WorkflowEdge {
        id: id.into(),
        source: source.into(),
        target: target.into(),
    })
    .collect();
    WorkflowDefinition {
        schema_version: WORKFLOW_SCHEMA_VERSION,
        nodes,
        edges,
    }
}

pub fn workflow_from_data(data: &Value) -> Result<WorkflowDefinition, AppError> {
    match data.get("workflow") {
        Some(value) => serde_json::from_value(value.clone())
            .map_err(|_| AppError::bad_request("workflow definition is invalid")),
        None => Ok(default_production_workflow()),
    }
}

pub fn validate_workflow(workflow: &WorkflowDefinition) -> Result<Vec<String>, AppError> {
    if workflow.schema_version != WORKFLOW_SCHEMA_VERSION {
        return Err(AppError::bad_request("unsupported workflow schema version"));
    }
    if workflow.nodes.is_empty() {
        return Err(AppError::bad_request(
            "workflow must contain at least one node",
        ));
    }
    let mut node_types = HashMap::new();
    for node in &workflow.nodes {
        let id = node.id.trim();
        let node_type = node.node_type.trim();
        if id.is_empty() || node_type.is_empty() {
            return Err(AppError::bad_request(
                "workflow node id and type are required",
            ));
        }
        if node.config.is_null() || (!node.config.is_object() && !node.config.is_array()) {
            return Err(AppError::bad_request("workflow node config must be JSON"));
        }
        if node_types
            .insert(id.to_string(), node_type.to_string())
            .is_some()
        {
            return Err(AppError::bad_request("workflow node ids must be unique"));
        }
    }

    let mut edge_ids = HashSet::new();
    let mut indegree = node_types
        .keys()
        .map(|id| (id.clone(), 0_usize))
        .collect::<HashMap<_, _>>();
    let mut downstream = HashMap::<String, Vec<String>>::new();
    for edge in &workflow.edges {
        if !edge_ids.insert(edge.id.trim()) {
            return Err(AppError::bad_request("workflow edge ids must be unique"));
        }
        if !node_types.contains_key(edge.source.as_str())
            || !node_types.contains_key(edge.target.as_str())
        {
            return Err(AppError::bad_request(
                "workflow edge references an unknown node",
            ));
        }
        if edge.source == edge.target {
            return Err(AppError::bad_request("workflow cannot contain self edges"));
        }
        *indegree.get_mut(&edge.target).expect("validated target") += 1;
        downstream
            .entry(edge.source.clone())
            .or_default()
            .push(edge.target.clone());
    }

    let mut ready = indegree
        .iter()
        .filter_map(|(id, degree)| (*degree == 0).then_some(id.clone()))
        .collect::<Vec<_>>();
    ready.sort();
    let mut ready = VecDeque::from(ready);
    let mut order = Vec::with_capacity(workflow.nodes.len());
    while let Some(id) = ready.pop_front() {
        order.push(id.clone());
        if let Some(children) = downstream.get(&id) {
            let mut children = children.clone();
            children.sort();
            for child in children {
                let degree = indegree.get_mut(&child).expect("validated child");
                *degree -= 1;
                if *degree == 0 {
                    ready.push_back(child);
                }
            }
        }
    }
    if order.len() != workflow.nodes.len() {
        return Err(AppError::bad_request("workflow must not contain cycles"));
    }
    Ok(order)
}

#[cfg(test)]
mod tests {
    use super::{WorkflowEdge, default_production_workflow, validate_workflow};

    #[test]
    fn default_workflow_has_stable_execution_order() {
        assert_eq!(
            validate_workflow(&default_production_workflow()).unwrap(),
            [
                "script",
                "scriptPlan",
                "storyboardTable",
                "storyboard",
                "workbench"
            ]
        );
    }

    #[test]
    fn rejects_cycles() {
        let mut workflow = default_production_workflow();
        workflow.edges.push(WorkflowEdge {
            id: "cycle".into(),
            source: "workbench".into(),
            target: "script".into(),
        });
        assert!(validate_workflow(&workflow).is_err());
    }
}
