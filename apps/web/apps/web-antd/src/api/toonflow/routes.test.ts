// @vitest-environment node
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';
import { describe, expect, it } from 'vitest';

const directory = fileURLToPath(new URL('.', import.meta.url));
const backend = readFileSync(resolve(directory, '../../../../../../../crates/modules/toon-server/src/lib.rs'), 'utf8');
const frontend = ts.createSourceFile('index.ts', readFileSync(resolve(directory, 'index.ts'), 'utf8'), ts.ScriptTarget.Latest, true);
type Endpoint = { method: string; path: string };
const normalize = (path: string) => path.replace(/\{[^}]*\}/g, '{}');

function paths(node: ts.Expression): string[] {
  if (ts.isStringLiteralLike(node)) return [node.text];
  if (ts.isParenthesizedExpression(node)) return paths(node.expression);
  if (ts.isConditionalExpression(node)) return [...paths(node.whenTrue), ...paths(node.whenFalse)];
  if (ts.isTemplateExpression(node)) {
    let result = [node.head.text];
    for (const span of node.templateSpans) result = result.flatMap((prefix) => paths(span.expression).map((part) => prefix + part + span.literal.text));
    return result;
  }
  return ['{}']; // Runtime IDs occupy a single Axum path parameter.
}

function clientEndpoints(source: ts.SourceFile): Endpoint[] {
  const endpoints: Endpoint[] = [];
  function visit(node: ts.Node) {
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) && node.expression.expression.getText(source) === 'requestClient') {
      const operation = node.expression.name.text;
      let method = operation.toUpperCase();
      if (operation === 'request' || operation === 'download') {
        const options = node.arguments[1];
        const property = options && ts.isObjectLiteralExpression(options) ? options.properties.find((item) => ts.isPropertyAssignment(item) && item.name.getText(source) === 'method') : undefined;
        method = property && ts.isPropertyAssignment(property) ? paths(property.initializer)[0]!.toUpperCase() : 'GET';
      }
      if (node.arguments[0]) endpoints.push(...paths(node.arguments[0]).map((path) => ({ method, path: normalize(path) })));
    }
    ts.forEachChild(node, visit);
  }
  visit(source);
  return endpoints;
}

function serverEndpoints(source: string): Endpoint[] {
  const endpoints: Endpoint[] = [];
  for (const match of source.matchAll(/\.route\(\s*"([^"]+)"\s*,/g)) {
    let depth = 1;
    let end = match.index! + match[0].length;
    const start = end;
    for (; end < source.length && depth; end++) {
      if (source[end] === '(') depth++;
      if (source[end] === ')') depth--;
    }
    for (const method of source.slice(start, end).matchAll(/\b(get|post|put|patch|delete|head|options)\s*\(/g)) {
      endpoints.push({ method: method[1]!.toUpperCase(), path: normalize(match[1]!) });
    }
  }
  return endpoints;
}

describe('Toonflow frontend/backend routing contract', () => {
  it('matches every frontend method and post-proxy path to an actual backend route', () => {
    const routes = new Set(serverEndpoints(backend).map(({ method, path }) => `${method} ${path}`));
    const calls = clientEndpoints(frontend);
    expect(calls.length).toBeGreaterThan(100);
    // The shared client adds /api and Vite/Nginx removes it. API modules must
    // therefore use the backend path directly, without a second /api prefix.
    expect(calls.filter(({ path }) => path.startsWith('/api/'))).toEqual([]);
    expect(calls.filter(({ method, path }) => !routes.has(`${method} ${path}`))).toEqual([]);
  });
  it('expands conditional URLs and distinguishes HTTP methods', () => {
    const source = ts.createSourceFile('fixture.ts', "requestClient.post(`/project/${kind === 'visual' ? 'addVisualManual' : 'addDirectorManual'}`, {}); requestClient.request(`/items/${id}`, {method:'PATCH'});", ts.ScriptTarget.Latest, true);
    expect(clientEndpoints(source)).toEqual([{ method: 'POST', path: '/project/addVisualManual' }, { method: 'POST', path: '/project/addDirectorManual' }, { method: 'PATCH', path: '/items/{}' }]);
    expect(serverEndpoints('.route("/items/{id}", get(list).post(save)).route("/items/{id}/state", axum::routing::patch(update))')).toEqual([{ method: 'GET', path: '/items/{}' }, { method: 'POST', path: '/items/{}' }, { method: 'PATCH', path: '/items/{}/state' }]);
  });
});
