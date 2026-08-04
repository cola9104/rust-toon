export interface ProductionWorkflowPosition {
  x: number;
  y: number;
}

export interface ProductionWorkflowNode {
  config: Record<string, unknown>;
  id: string;
  position: ProductionWorkflowPosition;
  type: string;
}

export interface ProductionWorkflowEdge {
  id: string;
  source: string;
  target: string;
}

export interface ProductionWorkflowDefinition {
  edges: ProductionWorkflowEdge[];
  nodes: ProductionWorkflowNode[];
  schemaVersion: number;
}

export interface ProductionWorkflowNodeMeta {
  description: string;
  executable: boolean;
  input?: string;
  label: string;
  output?: string;
}

const nodeViewTypes: Record<string, string> = {
  'director.plan': 'scriptPlan',
  'script.source': 'script',
  'storyboard.image': 'storyboard',
  'storyboard.plan': 'storyboardTable',
  'video.generate': 'workbench',
};

const nodeMetas: Record<string, ProductionWorkflowNodeMeta> = {
  'director.plan': {
    description: '根据剧本与项目资产生成镜头、节奏和视觉方向。',
    executable: true,
    input: '剧本 / 资产',
    label: '导演规划',
    output: '导演方案',
  },
  'script.source': {
    description: '读取当前项目中选定的剧本和已绑定资产。',
    executable: true,
    label: '剧本与衍生资产',
    output: '剧本上下文',
  },
  'storyboard.image': {
    description: '按分镜表和关联资产生成单帧画面，支持进度、取消与失败重试。',
    executable: true,
    input: '分镜描述',
    label: '分镜图片',
    output: '分镜帧',
  },
  'storyboard.plan': {
    description: '生成并复审结构化分镜表，随后按项目模式自动写入分镜面板。',
    executable: true,
    input: '导演方案',
    label: '分镜表',
    output: '分镜表 / 分镜面板',
  },
  'video.generate': {
    description: '使用分镜首尾帧和提示词生成视频片段。',
    executable: true,
    input: '分镜帧',
    label: '视频生成',
  },
};

export function defaultProductionWorkflow(): ProductionWorkflowDefinition {
  return {
    schemaVersion: 1,
    nodes: [
      { id: 'script', type: 'script.source', position: { x: 0, y: 0 }, config: {} },
      { id: 'scriptPlan', type: 'director.plan', position: { x: 1000, y: 0 }, config: {} },
      { id: 'storyboardTable', type: 'storyboard.plan', position: { x: 2000, y: 0 }, config: {} },
      { id: 'storyboard', type: 'storyboard.image', position: { x: 3000, y: 0 }, config: {} },
      { id: 'workbench', type: 'video.generate', position: { x: 4000, y: 0 }, config: {} },
    ],
    edges: [
      { id: 'script-plan', source: 'script', target: 'scriptPlan' },
      { id: 'plan-table', source: 'scriptPlan', target: 'storyboardTable' },
      { id: 'table-panel', source: 'storyboardTable', target: 'storyboard' },
      { id: 'panel-workbench', source: 'storyboard', target: 'workbench' },
    ],
  };
}

export function normalizeProductionWorkflow(
  value: unknown,
): ProductionWorkflowDefinition {
  if (!value || typeof value !== 'object') return defaultProductionWorkflow();
  const candidate = value as Partial<ProductionWorkflowDefinition>;
  if (
    candidate.schemaVersion !== 1 ||
    !Array.isArray(candidate.nodes) ||
    candidate.nodes.length === 0 ||
    !Array.isArray(candidate.edges)
  ) {
    return defaultProductionWorkflow();
  }
  const workflow = candidate as ProductionWorkflowDefinition;
  return {
    ...workflow,
    nodes: workflow.nodes.map((node) => ({
      ...node,
      config: node.config && typeof node.config === 'object' ? node.config : {},
    })),
  };
}

export function workflowNodeViewType(nodeType: string) {
  return nodeViewTypes[nodeType] ?? 'default';
}

export function workflowNodeMeta(nodeType: string): ProductionWorkflowNodeMeta {
  return nodeMetas[nodeType] ?? {
    description: '自定义工作流节点。',
    executable: false,
    input: '输入',
    label: '自定义节点',
    output: '输出',
  };
}

export function workflowHasCycle(
  definition: ProductionWorkflowDefinition,
): boolean {
  const indegree = new Map(definition.nodes.map((node) => [node.id, 0]));
  const children = new Map<string, string[]>();
  for (const edge of definition.edges) {
    if (!indegree.has(edge.source) || !indegree.has(edge.target)) return true;
    indegree.set(edge.target, (indegree.get(edge.target) ?? 0) + 1);
    children.set(edge.source, [...(children.get(edge.source) ?? []), edge.target]);
  }
  const ready = [...indegree.entries()]
    .filter(([, degree]) => degree === 0)
    .map(([id]) => id);
  let visited = 0;
  while (ready.length > 0) {
    const id = ready.shift()!;
    visited += 1;
    for (const child of children.get(id) ?? []) {
      const degree = (indegree.get(child) ?? 0) - 1;
      indegree.set(child, degree);
      if (degree === 0) ready.push(child);
    }
  }
  return visited !== definition.nodes.length;
}

export function workflowExecutionOrder(
  definition: ProductionWorkflowDefinition,
): string[] {
  const indegree = new Map(definition.nodes.map((node) => [node.id, 0]));
  const children = new Map<string, string[]>();
  for (const edge of definition.edges) {
    indegree.set(edge.target, (indegree.get(edge.target) ?? 0) + 1);
    children.set(edge.source, [...(children.get(edge.source) ?? []), edge.target]);
  }
  const ready = definition.nodes
    .filter((node) => indegree.get(node.id) === 0)
    .map((node) => node.id);
  const order: string[] = [];
  while (ready.length > 0) {
    const id = ready.shift()!;
    order.push(id);
    for (const child of children.get(id) ?? []) {
      const degree = (indegree.get(child) ?? 0) - 1;
      indegree.set(child, degree);
      if (degree === 0) ready.push(child);
    }
  }
  return order;
}

export function workflowPath(
  definition: ProductionWorkflowDefinition,
  nodeId: string,
  direction: 'downstream' | 'upstream',
): string[] {
  const adjacent = new Map<string, string[]>();
  for (const edge of definition.edges) {
    const from = direction === 'upstream' ? edge.target : edge.source;
    const to = direction === 'upstream' ? edge.source : edge.target;
    adjacent.set(from, [...(adjacent.get(from) ?? []), to]);
  }
  const included = new Set([nodeId]);
  const queue = [nodeId];
  while (queue.length > 0) {
    const id = queue.shift()!;
    for (const next of adjacent.get(id) ?? []) {
      if (included.has(next)) continue;
      included.add(next);
      queue.push(next);
    }
  }
  return workflowExecutionOrder(definition).filter((id) => included.has(id));
}
