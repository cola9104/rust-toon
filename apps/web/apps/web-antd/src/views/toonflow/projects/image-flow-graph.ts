export interface ImageFlowEdge {
  id: string;
  source: string;
  target: string;
}

export interface ImageFlowNode {
  id: string;
  type: string;
}

export function upstreamNodeIds(edges: ImageFlowEdge[], nodeId: string): Set<string> {
  const visited = new Set<string>([nodeId]);
  const visit = (id: string) => {
    for (const edge of edges.filter((item) => item.target === id)) {
      if (!visited.has(edge.source)) {
        visited.add(edge.source);
        visit(edge.source);
      }
    }
  };
  visit(nodeId);
  visited.delete(nodeId);
  return visited;
}

/** Direct inputs are the only references for one edit step. Traversing all ancestors would feed
 * every historical generated image back into the model and compound visual drift. */
export function directUpstreamNodeIds(edges: ImageFlowEdge[], nodeId: string): Set<string> {
  return new Set(
    edges.filter((edge) => edge.target === nodeId).map((edge) => edge.source),
  );
}

export function defaultImageFlowEdges(nodes: ImageFlowNode[]): ImageFlowEdge[] {
  const generatedNode = nodes.find((node) => node.type === 'generated');
  if (!generatedNode) return [];
  return nodes
    .filter((node) => node.id !== generatedNode.id && ['prompt', 'upload'].includes(node.type))
    .map((node) => ({
      id: `edge-${node.id}-${generatedNode.id}`,
      source: node.id,
      target: generatedNode.id,
    }));
}
